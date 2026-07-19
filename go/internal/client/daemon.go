package client

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/user/dns-transport/internal/media"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
	pb "github.com/user/dns-transport/pkg/relaypb"

	"github.com/user/dns-transport/internal/crypto"
	"github.com/user/dns-transport/internal/dns"
)

type helloEntry struct {
	nonce     []byte
	pubkey    string
	nickname  string
	createdAt time.Time
}

// Daemon implements the RelayClient gRPC service.
type Daemon struct {
	pb.UnimplementedRelayClientServer

	engine      *DNSClientEngine
	detector    *Detector
	queue       *OfflineQueue
	identity    *crypto.KeyPair
		peers           map[string]*PeerInfoEntry // pubkey -> PeerInfo
		peersMu         sync.RWMutex
		peersPath       string // path to peers.json
		groups          map[string]*Group // groupID -> Group
		groupsMu        sync.RWMutex
		groupsPath      string
		dataDir         string
		grpcServer      *grpc.Server
		pendingHellos   map[string]*helloEntry
		pendingHellosMu sync.Mutex

	// Media transfer tracking
	transfers      map[string]*MediaTransfer // messageID -> transfer
	transferMu     sync.Mutex
	transferStore  *media.TransferStore

	// Auth token for gRPC
	authToken     []byte
	authTokenPath string

		debugLog *os.File // DNS debug log, written to dataDir/relayd_debug.log

		// Profile data
		profile     *Profile
		profilePath string
		profileMu   sync.RWMutex
	}

	// Profile holds the user's own profile information.
	type Profile struct {
		Nickname string `json:"nickname,omitempty"`
		Bio      string `json:"bio,omitempty"`
	}

	// PeerInfoEntry holds a peer's nickname and pubkey, keyed by pubkey.
type PeerInfoEntry struct {
	Nickname string `json:"nickname"`
	Pubkey   string `json:"pubkey"`
}

// Group represents a chat group with epoch-based key rotation.
type Group struct {
	GroupID     string                  `json:"group_id"`
	Name        string                  `json:"name"`
	AdminPubkey string                 `json:"admin_pubkey"`
	Members     map[string]*GroupMember `json:"members"` // pubkey -> member
	GroupKey    []byte                  `json:"group_key"`
	KeyEpoch    uint64                  `json:"key_epoch"`
}

// GroupMember represents a member of a group.
type GroupMember struct {
	Pubkey   string `json:"pubkey"`
	Nickname string `json:"nickname"`
	Role     string `json:"role"` // "admin" | "member"
}

// TransferStatus represents the state of a media transfer.
type TransferStatus int32

const (
	TransferQueued    TransferStatus = 0
	TransferSending   TransferStatus = 1
	TransferComplete  TransferStatus = 2
	TransferFailed    TransferStatus = 3
	TransferCancelled TransferStatus = 4
)

// MediaTransfer tracks the progress and state of a media transfer.
type MediaTransfer struct {
	mu         sync.Mutex
	Status     TransferStatus
	Progress   int32 // 0-100
	ChunksSent int32
	TotalChunks int32
	Error      string
	Created    time.Time
}

// toProtoStatus converts internal status to protobuf status enum value.
func (t *MediaTransfer) toProtoStatus() pb.MediaStatusResponse_Status {
	t.mu.Lock()
	defer t.mu.Unlock()
	switch t.Status {
	case TransferQueued:
		return pb.MediaStatusResponse_QUEUED
	case TransferSending:
		return pb.MediaStatusResponse_SENDING
	case TransferComplete:
		return pb.MediaStatusResponse_COMPLETE
	case TransferFailed:
		return pb.MediaStatusResponse_FAILED
	case TransferCancelled:
		return pb.MediaStatusResponse_FAILED
	default:
		return pb.MediaStatusResponse_QUEUED
	}
}

// getProgress returns the current progress safely.
func (t *MediaTransfer) getProgress() int32 {
	t.mu.Lock()
	defer t.mu.Unlock()
	return t.Progress
}

// getError returns the error string safely.
func (t *MediaTransfer) getError() string {
	t.mu.Lock()
	defer t.mu.Unlock()
	return t.Error
}

// RunDaemon starts the client daemon with gRPC server, DNS engine, and offline queue.
func RunDaemon(grpcPort int, relays []string, zone string, dataDir string, forceBlackout bool, dnsResolver string) error {
	t0 := time.Now()
	// Write startup progress to a file Flutter can read
	startupLog := func(msg string) {
		elapsed := time.Since(t0)
		slog.Info("daemon startup", "msg", msg, "elapsed", elapsed)
		// Also write to file in data dir for Flutter to read
		if dataDir != "" {
			os.WriteFile(filepath.Join(dataDir, "startup.log"), []byte(fmt.Sprintf("[%v] %s\n", elapsed, msg)), 0644)
		}
	}

	startupLog("begin")

	// Ensure data directory
	if err := os.MkdirAll(dataDir, 0700); err != nil {
		return err
	}
	startupLog("data dir ready")

	// Load or create identity
	identityPath := filepath.Join(dataDir, "identity.key")
	identity, err := crypto.LoadIdentity(identityPath)
	if err != nil {
		slog.Info("no identity found, generating new keypair")
		identity, err = crypto.GenerateKeyPair()
		if err != nil {
			return err
		}
		if err := crypto.SaveIdentity(identityPath, identity); err != nil {
			return err
		}
	}
	startupLog("identity ready")
	
	// Generate or load auth token for gRPC
	authTokenPath := filepath.Join(dataDir, "auth_token")
	authToken, err := loadOrGenerateAuthToken(authTokenPath)
	if err != nil {
		return fmt.Errorf("auth token: %w", err)
	}
	startupLog("auth token ready")

	// Open offline queue
	queue, err := NewOfflineQueue(filepath.Join(dataDir, "queue.db"))
	if err != nil {
		return err
	}
	startupLog("queue ready")

	// Determine relays: merge file relays with method-channel relays, deduplicate.
	var engineRelays []string
	fileRelays := loadRelaysFromConfig(dataDir)
	seen := make(map[string]bool)
	for _, r := range fileRelays {
		if !seen[r] {
			seen[r] = true
			engineRelays = append(engineRelays, r)
		}
	}
	for _, r := range relays {
		if !seen[r] {
			seen[r] = true
			engineRelays = append(engineRelays, r)
		}
	}
	if len(engineRelays) == 0 {
		slog.Warn("no relay endpoints configured")
	}
	if len(engineRelays) > 0 {
		slog.Info("using relays", "relays", engineRelays)
	}
	startupLog("relays merged")

	// Create DNS engine
	engine := NewDNSClientEngine(engineRelays, zone)
	engine.SetDNSResolver(dnsResolver)
	engine.SetDebugLogPath(filepath.Join(dataDir, "relayd_debug.log"))
	startupLog("DNS engine ready")

	// Create network detector
	detector := NewDetector(forceBlackout, len(engineRelays))
	detector.Check() // initial check
	slog.Info("network mode", "blackout", detector.CurrentMode() == ModeBlackout)

	// Create daemon
	daemon := &Daemon{
		engine:        engine,
		detector:      detector,
		queue:         queue,
		identity:      identity,
		peers:         make(map[string]*PeerInfoEntry),
			peersPath:     filepath.Join(dataDir, "daemon_peers.json"),
			groups:        make(map[string]*Group),
			groupsPath:    filepath.Join(dataDir, "daemon_groups.json"),
			dataDir:       dataDir,
		transfers:     make(map[string]*MediaTransfer),
		authToken:     authToken,
		authTokenPath: authTokenPath,
		pendingHellos: make(map[string]*helloEntry),
	}
	// Open debug log (append, create if missing)
	dl, err := os.OpenFile(filepath.Join(dataDir, "relayd_debug.log"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err == nil {
		daemon.debugLog = dl
	}
	daemon.loadPeers()
	daemon.loadGroups()
	// Load profile (nickname, bio)
	daemon.profilePath = filepath.Join(dataDir, "profile.json")
	daemon.loadProfile()
	// Open transfer store for resume support
	ts, err := media.NewTransferStore(filepath.Join(dataDir, "media_transfers.db"))
	if err != nil {
		slog.Warn("failed to open transfer store, resume disabled", "error", err)
	} else {
		daemon.transferStore = ts
	}
	startupLog("struct ready")

	// Start gRPC server
	lis, err := net.Listen("tcp", net.JoinHostPort("127.0.0.1", strconv.Itoa(grpcPort)))
	if err != nil {
		return err
	}
	startupLog("gRPC listener ready")

	s := grpc.NewServer(
		grpc.MaxRecvMsgSize(100*1024*1024), // 100 MB max receive
		grpc.MaxSendMsgSize(100*1024*1024), // 100 MB max send
		grpc.UnaryInterceptor(daemon.authInterceptor),
	)
	pb.RegisterRelayClientServer(s, daemon)
	daemon.grpcServer = s

	// Start periodic network check
	go func() {
		for {
			time.Sleep(60 * time.Second)
			mode := detector.Check()
			slog.Info("network check", "blackout", mode == ModeBlackout)
		}
	}()

	// Start offline queue processor
	go daemon.processQueue()

	// Start transfer cleanup goroutine (every 5 minutes)
	go daemon.cleanupTransfers()

	// Start transport mode file watcher (reads dataDir/transport_mode every 5s)
	go daemon.watchTransportMode()

	// Start chunk size file watcher (reads dataDir/chunk_size every 5s)
	go daemon.watchChunkSize()

	startupLog("gRPC registered, about to serve")
	slog.Info("client daemon listening", "grpc", grpcPort, "pubkey", base64.StdEncoding.EncodeToString(identity.PublicKey), "elapsed", time.Since(t0))
	return s.Serve(lis)
}

// loadRelaysFromConfig reads fallback relays from relays.json in dataDir.
func loadRelaysFromConfig(dataDir string) []string {
	configPath := filepath.Join(dataDir, "relays.json")
	data, err := os.ReadFile(configPath)
	if err != nil {
		return nil
	}
	var cfg struct {
		Relays []string `json:"relays"`
	}
	if err := json.Unmarshal(data, &cfg); err != nil {
		slog.Warn("failed to parse relays config", "path", configPath, "error", err)
		return nil
	}
	return cfg.Relays
}

const authTokenLen = 32

// loadOrGenerateAuthToken reads an existing auth token or generates a new one.
// Token is stored as hex-encoded string (64 hex chars = 32 bytes).
func loadOrGenerateAuthToken(path string) ([]byte, error) {
	data, err := os.ReadFile(path)
	if err == nil && len(data) == authTokenLen*2 {
		// Already hex-encoded, return as-is
		d := make([]byte, len(data))
		copy(d, data)
		return d, nil
	}
	token := make([]byte, authTokenLen)
	if _, err := rand.Read(token); err != nil {
		return nil, fmt.Errorf("generate auth token: %w", err)
	}
	// Store as hex string so it's valid UTF-8 for gRPC metadata
	tokenHex := hex.EncodeToString(token)
	if err := os.WriteFile(path, []byte(tokenHex), 0600); err != nil {
		return nil, fmt.Errorf("save auth token: %w", err)
	}
	return []byte(tokenHex), nil
}

// authInterceptor validates the x-auth-token metadata on every gRPC call.
// GetIdentity is exempted so Flutter can check daemon readiness before auth.
func (d *Daemon) authInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
	if d.authToken == nil {
		return handler(ctx, req)
	}
	// Allow GetIdentity without auth (used for readiness polling)
	if strings.Contains(info.FullMethod, "GetIdentity") {
		return handler(ctx, req)
	}
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "missing metadata")
	}
	tokens := md["x-auth-token"]
	if len(tokens) == 0 {
		return nil, status.Error(codes.Unauthenticated, "missing auth token")
	}
		if len(tokens[0]) != authTokenLen*2 {
		return nil, status.Error(codes.Unauthenticated, "invalid auth token")
	}
	// Constant-time comparison to prevent timing attacks
	if subtle.ConstantTimeCompare(d.authToken, []byte(tokens[0])) != 1 {
		return nil, status.Error(codes.Unauthenticated, "invalid auth token")
	}
	return handler(ctx, req)
}

// debugWrite writes a line to the debug log file (if open).
func (d *Daemon) debugWrite(format string, args ...interface{}) {
	if d.debugLog == nil {
		return
	}
	fmt.Fprintf(d.debugLog, "[%s] ", time.Now().Format("15:04:05.000"))
	fmt.Fprintf(d.debugLog, format, args...)
	fmt.Fprintf(d.debugLog, "\n")
}

// SendMessage encrypts and sends a message via DNS engine, falling back to offline queue.
func (d *Daemon) SendMessage(ctx context.Context, req *pb.SendRequest) (*pb.SendResponse, error) {
	if d.identity == nil {
		return nil, status.Error(codes.FailedPrecondition, "identity not initialized")
	}
	d.debugWrite("SendMessage start peer_pubkey=%s text_len=%d", req.PeerPubkey[:min(16, len(req.PeerPubkey))], len(req.Plaintext))

	// If group_id is set, handle as group message
	if req.GroupId != "" {
		d.groupsMu.RLock()
		group, ok := d.groups[req.GroupId]
		d.groupsMu.RUnlock()
		if !ok {
			return nil, status.Errorf(codes.NotFound, "group not found: %s", req.GroupId)
		}
		// Encrypt plaintext with group key
		ciphertext, err := crypto.EncryptGroupMessage(group.GroupKey, req.Plaintext)
		if err != nil {
			return nil, status.Error(codes.Internal, "encrypt group message failed")
		}
		// Wrap in group message envelope
		groupPayload := fmt.Sprintf(`{"g":"%s","e":%d,"m":"%s"}`,
			req.GroupId, group.KeyEpoch, base64.StdEncoding.EncodeToString(ciphertext))
		// Send to each member individually
		myPubkey := base64.StdEncoding.EncodeToString(d.identity.PublicKey)
		for pubkey := range group.Members {
			if pubkey == myPubkey {
				continue
			}
			d.engine.SendMessage(ctx, []byte(groupPayload), pubkey)
		}
		return &pb.SendResponse{MessageId: "group:" + req.GroupId, Queued: false, ChunkCount: 0}, nil
	}

	// Decrypt peer pubkey
	peerPubkey, err := base64.StdEncoding.DecodeString(req.PeerPubkey)
	if err != nil {
		return nil, err
	}
	sharedSecret, err := crypto.SharedSecret(d.identity.PrivateKey, peerPubkey)
	if err != nil {
		return nil, err
	}
	// Build signed payload with Ed25519 signature
	signedPayload := crypto.BuildSignedPayload(d.identity, req.Plaintext)
	ciphertext, nonce, err := crypto.EncryptMessage(sharedSecret, signedPayload)
	if err != nil {
		return nil, err
	}
	// Prepend nonce to ciphertext for transport
	transportPayload := append(nonce, ciphertext...)

	// Try send via DNS engine
	msgID, chunkCount, err := d.engine.SendMessage(ctx, transportPayload, req.PeerPubkey)
	if err != nil {
		// Queue ciphertext offline (already encrypted)
		d.debugWrite("SendMessage DNS FAILED: %v -- queueing offline", err)
		slog.Warn("send failed, queueing offline", "error", err)
		_, qErr := d.queue.Enqueue(req.PeerPubkey, transportPayload)
		if qErr != nil {
			return nil, qErr
		}
		return &pb.SendResponse{
			MessageId:  base64.StdEncoding.EncodeToString(msgID[:]),
			Queued:     true,
			ChunkCount: 0,
		}, nil
	}

	d.debugWrite("SendMessage DNS OK chunk_count=%d", chunkCount)
	return &pb.SendResponse{
		MessageId:  base64.StdEncoding.EncodeToString(msgID[:]),
		Queued:     false,
		ChunkCount: int32(chunkCount),
	}, nil
}

// PollMessages polls relays for pending messages and returns them.
func (d *Daemon) PollMessages(ctx context.Context, req *pb.PollRequest) (*pb.PollResponse, error) {
	if d.identity == nil {
		return &pb.PollResponse{}, nil
	}
	myPubkey := base64.StdEncoding.EncodeToString(d.identity.PublicKey)
	d.debugWrite("PollMessages: start myPubkey=%s", myPubkey[:min(24, len(myPubkey))])
	polled, err := d.engine.PollMessages(myPubkey)
	if err != nil {
		d.debugWrite("PollMessages: engine.PollMessages FAILED err=%v", err)
		slog.Warn("poll messages failed", "error", err)
		return &pb.PollResponse{}, nil
	}
	d.debugWrite("PollMessages: engine returned %d messages", len(polled))

	var resp pb.PollResponse
	for _, pm := range polled {
		raw := pm.Data
		if len(raw) < crypto.NonceLength {
			d.debugWrite("PollMessages: message too short len=%d", len(raw))
			continue
		}
		nonce := raw[:crypto.NonceLength]
		ciphertext := raw[crypto.NonceLength:]

		// Try to decrypt with each peer's shared secret
		var decrypted []byte
		var fromPeer string
		d.peersMu.RLock()
		peersSnapshot := make(map[string]*PeerInfoEntry, len(d.peers))
		for k, v := range d.peers {
			peersSnapshot[k] = v
		}
		d.peersMu.RUnlock()
		d.debugWrite("PollMessages: decrypt trying %d peers msgID=%x", len(peersSnapshot), pm.MsgID)
		for pubkeyStr, peerInfo := range peersSnapshot {
			pubkey, err := base64.StdEncoding.DecodeString(pubkeyStr)
			if err != nil {
				d.debugWrite("PollMessages: bad pubkey for peer %s", peerInfo.Nickname)
				continue
			}
			ss, err := crypto.SharedSecret(d.identity.PrivateKey, pubkey)
			if err != nil {
				d.debugWrite("PollMessages: shared secret failed for peer %s", peerInfo.Nickname)
				continue
			}
			plaintext, err := crypto.DecryptMessage(ss, nonce, ciphertext)
			if err != nil {
				d.debugWrite("PollMessages: decrypt failed for peer %s err=%v", peerInfo.Nickname, err)
				continue
			}
			// Verify and parse signed payload
			senderX25519, _, msgPlaintext, sigVerified, parseErr := crypto.ParseSignedPayload(plaintext)
			if parseErr != nil || senderX25519 == "" {
				// Fallback: treat as unsigned plaintext
				d.debugWrite("PollMessages: parse failed for msgID=%x err=%v", pm.MsgID, parseErr)
				decrypted = plaintext
				fromPeer = pubkeyStr
			} else {
				fromPeer = senderX25519
				decrypted = msgPlaintext
				if !sigVerified {
					d.debugWrite("PollMessages: INVALID signature from sender=%s msgID=%x", senderX25519, pm.MsgID)
				} else {
					d.debugWrite("PollMessages: signature OK from sender=%s msgID=%x", senderX25519, pm.MsgID)
				}
			}
			d.debugWrite("PollMessages: decrypted OK from peer=%s text_len=%d", fromPeer, len(decrypted))
			break
		}
		// If decryption failed for all known peers, try pending hello keys
		if decrypted == nil {
			d.pendingHellosMu.Lock()
			for nonceHex, entry := range d.pendingHellos {
				if time.Since(entry.createdAt) > 24*time.Hour {
					delete(d.pendingHellos, nonceHex)
					continue
				}
				helloKey := crypto.DeriveHelloKey(entry.nonce)
				plaintext, err := crypto.DecryptHello(helloKey, raw)
				if err != nil {
					continue
				}
				var hello struct {
					Type     string `json:"type"`
					Pubkey   string `json:"pubkey"`
					Nickname string `json:"nickname"`
				}
				if json.Unmarshal(plaintext, &hello) == nil && hello.Type == "hello" && hello.Pubkey != "" {
					nick := hello.Nickname
					if nick == "" {
						nick = "Unknown"
					}
					d.peersMu.Lock()
					d.peers[hello.Pubkey] = &PeerInfoEntry{Nickname: nick, Pubkey: hello.Pubkey}
					d.peersMu.Unlock()
					d.savePeers()
					decrypted = plaintext
					fromPeer = hello.Pubkey
					delete(d.pendingHellos, nonceHex)
					d.debugWrite("PollMessages: auto-added peer via hello %s", hello.Pubkey[:min(16, len(hello.Pubkey))])
				}
			}
			d.pendingHellosMu.Unlock()
			}
				if decrypted == nil {
					d.debugWrite("PollMessages: could not decrypt msgID=%x from any known peer", pm.MsgID)
					continue
				}

				// Check for group key distribution message
				if len(decrypted) > 10 && decrypted[0] == '{' {
					var keyDist struct {
						Type        string `json:"type"`
						GroupID     string `json:"group_id"`
						GroupKeyB64 string `json:"group_key_b64"`
						KeyEpoch    uint64 `json:"key_epoch"`
						Name        string `json:"name"`
					}
					if json.Unmarshal(decrypted, &keyDist) == nil && keyDist.Type == "group_key" && keyDist.GroupKeyB64 != "" {
						groupKey, _ := base64.StdEncoding.DecodeString(keyDist.GroupKeyB64)
						d.groupsMu.Lock()
						if _, exists := d.groups[keyDist.GroupID]; !exists {
							d.groups[keyDist.GroupID] = &Group{
								GroupID:     keyDist.GroupID,
								Name:        keyDist.Name,
								AdminPubkey: "",
								Members:     make(map[string]*GroupMember),
								GroupKey:    groupKey,
								KeyEpoch:    keyDist.KeyEpoch,
							}
						} else {
							d.groups[keyDist.GroupID].GroupKey = groupKey
							d.groups[keyDist.GroupID].KeyEpoch = keyDist.KeyEpoch
						}
						d.groupsMu.Unlock()
						d.saveGroups()
						continue // Don't add as a text message
					}
				}

				// Check for group message format: {"g":"group_id","e":epoch,"m":"base64_ciphertext"}
				groupID := ""
				if len(decrypted) > 10 && decrypted[0] == '{' {
					var groupMeta struct {
						G    string `json:"g"`
						E    uint64 `json:"e"`
						MB64 string `json:"m"`
					}
					if json.Unmarshal(decrypted, &groupMeta) == nil && groupMeta.G != "" && groupMeta.MB64 != "" {
						d.groupsMu.RLock()
						group, hasGroup := d.groups[groupMeta.G]
						d.groupsMu.RUnlock()
						if hasGroup {
							if groupMeta.E < group.KeyEpoch {
								d.debugWrite("PollMessages: ignoring stale group message (epoch %d < %d)", groupMeta.E, group.KeyEpoch)
								continue
							}
							msgBytes, err := base64.StdEncoding.DecodeString(groupMeta.MB64)
							if err == nil {
								msgPlaintext, err := crypto.DecryptGroupMessage(group.GroupKey, msgBytes)
								if err == nil {
									decrypted = msgPlaintext
									groupID = groupMeta.G
								}
							}
						}
					}
				}

					// Check for JSON-typed messages: profile updates, profile pics, media metadata.
					// Only recognized types skip the text message path; everything else falls through.
					if len(decrypted) > 20 && decrypted[0] == '{' {
						// Check for profile update messages
						var profileMsg struct {
							Type         string `json:"type"`
							Nickname     string `json:"nickname"`
							Bio          string `json:"bio"`
							FileID       string `json:"file_id"`
							FileKeyB64   string `json:"file_key_b64"`
							Transport    string `json:"transport"`
							Mime         string `json:"mime"`
						}
						if json.Unmarshal(decrypted, &profileMsg) == nil && profileMsg.Type == "profile_update" && fromPeer != "" {
							d.peersMu.Lock()
							if entry, ok := d.peers[fromPeer]; ok && profileMsg.Nickname != "" {
								entry.Nickname = profileMsg.Nickname
								d.debugWrite("PollMessages: profile_update from=%s nickname=%s", fromPeer[:min(16, len(fromPeer))], profileMsg.Nickname)
							}
							d.peersMu.Unlock()
							d.savePeers()
							// Also save bio to a file so Flutter can read it
							if profileMsg.Bio != "" {
								bioDir := filepath.Join(d.dataDir, "peer_bios")
								os.MkdirAll(bioDir, 0700)
								bioPath := filepath.Join(bioDir, fromPeer+".json")
								bioJSON, _ := json.Marshal(map[string]string{"bio": profileMsg.Bio})
								os.WriteFile(bioPath, bioJSON, 0600)
							}
							continue
						}
						if json.Unmarshal(decrypted, &profileMsg) == nil && profileMsg.Type == "profile_pic" && fromPeer != "" && profileMsg.FileID != "" {
							// Profile pic sent via TCP relay — download, decrypt, save
							relays := d.engine.GetRelays()
							if len(relays) > 0 {
fileKey, _ := base64.StdEncoding.DecodeString(profileMsg.FileKeyB64)
									tcpT := media.NewTCPTransport(relays[0], d.authToken)
									encryptedPic, err := tcpT.DownloadFile(ctx, profileMsg.FileID)
								if err == nil && fileKey != nil {
									picData, err := media.DecryptFile(fileKey, encryptedPic)
									if err == nil && len(picData) > 0 {
										picDir := filepath.Join(d.dataDir, "peer_pics")
										os.MkdirAll(picDir, 0700)
										picPath := filepath.Join(picDir, fromPeer+".jpg")
										os.WriteFile(picPath, picData, 0600)
										d.debugWrite("PollMessages: profile_pic saved for %s (%d bytes)", fromPeer[:min(16, len(fromPeer))], len(picData))
									}
								}
							}
							continue
						}

							// Media metadata check
							var maybeMeta struct {
								FileKeyB64 string `json:"file_key_b64"`
								MimeType   string `json:"mime_type"`
								FileName   string `json:"file_name"`
								FileID     string `json:"file_id"`
							}
							if json.Unmarshal(decrypted, &maybeMeta) == nil && maybeMeta.FileKeyB64 != "" {
								fileKey, _ := base64.StdEncoding.DecodeString(maybeMeta.FileKeyB64)
								relays := d.engine.GetRelays()
								if len(relays) == 0 {
									d.debugWrite("PollMessages: no relays for media download")
									continue
								}
								relay := relays[0]

								var fileData []byte

								if maybeMeta.FileID != "" {
									d.debugWrite("PollMessages: downloading TCP media msgID=%x fileID=%s", pm.MsgID, maybeMeta.FileID)
									tcpT := media.NewTCPTransport(relay, d.authToken)
									encryptedFile, err := tcpT.DownloadFile(ctx, maybeMeta.FileID)
									if err != nil {
										d.debugWrite("PollMessages: TCP download failed fileID=%s err=%v", maybeMeta.FileID, err)
									} else if fileKey != nil {
										fileData, err = media.DecryptFile(fileKey, encryptedFile)
										if err != nil {
											d.debugWrite("PollMessages: TCP media decrypt failed err=%v", err)
										}
									}
								}

							// Save media file (or placeholder) + meta sidecar
							ext := ".bin"
							if maybeMeta.MimeType == "image/jpeg" {
								ext = ".jpg"
							} else if maybeMeta.MimeType == "image/png" {
								ext = ".png"
							} else if maybeMeta.MimeType == "video/mp4" {
								ext = ".mp4"
							} else if maybeMeta.MimeType == "audio/m4a" {
								ext = ".m4a"
							}
								recvDir := filepath.Join(d.dataDir, "media_received")
								os.MkdirAll(recvDir, 0700)
								mediaMsgID := hex.EncodeToString(pm.MsgID[:])
								filePath := filepath.Join(recvDir, mediaMsgID+ext)

								// Write meta sidecar FIRST so Flutter's file scanner
								// never sees a body without its metadata.
								status := "complete"
								if fileData == nil {
									status = "failed"
								}
								metaPath := filePath + ".meta"
								metaJSON, _ := json.Marshal(map[string]string{
									"mime":               maybeMeta.MimeType,
									"filename":           maybeMeta.FileName,
									"sender_pubkey":      fromPeer,
									"server_timestamp_ms": fmt.Sprintf("%d", pm.Timestamp),
									"status":             status,
								})
								os.WriteFile(metaPath, metaJSON, 0600)

								// Write body file (only after meta is safely on disk)
								if fileData != nil {
									if err := os.WriteFile(filePath, fileData, 0600); err != nil {
										d.debugWrite("PollMessages: media save failed err=%v", err)
									} else {
										d.debugWrite("PollMessages: media saved to %s", filePath)
									}
								} else {
									d.debugWrite("PollMessages: media download failed for %s, saving placeholder", mediaMsgID)
									os.WriteFile(filePath, []byte{}, 0600)
								}
							// Don't add media metadata as a text message
							continue
						}
					}

		msgID := hex.EncodeToString(pm.MsgID[:])
		received := &pb.ReceivedMessage{
				MessageId: msgID,
				Plaintext: decrypted,
				FromPeer:  fromPeer,
				GroupId:   groupID,
			}
		// Populate relay-stamped metadata if available
		if pm.Timestamp > 0 {
			received.ServerTimestampMs = uint64(pm.Timestamp)
		}
		if pm.Sequence > 0 {
			received.SequenceNumber = pm.Sequence
		}
			resp.Messages = append(resp.Messages, received)
		}
	return &resp, nil
}

// GetRelayStatus returns the status of all configured relays.
func (d *Daemon) GetRelayStatus(ctx context.Context, req *pb.Empty) (*pb.RelayStatusList, error) {
	mode := d.detector.CurrentMode()
	relays := d.engine.GetRelays()
	endpoints := make([]*pb.RelayStatus, 0, len(relays))
	for _, r := range relays {
		endpoints = append(endpoints, &pb.RelayStatus{
			Address:      r,
			Reachable:    mode == ModeNormal,
			LatencyMs:    0,
			LastError:    "",
			BlackoutMode: mode == ModeBlackout,
		})
	}
	return &pb.RelayStatusList{Endpoints: endpoints}, nil
}

// AddRelay adds a relay endpoint to the engine.
func (d *Daemon) AddRelay(ctx context.Context, req *pb.RelayEndpoint) (*pb.Empty, error) {
	relays := append(d.engine.GetRelays(), req.Address)
	d.engine.SetRelays(relays)
	return &pb.Empty{}, nil
}

// RemoveRelay removes a relay endpoint from the engine.
func (d *Daemon) RemoveRelay(ctx context.Context, req *pb.RelayEndpoint) (*pb.Empty, error) {
	relays := d.engine.GetRelays()
	var updated []string
	for _, r := range relays {
		if r != req.Address {
			updated = append(updated, r)
		}
	}
	d.engine.SetRelays(updated)
	return &pb.Empty{}, nil
}

// GetIdentity returns the daemon's public key and profile info.
func (d *Daemon) GetIdentity(ctx context.Context, req *pb.Empty) (*pb.IdentityInfo, error) {
	d.profileMu.RLock()
	nickname := ""
	bio := ""
	if d.profile != nil {
		nickname = d.profile.Nickname
		bio = d.profile.Bio
	}
	d.profileMu.RUnlock()
	return &pb.IdentityInfo{
		Pubkey:   base64.StdEncoding.EncodeToString(d.identity.PublicKey),
		Nickname: nickname,
		Bio:      bio,
	}, nil
}

// AddPeer stores a peer mapping and persists to disk.
func (d *Daemon) AddPeer(ctx context.Context, req *pb.PeerInfo) (*pb.Empty, error) {
	// Validate pubkey is valid base64
	pubkeyBytes, err := base64.StdEncoding.DecodeString(req.Pubkey)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid public key: not valid base64: %v", err)
	}
	if len(pubkeyBytes) != crypto.KeyLength {
		return nil, status.Errorf(codes.InvalidArgument, "invalid public key: expected %d bytes, got %d", crypto.KeyLength, len(pubkeyBytes))
	}

	d.peersMu.Lock()
	d.peers[req.Pubkey] = &PeerInfoEntry{Nickname: req.Nickname, Pubkey: req.Pubkey}
	d.peersMu.Unlock()
	d.savePeers()
	return &pb.Empty{}, nil
}

// RemovePeer removes a peer from the peers map and persists.
func (d *Daemon) RemovePeer(ctx context.Context, req *pb.PeerInfo) (*pb.Empty, error) {
	d.peersMu.Lock()
	delete(d.peers, req.Pubkey)
	d.peersMu.Unlock()
	d.savePeers()
	return &pb.Empty{}, nil
}

// GenerateInviteCode creates an invite code that can be shared with another user.
func (d *Daemon) GenerateInviteCode(ctx context.Context, req *pb.GenerateInviteCodeRequest) (*pb.GenerateInviteCodeResponse, error) {
	myPubkey := base64.StdEncoding.EncodeToString(d.identity.PublicKey)
	nickname := req.Nickname
	if nickname == "" {
		nickname = d.getMyNickname()
		if nickname == "" {
			nickname = "Me"
		}
	}
	code, nonce, err := crypto.GenerateInviteCode(d.identity.PublicKey, nickname)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	d.pendingHellosMu.Lock()
	d.pendingHellos[hex.EncodeToString(nonce)] = &helloEntry{
		nonce:     nonce,
		pubkey:    myPubkey,
		nickname:  nickname,
		createdAt: time.Now(),
	}
	d.pendingHellosMu.Unlock()
	return &pb.GenerateInviteCodeResponse{Code: code}, nil
}

// JoinViaCode parses an invite code, adds the inviter as a peer, and sends a hello message.
func (d *Daemon) JoinViaCode(ctx context.Context, req *pb.JoinViaCodeRequest) (*pb.JoinViaCodeResponse, error) {
		remotePubkey, nonce, nickname, err := crypto.ParseInviteCode(req.Code)
		if err != nil {
			return nil, status.Errorf(codes.InvalidArgument, "invalid invite code: %v", err)
		}
		remotePubkeyB64 := base64.StdEncoding.EncodeToString(remotePubkey)

		// Add remote as a peer
		d.peersMu.Lock()
		d.peers[remotePubkeyB64] = &PeerInfoEntry{Nickname: nickname, Pubkey: remotePubkeyB64}
		d.peersMu.Unlock()
		d.savePeers()

		// Derive hello key from nonce and send hello message
		helloKey := crypto.DeriveHelloKey(nonce)
		myPubkeyB64 := base64.StdEncoding.EncodeToString(d.identity.PublicKey)
		myNickname := d.getMyNickname()
		helloPayload := fmt.Sprintf(`{"type":"hello","pubkey":"%s","nickname":"%s"}`, myPubkeyB64, myNickname)
		encryptedHello, err := crypto.EncryptHello(helloKey, []byte(helloPayload))
		if err != nil {
			return nil, status.Error(codes.Internal, "encrypt hello failed")
		}

		// Send via relay (plaintext = encrypted hello, no ECDH wrapper)
		_, _, err = d.engine.SendMessage(ctx, encryptedHello, remotePubkeyB64)
		if err != nil {
			d.queue.Enqueue(remotePubkeyB64, encryptedHello)
		}

		return &pb.JoinViaCodeResponse{
			PeerNickname: nickname,
			PeerPubkey:   remotePubkeyB64,
			}, nil
		}

	// UpdateProfile saves the user's nickname and bio, then broadcasts to all peers.
	func (d *Daemon) UpdateProfile(ctx context.Context, req *pb.ProfileInfo) (*pb.Empty, error) {
		d.profileMu.Lock()
		if d.profile == nil {
			d.profile = &Profile{}
		}
		d.profile.Nickname = req.Nickname
		d.profile.Bio = req.Bio
		d.profileMu.Unlock()
		d.saveProfile()
		slog.Info("profile updated", "nickname", req.Nickname)

		// Broadcast profile to all known peers
		go d.broadcastProfileUpdate(req.Nickname, req.Bio)

		return &pb.Empty{}, nil
	}

	// broadcastProfileUpdate sends the user's profile to every known peer.
	// sendProfileToPeer encrypts payload and sends it to a specific peer.

	// GetProfilePic returns the user's profile picture.
	func (d *Daemon) GetProfilePic(ctx context.Context, req *pb.Empty) (*pb.ProfilePicResponse, error) {
		picPath := filepath.Join(d.dataDir, "profile_pic.jpg")
		data, err := os.ReadFile(picPath)
		if err != nil {
			return &pb.ProfilePicResponse{}, nil // no pic, return empty
		}
		return &pb.ProfilePicResponse{
			ImageData: data,
			MimeType:  "image/jpeg",
		}, nil
	}

	// SetProfilePic saves the user's profile picture and broadcasts to peers.
	func (d *Daemon) SetProfilePic(ctx context.Context, req *pb.SetProfilePicRequest) (*pb.Empty, error) {
		if len(req.ImageData) > 5*1024*1024 {
			return nil, status.Error(codes.InvalidArgument, "image too large (max 5MB)")
		}
		picPath := filepath.Join(d.dataDir, "profile_pic.jpg")
		if err := os.WriteFile(picPath, req.ImageData, 0600); err != nil {
			return nil, status.Error(codes.Internal, "failed to save profile picture")
		}
		slog.Info("profile picture saved", "size", len(req.ImageData))

		// Broadcast profile pic to all peers
		go d.broadcastProfilePic(req.ImageData, req.MimeType)

		return &pb.Empty{}, nil
	}

	// broadcastProfilePic uploads the picture to the relay (via TCP) and sends
	// a lightweight metadata message to each peer instead of inline base64 (which
	// is too large for DNS chunking within the 10s deadline).

	// ListPeers returns all known peers from the daemon.
func (d *Daemon) ListPeers(ctx context.Context, req *pb.Empty) (*pb.ListPeersResponse, error) {
	d.peersMu.RLock()
	defer d.peersMu.RUnlock()
	var pbPeers []*pb.PeerInfo
	for _, p := range d.peers {
		pbPeers = append(pbPeers, &pb.PeerInfo{
			Nickname: p.Nickname,
			Pubkey:   p.Pubkey,
		})
	}
	return &pb.ListPeersResponse{Peers: pbPeers}, nil
}

// CreateGroup creates a new chat group, generates a group key, and distributes it to all members.

// ListGroups returns all groups this node is a member of.

// LeaveGroup removes the current node from a group. If admin leaves, reassigns admin.
// If no members remain, the group is deleted.

// RemoveGroupMember removes a member from a group (admin only). Rotates group key.

// loadPeers reads peers from JSON file into memory.
// savePeers writes the peers map to JSON file.
// saveGroups writes the groups map to JSON file.
// loadGroups reads groups from JSON file into memory.
// loadProfile reads profile from JSON file into memory.
// saveProfile writes the profile to JSON file.
// getMyNickname returns the user's nickname, or "Me" if not set.
// GetTransportStatus returns the current transport layer status.
func (d *Daemon) GetTransportStatus(ctx context.Context, req *pb.Empty) (*pb.TransportStatusResponse, error) {
	status := &pb.TransportStatusResponse{
		DnsMode: "normal",
	}
	mode := d.detector.CurrentMode()
	if mode == ModeBlackout {
		status.DnsMode = "blackout"
	}
	return status, nil
}

// SendMedia sends media data (file, image, etc.) to a peer over TCP transport.
func (d *Daemon) SendMedia(ctx context.Context, req *pb.SendMediaRequest) (*pb.SendMediaResponse, error) {
	transport := "tcp"
	estimatedSec := int32(len(req.MediaData) / (100 * 1024) * 100 / 1000)
	if estimatedSec < 5 {
		estimatedSec = 5
	}
	msgID := fmt.Sprintf("%x", time.Now().UnixNano())

	// Create transfer tracking entry
	transfer := &MediaTransfer{
		Status:  TransferQueued,
		Progress: 0,
		Created: time.Now(),
	}
	d.transferMu.Lock()
	d.transfers[msgID] = transfer
	d.transferMu.Unlock()

	var meta *media.MediaMessage
	var mid [8]byte
	rand.Read(mid[:])
	var err error

	// TCP path — upload file to relay's HTTP media server
	relays := d.engine.GetRelays()
	if len(relays) == 0 {
		transfer.mu.Lock()
		transfer.Status = TransferFailed
		transfer.Error = "no relays configured for TCP upload"
		transfer.mu.Unlock()
		return nil, status.Error(codes.FailedPrecondition, "no relays configured")
	}
	tcpTransport := media.NewTCPTransport(relays[0], d.authToken)
	
	// Update status to sending before upload
	transfer.mu.Lock()
	transfer.Status = TransferSending
	transfer.Progress = 10
	transfer.mu.Unlock()
	
	meta, err = tcpTransport.SendChunks(ctx, mid, req.MediaData, req.Filename, req.MimeType, media.MediaTypeFile)
	if err != nil {
		transfer.mu.Lock()
		transfer.Status = TransferFailed
		transfer.Error = err.Error()
		transfer.mu.Unlock()
		return nil, fmt.Errorf("TCP upload: %w", err)
	}

	// Update progress after upload
	transfer.mu.Lock()
	transfer.Progress = 50
	transfer.mu.Unlock()

	meta.Timestamp = time.Now().UnixMilli()
	meta.MessageID = msgID

	// Send metadata as E2E-encrypted message addressed to peer
	metaBytes, err := meta.Marshal()
	if err != nil {
		transfer.mu.Lock()
		transfer.Status = TransferFailed
		transfer.Error = err.Error()
		transfer.mu.Unlock()
		return nil, err
	}
	peerPubkey, err := base64.StdEncoding.DecodeString(req.PeerPubkey)
	if err != nil {
		transfer.mu.Lock()
		transfer.Status = TransferFailed
		transfer.Error = err.Error()
		transfer.mu.Unlock()
		return nil, err
	}
	sharedSecret, err := crypto.SharedSecret(d.identity.PrivateKey, peerPubkey)
	if err != nil {
		transfer.mu.Lock()
		transfer.Status = TransferFailed
		transfer.Error = err.Error()
		transfer.mu.Unlock()
		return nil, err
	}
	ciphertext, _, err := crypto.EncryptMessage(sharedSecret, metaBytes)
	if err != nil {
		transfer.mu.Lock()
		transfer.Status = TransferFailed
		transfer.Error = err.Error()
		transfer.mu.Unlock()
		return nil, err
	}
	if _, _, err := d.engine.SendMessage(ctx, ciphertext, req.PeerPubkey); err != nil {
		transfer.mu.Lock()
		transfer.Status = TransferFailed
		transfer.Error = err.Error()
		transfer.mu.Unlock()
		return nil, err
	}

	transfer.mu.Lock()
	transfer.Status = TransferComplete
	transfer.Progress = 100
	transfer.mu.Unlock()

	if d.transferStore != nil {
		chunkEstimate := int32(len(req.MediaData)/(256*1024)) + 1
		d.transferStore.Update(msgID, media.TransferComplete, 100, chunkEstimate)
	}

	return &pb.SendMediaResponse{
		MessageId:       msgID,
		EstimatedSeconds: estimatedSec,
		Transport:       transport,
	}, nil
}

// GetMediaStatus returns the status of a media transfer.
func (d *Daemon) GetMediaStatus(ctx context.Context, req *pb.GetMediaStatusRequest) (*pb.MediaStatusResponse, error) {
	d.transferMu.Lock()
	t, ok := d.transfers[req.MessageId]
	d.transferMu.Unlock()

	if !ok {
		return nil, status.Error(codes.NotFound, "transfer not found")
	}

	t.mu.Lock()
	status := t.Status
	progress := t.Progress
	errStr := t.Error
	t.mu.Unlock()

	var pbStatus pb.MediaStatusResponse_Status
	switch status {
	case TransferQueued:
		pbStatus = pb.MediaStatusResponse_QUEUED
	case TransferSending:
		pbStatus = pb.MediaStatusResponse_SENDING
	case TransferComplete:
		pbStatus = pb.MediaStatusResponse_COMPLETE
	case TransferFailed:
		pbStatus = pb.MediaStatusResponse_FAILED
	case TransferCancelled:
		pbStatus = pb.MediaStatusResponse_FAILED
	default:
		pbStatus = pb.MediaStatusResponse_QUEUED
	}

	return &pb.MediaStatusResponse{
		MessageId:   req.MessageId,
		Status:      pbStatus,
		ProgressPct: progress,
		Error:       errStr,
	}, nil
}

// CancelSend cancels a pending send.
func (d *Daemon) CancelSend(ctx context.Context, req *pb.CancelSendRequest) (*pb.Empty, error) {
	d.transferMu.Lock()
	t, ok := d.transfers[req.MessageId]
	d.transferMu.Unlock()

	if !ok {
		return nil, status.Error(codes.NotFound, "transfer not found")
	}

	t.mu.Lock()
	defer t.mu.Unlock()

	if t.Status == TransferComplete || t.Status == TransferFailed {
		return nil, status.Error(codes.FailedPrecondition, "transfer already finished")
	}

	t.Status = TransferCancelled
	return &pb.Empty{}, nil
}

// SendMediaStream handles client-streaming upload of media data.
// First chunk data should be JSON with peer_pubkey, file_name, mime_type.
// Subsequent chunks are raw binary file data.
func (d *Daemon) SendMediaStream(stream pb.RelayClient_SendMediaStreamServer) error {
	var transferID string
	var tempFile *os.File
	var totalSize int64
	var peerPubkey string
	var fileName string
	var mimeType string
	chunkCount := int32(0)

	for {
		chunk, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			if transferID != "" {
				d.transferMu.Lock()
				if t, ok := d.transfers[transferID]; ok {
					t.mu.Lock()
					t.Status = TransferFailed
					t.Error = err.Error()
					t.mu.Unlock()
				}
				d.transferMu.Unlock()
				if d.transferStore != nil {
					d.transferStore.Update(transferID, media.TransferFailed, 0, chunkCount)
				}
			}
			return err
		}

		if transferID == "" {
			transferID = chunk.TransferId
			// Parse JSON metadata from first chunk data
			var header struct {
				PeerPubkey string `json:"peer_pubkey"`
				FileName   string `json:"file_name"`
				MimeType   string `json:"mime_type"`
			}
			if err := json.Unmarshal(chunk.Data, &header); err == nil {
				peerPubkey = header.PeerPubkey
				fileName = header.FileName
				mimeType = header.MimeType
			}

			tempFile, err = os.CreateTemp("", "media-upload-*")
			if err != nil {
				return status.Error(codes.Internal, "create temp file failed")
			}

			// Create transfer tracking
			transfer := &MediaTransfer{
				Status:   TransferQueued,
				Progress: 0,
				Created:  time.Now(),
			}
			d.transferMu.Lock()
			d.transfers[transferID] = transfer
			d.transferMu.Unlock()

			if d.transferStore != nil {
				d.transferStore.Create(&media.TransferEntry{
					ID:         transferID,
					PeerPubkey: peerPubkey,
					FileName:   fileName,
					MimeType:   mimeType,
					Status:     media.TransferQueued,
					CreatedAt:  time.Now().UnixMilli(),
				})
			}

			// If metadata was detected in first chunk, skip writing to temp file
			if peerPubkey == "" {
				// No JSON metadata header — treat data as file content
				n, _ := tempFile.Write(chunk.Data)
				totalSize += int64(n)
			}
			chunkCount++
			continue
		}

		// Write data to temp file
		n, _ := tempFile.Write(chunk.Data)
		totalSize += int64(n)
		chunkCount++

		// Enforce size limit
		if totalSize > media.MediaMaxHardCap {
			tempFile.Close()
			os.Remove(tempFile.Name())
			return status.Errorf(codes.InvalidArgument, "file too large (max %d bytes)", media.MediaMaxHardCap)
		}

		// Update progress estimate
		d.transferMu.Lock()
		if t, ok := d.transfers[transferID]; ok {
			t.mu.Lock()
			t.Status = TransferSending
			t.Progress = int32(chunkCount * 100 / 1000)
			t.ChunksSent = chunkCount
			t.mu.Unlock()
		}
		d.transferMu.Unlock()
	}

	if tempFile == nil {
		return status.Error(codes.InvalidArgument, "no data received")
	}
	tempFile.Close()
	defer os.Remove(tempFile.Name())

	// Read assembled file from temp
	fileData, err := os.ReadFile(tempFile.Name())
	if err != nil {
		return status.Error(codes.Internal, "read temp file failed")
	}

	// Choose transport: TCP-only (media always via HTTP relay)
	transport := "tcp"
	var meta *media.MediaMessage
	var mid [8]byte
	rand.Read(mid[:])

	if peerPubkey == "" {
		slog.Warn("SendMediaStream: no peer pubkey, file assembled but metadata not sent", "transferID", transferID)
		if d.transferStore != nil {
			d.transferStore.Update(transferID, media.TransferComplete, 100, chunkCount)
		}
		estimatedSec := media.EstimateSeconds(totalSize, true)
		return stream.SendAndClose(&pb.SendMediaResponse{
			MessageId:       transferID,
			EstimatedSeconds: estimatedSec,
			Transport:       transport,
		})
	}

	// TCP path — requires relay HTTP media server
	relays := d.engine.GetRelays()
	if len(relays) == 0 {
		d.transferMu.Lock()
		if t, ok := d.transfers[transferID]; ok {
			t.mu.Lock()
			t.Status = TransferFailed
			t.Error = "no relays configured for TCP upload"
			t.mu.Unlock()
		}
		d.transferMu.Unlock()
		if d.transferStore != nil {
			d.transferStore.Update(transferID, media.TransferFailed, 0, chunkCount)
		}
		return status.Error(codes.FailedPrecondition, "no relays configured for TCP upload")
	}
	tcpTransport := media.NewTCPTransport(relays[0], d.authToken)
	meta, err = tcpTransport.SendChunks(stream.Context(), mid, fileData, fileName, mimeType, media.MediaTypeFile)
	if err != nil {
		d.transferMu.Lock()
		if t, ok := d.transfers[transferID]; ok {
			t.mu.Lock()
			t.Status = TransferFailed
			t.Error = err.Error()
			t.mu.Unlock()
		}
		d.transferMu.Unlock()
		if d.transferStore != nil {
			d.transferStore.Update(transferID, media.TransferFailed, 0, chunkCount)
		}
		return err
	}

	// Update status to confirming
	if d.transferStore != nil {
		d.transferStore.Update(transferID, media.TransferConfirming, 90, chunkCount)
	}

	// Send metadata as encrypted message addressed to peer
	meta.Timestamp = time.Now().UnixMilli()
	meta.MessageID = transferID
	metaBytes, err := meta.Marshal()
	if err != nil {
		d.transferMu.Lock()
		if t, ok := d.transfers[transferID]; ok {
			t.mu.Lock()
			t.Status = TransferFailed
			t.Error = err.Error()
			t.mu.Unlock()
		}
		d.transferMu.Unlock()
		if d.transferStore != nil {
			d.transferStore.Update(transferID, media.TransferFailed, 0, chunkCount)
		}
		return err
	}

	peerPubkeyBytes, err := base64.StdEncoding.DecodeString(peerPubkey)
	if err != nil {
		d.transferMu.Lock()
		if t, ok := d.transfers[transferID]; ok {
			t.mu.Lock()
			t.Status = TransferFailed
			t.Error = err.Error()
			t.mu.Unlock()
		}
		d.transferMu.Unlock()
		if d.transferStore != nil {
			d.transferStore.Update(transferID, media.TransferFailed, 0, chunkCount)
		}
		return status.Error(codes.InvalidArgument, "invalid peer pubkey")
	}
	sharedSecret, err := crypto.SharedSecret(d.identity.PrivateKey, peerPubkeyBytes)
	if err != nil {
		d.transferMu.Lock()
		if t, ok := d.transfers[transferID]; ok {
			t.mu.Lock()
			t.Status = TransferFailed
			t.Error = err.Error()
			t.mu.Unlock()
		}
		d.transferMu.Unlock()
		if d.transferStore != nil {
			d.transferStore.Update(transferID, media.TransferFailed, 0, chunkCount)
		}
		return err
	}
	ciphertext, _, err := crypto.EncryptMessage(sharedSecret, metaBytes)
	if err != nil {
		d.transferMu.Lock()
		if t, ok := d.transfers[transferID]; ok {
			t.mu.Lock()
			t.Status = TransferFailed
			t.Error = err.Error()
			t.mu.Unlock()
		}
		d.transferMu.Unlock()
		if d.transferStore != nil {
			d.transferStore.Update(transferID, media.TransferFailed, 0, chunkCount)
		}
		return err
	}
	d.engine.SendMessage(stream.Context(), ciphertext, peerPubkey)

	// Mark complete
	d.transferMu.Lock()
	if t, ok := d.transfers[transferID]; ok {
		t.mu.Lock()
		t.Status = TransferComplete
		t.Progress = 100
		t.mu.Unlock()
	}
	d.transferMu.Unlock()
	if d.transferStore != nil {
		d.transferStore.Update(transferID, media.TransferComplete, 100, chunkCount)
	}

	estimatedSec := media.EstimateSeconds(totalSize, transport == "tcp")
	return stream.SendAndClose(&pb.SendMediaResponse{
		MessageId:       transferID,
		EstimatedSeconds: estimatedSec,
		Transport:       transport,
	})
}

// cleanupTransfers periodically removes old completed transfers from the map.
func (d *Daemon) cleanupTransfers() {
	for {
		time.Sleep(5 * time.Minute)
		now := time.Now()
		d.transferMu.Lock()
		for id, t := range d.transfers {
			t.mu.Lock()
			// Remove transfers older than 1 hour that are in a terminal state
			if (t.Status == TransferComplete || t.Status == TransferFailed || t.Status == TransferCancelled) &&
				now.Sub(t.Created) > 1*time.Hour {
				delete(d.transfers, id)
			}
			t.mu.Unlock()
		}
		d.transferMu.Unlock()
	}
}

const maxQueueRetries = 20 // give up after ~10 minutes (20 × 30s)

// SetTransportMode sets the DNS transport mode via gRPC (replaces file-watcher).
func (d *Daemon) SetTransportMode(ctx context.Context, req *pb.SetTransportModeRequest) (*pb.Empty, error) {
	mode := dns.TransportAuto
	switch req.Mode {
	case pb.SetTransportModeRequest_TCP:
		mode = dns.TransportTCP
	case pb.SetTransportModeRequest_UDP:
		mode = dns.TransportUDP
	default:
		mode = dns.TransportAuto
	}
	d.engine.SetTransportMode(mode)
	slog.Info("transport mode set via gRPC", "mode", mode.String())
	return &pb.Empty{}, nil
}

// SetChunkSize sets the DNS chunk size via gRPC (replaces file-watcher).
func (d *Daemon) SetChunkSize(ctx context.Context, req *pb.SetChunkSizeRequest) (*pb.Empty, error) {
	d.engine.SetChunkSize(int(req.Size))
	slog.Info("chunk size set via gRPC", "size", req.Size)
	return &pb.Empty{}, nil
}

// watchTransportMode reads dataDir/transport_mode every 5 seconds.
// Flutter writes this file when the user changes the DNS transport mode
// (Auto / TCP / UDP). The mode is applied to the engine immediately.
// DEPRECATED: replaced by SetTransportMode gRPC. Kept for backward compat.
func (d *Daemon) watchTransportMode() {
	path := filepath.Join(d.dataDir, "transport_mode")
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	var last string
	for range ticker.C {
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		mode := strings.TrimSpace(string(data))
		if mode == last {
			continue
		}
		last = mode
		m := dns.TransportModeFromString(mode)
		d.engine.SetTransportMode(m)
		slog.Info("transport mode updated from file", "mode", m.String())
	}
}

// watchChunkSize reads dataDir/chunk_size every 5 seconds.
// Flutter writes this file when the user changes the DNS chunk size.
// Minimum 32, maximum 200.
func (d *Daemon) watchChunkSize() {
	path := filepath.Join(d.dataDir, "chunk_size")
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	var last int
	for range ticker.C {
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		size, err := strconv.Atoi(strings.TrimSpace(string(data)))
		if err != nil || size < 32 || size > 200 {
			continue
		}
		if size == last {
			continue
		}
		last = size
		d.engine.SetChunkSize(size)
		slog.Info("chunk size updated from file", "size", size)
	}
}

// processQueue periodically retries sending queued messages.
func (d *Daemon) processQueue() {
	for {
		time.Sleep(30 * time.Second)
		pending, err := d.queue.Pending()
		if err != nil {
			slog.Error("queue read failed", "error", err)
			continue
		}
		for _, msg := range pending {
			if msg.Retries >= maxQueueRetries {
				slog.Warn("queue giving up on message", "id", msg.ID, "retries", msg.Retries)
				d.queue.Remove(msg.ID)
				continue
			}
			// Message already encrypted when queued — send ciphertext directly
			_, _, err = d.engine.SendMessage(context.Background(), msg.Ciphertext, msg.PeerKey)
			if err != nil {
				slog.Error("queue send failed", "id", msg.ID, "retries", msg.Retries, "error", err)
				d.queue.MarkFailed(msg.ID, err.Error())
				continue
			}
			slog.Info("queue message sent", "id", msg.ID, "retries", msg.Retries)
			d.queue.Remove(msg.ID)
		}
	}
}
