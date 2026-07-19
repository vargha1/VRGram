package client

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"strings"

	"github.com/user/dns-transport/internal/crypto"
	"github.com/user/dns-transport/internal/media"
)

// loadPeers reads peers from JSON file into memory.
func (d *Daemon) loadPeers() {
	data, err := os.ReadFile(d.peersPath)
	if err != nil {
		if !os.IsNotExist(err) {
			slog.Warn("failed to read peers file", "error", err)
		}
		return
	}
	var loaded map[string]*PeerInfoEntry
	if err := json.Unmarshal(data, &loaded); err != nil {
		slog.Warn("failed to parse peers file", "error", err)
		return
	}
	d.peersMu.Lock()
	for k, v := range loaded {
		d.peers[k] = v
	}
	d.peersMu.Unlock()
	slog.Info("loaded peers from disk", "count", len(loaded))
}

// savePeers writes the peers map to JSON file.
func (d *Daemon) savePeers() {
	d.peersMu.RLock()
	data, err := json.MarshalIndent(d.peers, "", "  ")
	d.peersMu.RUnlock()
	if err != nil {
		slog.Warn("failed to marshal peers", "error", err)
		return
	}
	if err := os.WriteFile(d.peersPath, data, 0600); err != nil {
		slog.Warn("failed to save peers file", "error", err)
	}
}

// saveGroups writes the groups map to JSON file.
func (d *Daemon) saveGroups() {
	d.groupsMu.RLock()
	data, err := json.MarshalIndent(d.groups, "", "  ")
	d.groupsMu.RUnlock()
	if err != nil {
		slog.Warn("failed to marshal groups", "error", err)
		return
	}
	if err := os.WriteFile(d.groupsPath, data, 0600); err != nil {
		slog.Warn("failed to save groups file", "error", err)
	}
}

// loadGroups reads groups from JSON file into memory.
func (d *Daemon) loadGroups() {
	data, err := os.ReadFile(d.groupsPath)
	if err != nil {
		if !os.IsNotExist(err) {
			slog.Warn("failed to read groups file", "error", err)
		}
		return
	}
	var loaded map[string]*Group
	if err := json.Unmarshal(data, &loaded); err != nil {
		slog.Warn("failed to parse groups file", "error", err)
		return
	}
	d.groupsMu.Lock()
	for k, v := range loaded {
		d.groups[k] = v
	}
	d.groupsMu.Unlock()
	slog.Info("loaded groups from disk", "count", len(loaded))
}

// loadProfile reads profile from JSON file into memory.
func (d *Daemon) loadProfile() {
	data, err := os.ReadFile(d.profilePath)
	if err != nil {
		if !os.IsNotExist(err) {
			slog.Warn("failed to read profile", "error", err)
		}
		return
	}
	var p Profile
	if err := json.Unmarshal(data, &p); err != nil {
		slog.Warn("failed to parse profile", "error", err)
		return
	}
	d.profileMu.Lock()
	d.profile = &p
	d.profileMu.Unlock()
	slog.Info("loaded profile", "nickname", p.Nickname)
}

// saveProfile writes the profile to JSON file.
func (d *Daemon) saveProfile() {
	d.profileMu.RLock()
	data, err := json.MarshalIndent(d.profile, "", "  ")
	d.profileMu.RUnlock()
	if err != nil {
		slog.Warn("failed to marshal profile", "error", err)
		return
	}
	if err := os.WriteFile(d.profilePath, data, 0600); err != nil {
		slog.Warn("failed to save profile", "error", err)
	}
}

// getMyNickname returns the user's nickname, or "Me" if not set.
func (d *Daemon) getMyNickname() string {
	d.profileMu.RLock()
	defer d.profileMu.RUnlock()
	if d.profile != nil && d.profile.Nickname != "" {
		return d.profile.Nickname
	}
	return "Me"
}

// broadcastProfileUpdate sends the user's profile to every known peer.
func (d *Daemon) broadcastProfileUpdate(nickname, bio string) {
	payload := fmt.Sprintf(`{"type":"profile_update","nickname":"%s","bio":"%s"}`,
		strings.ReplaceAll(nickname, `"`, `\"`),
		strings.ReplaceAll(bio, `"`, `\"`))
	d.peersMu.RLock()
	peers := make([]string, 0, len(d.peers))
	for pubkey := range d.peers {
		peers = append(peers, pubkey)
	}
	d.peersMu.RUnlock()

	for _, peerPubkey := range peers {
		d.sendProfileToPeer(peerPubkey, payload)
	}
}

// broadcastProfilePic uploads the picture to the relay (via TCP) and sends
// a lightweight metadata message to each peer instead of inline base64.
func (d *Daemon) broadcastProfilePic(imageData []byte, mimeType string) {
	relays := d.engine.GetRelays()
	if len(relays) == 0 {
		slog.Warn("broadcastProfilePic: no relays, skipping")
		return
	}
	fileKey, err := media.GenerateFileKey()
	if err != nil {
		slog.Warn("broadcastProfilePic: generate file key failed", "error", err)
		return
	}
	encryptedPic, err := media.EncryptFile(fileKey, imageData)
	if err != nil {
		slog.Warn("broadcastProfilePic: encrypt failed", "error", err)
		return
	}
	tcpT := media.NewTCPTransport(relays[0], d.authToken)
	var mid [8]byte
	rand.Read(mid[:])
	meta, err := tcpT.SendChunks(context.Background(), mid, encryptedPic, "profile_pic.jpg", mimeType, media.MediaTypeImage)
	if err != nil {
		slog.Warn("broadcastProfilePic: TCP upload failed", "error", err)
		return
	}
	fileKeyB64 := base64.StdEncoding.EncodeToString(fileKey)
	payload := fmt.Sprintf(`{"type":"profile_pic","file_id":"%s","file_key_b64":"%s","mime":"%s","transport":"tcp"}`,
		meta.FileID, fileKeyB64, mimeType)

	d.peersMu.RLock()
	peers := make([]string, 0, len(d.peers))
	for pubkey := range d.peers {
		peers = append(peers, pubkey)
	}
	d.peersMu.RUnlock()
	for _, peerPubkey := range peers {
		d.sendProfileToPeer(peerPubkey, payload)
	}
}

// sendProfileToPeer encrypts payload and sends it to a specific peer.
func (d *Daemon) sendProfileToPeer(peerPubkeyB64, payload string) {
	pubkey, err := base64.StdEncoding.DecodeString(peerPubkeyB64)
	if err != nil {
		return
	}
	sharedSecret, err := crypto.SharedSecret(d.identity.PrivateKey, pubkey)
	if err != nil {
		return
	}
	ciphertext, _, err := crypto.EncryptMessage(sharedSecret, []byte(payload))
	if err != nil {
		return
	}
	d.engine.SendMessage(context.Background(), ciphertext, peerPubkeyB64)
}
