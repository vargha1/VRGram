package client

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log/slog"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"sync"
	"time"

	"github.com/user/dns-transport/internal/media"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	pb "github.com/user/dns-transport/pkg/relaypb"

	"github.com/user/dns-transport/internal/bridge"
	"github.com/user/dns-transport/internal/crypto"
)

// Daemon implements the RelayClient gRPC service.
type Daemon struct {
	pb.UnimplementedRelayClientServer

	engine         *DNSClientEngine
	detector       *Detector
	queue          *OfflineQueue
	identity       *crypto.KeyPair
	peers          map[string]string // nickname -> pubkey
	dataDir        string
	dhtOnly        bool
	grpcServer     *grpc.Server
	bridgeCli      *bridge.Client
	libp2pTransport Libp2pTransport // optional libp2p transport for media

	// Media transfer tracking
	transfers   map[string]*MediaTransfer // messageID -> transfer
	transferMu  sync.Mutex
}

// Libp2pTransport is the interface for sending files over libp2p.
type Libp2pTransport interface {
	SendFile(ctx context.Context, peerID string, fileName string, mimeType string, data []byte) error
}

// TransferStatus represents the state of a media transfer.
type TransferStatus int32

const (
	TransferQueued     TransferStatus = 0
	TransferSending    TransferStatus = 1
	TransferComplete   TransferStatus = 2
	TransferFailed     TransferStatus = 3
	TransferCancelled  TransferStatus = 4
)

// MediaTransfer tracks the progress and state of a media transfer.
type MediaTransfer struct {
	mu       sync.Mutex
	Status   TransferStatus
	Progress int32 // 0-100
	Error    string
	Created  time.Time
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
func RunDaemon(grpcPort int, relays []string, zone string, dataDir string, forceBlackout bool, bridgeSocket string, dhtOnly bool) error {
	// Ensure data directory
	if err := os.MkdirAll(dataDir, 0700); err != nil {
		return err
	}

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

	// Open offline queue
	queue, err := NewOfflineQueue(filepath.Join(dataDir, "queue.db"))
	if err != nil {
		return err
	}

	// Connect to bridge (optional)
	var cli *bridge.Client
	if bridgeSocket != "" {
		cli, err = bridge.NewClient(bridgeSocket)
		if err != nil {
			slog.Warn("bridge client not available", "error", err)
		}
	}

	// Determine relays based on bridge availability and dhtOnly
	var engineRelays []string
	if cli != nil {
		// Bridge available — skip static relays, DHT discovery provides them
		slog.Info("bridge connected, using DHT-discovered relays")
		engineRelays = nil
	} else if dhtOnly {
		// DHT-only mode with no bridge — no relays available
		slog.Warn("DHT-only mode but bridge not connected, no relays configured")
		engineRelays = nil
	} else {
		// No bridge, not DHT-only — try config file, then command-line relays
		engineRelays = loadRelaysFromConfig(dataDir)
		if len(engineRelays) == 0 {
			engineRelays = relays
		}
		if len(engineRelays) == 0 {
			slog.Warn("no relay endpoints configured")
		}
	}

	// Create DNS engine with bridge client (optional)
	engine := NewDNSClientEngine(cli, engineRelays, zone)

	// Create network detector
	detector := NewDetector(forceBlackout, cli)
	detector.Check() // initial check
	slog.Info("network mode", "blackout", detector.CurrentMode() == ModeBlackout)

	// Create daemon
	daemon := &Daemon{
		engine:    engine,
		detector:  detector,
		queue:     queue,
		identity:  identity,
		peers:     make(map[string]string),
		dataDir:   dataDir,
		dhtOnly:   dhtOnly,
		bridgeCli: cli,
		transfers: make(map[string]*MediaTransfer),
	}

	// Start gRPC server
	lis, err := net.Listen("tcp", net.JoinHostPort("127.0.0.1", strconv.Itoa(grpcPort)))
	if err != nil {
		return err
	}

	s := grpc.NewServer(
		grpc.MaxRecvMsgSize(100 * 1024 * 1024), // 100 MB max receive
		grpc.MaxSendMsgSize(100 * 1024 * 1024), // 100 MB max send
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

	slog.Info("client daemon listening", "grpc", grpcPort, "pubkey", base64.StdEncoding.EncodeToString(identity.PublicKey))
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

// SendMessage encrypts and sends a message via DNS engine, falling back to offline queue.
func (d *Daemon) SendMessage(ctx context.Context, req *pb.SendRequest) (*pb.SendResponse, error) {
	if d.identity == nil {
		return nil, status.Error(codes.FailedPrecondition, "identity not initialized")
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
	ciphertext, _, err := crypto.EncryptMessage(sharedSecret, req.Plaintext)
	if err != nil {
		return nil, err
	}

		// Try send via DNS engine
		msgID, chunkCount, err := d.engine.SendMessage(ctx, ciphertext)
	if err != nil {
		// Queue ciphertext offline (already encrypted)
		slog.Warn("send failed, queueing offline", "error", err)
		_, qErr := d.queue.Enqueue(req.PeerPubkey, ciphertext)
		if qErr != nil {
			return nil, qErr
		}
		return &pb.SendResponse{
			MessageId:  base64.StdEncoding.EncodeToString(msgID[:]),
			Queued:     true,
			ChunkCount: 0,
		}, nil
	}

	return &pb.SendResponse{
		MessageId:  base64.StdEncoding.EncodeToString(msgID[:]),
		Queued:     false,
		ChunkCount: int32(chunkCount),
	}, nil
}

// PollMessages returns pending messages (PoC: returns empty).
func (d *Daemon) PollMessages(ctx context.Context, req *pb.PollRequest) (*pb.PollResponse, error) {
	// PoC: server-mode only, returns empty
	return &pb.PollResponse{}, nil
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

// GetIdentity returns the daemon's public key.
func (d *Daemon) GetIdentity(ctx context.Context, req *pb.Empty) (*pb.IdentityInfo, error) {
	return &pb.IdentityInfo{
		Pubkey: base64.StdEncoding.EncodeToString(d.identity.PublicKey),
	}, nil
}

// AddPeer stores a peer mapping in memory (PoC: not persisted).
func (d *Daemon) AddPeer(ctx context.Context, req *pb.PeerInfo) (*pb.Empty, error) {
	d.peers[req.Nickname] = req.Pubkey
	return &pb.Empty{}, nil
}

// DiscoverRelays returns the relay list from bridge.
func (d *Daemon) DiscoverRelays(ctx context.Context) ([]bridge.RelayInfo, error) {
	if d.bridgeCli == nil {
		return nil, fmt.Errorf("bridge not connected")
	}
	ch, err := d.bridgeCli.DiscoverRelays(ctx, 20, false)
	if err != nil {
		return nil, err
	}
	upd, ok := <-ch
	if !ok {
		return nil, fmt.Errorf("no relay updates")
	}
	return upd.Added, nil
}

// GetTransportStatus returns the current transport layer status.
func (d *Daemon) GetTransportStatus(ctx context.Context, req *pb.Empty) (*pb.TransportStatusResponse, error) {
	status := &pb.TransportStatusResponse{
		DhtConnected:     false,
		DiscoveredRelays: 0,
		Libp2PDirect:     false,
		Libp2PCircuit:    false,
		DnsMode:          "unknown",
	}

	if d.bridgeCli != nil {
		ts, err := d.bridgeCli.GetTransportStatus(ctx)
		if err == nil {
			status.DhtConnected = ts.DHTConnected
			status.DiscoveredRelays = ts.DiscoveredRelays
			status.Libp2PDirect = ts.Libp2pDirect
			status.Libp2PCircuit = ts.Libp2pCircuit
			if ts.DNSMode != "" {
				status.DnsMode = ts.DNSMode
			}
		}
	}

	// If bridge is unavailable or returns empty, use local detector for DNS mode
	if status.DnsMode == "unknown" {
		mode := d.detector.CurrentMode()
		if mode == ModeBlackout {
			status.DnsMode = "blackout"
		} else {
			status.DnsMode = "normal"
		}
	}

	return status, nil
}

// SendMedia sends media data (file, image, etc.) to a peer.
// Chooses transport based on size and availability: DNS for small files, libp2p for larger.
func (d *Daemon) SendMedia(ctx context.Context, req *pb.SendMediaRequest) (*pb.SendMediaResponse, error) {
	transport := "dns"
	estimatedSec := int32(len(req.MediaData) / 1000) // rough estimate
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

	if req.PreferredTransport == pb.SendMediaRequest_DNS ||
		(req.PreferredTransport == pb.SendMediaRequest_AUTO && len(req.MediaData) < media.MediaDNSSizeThreshold) {
		// DNS path
		var mid [8]byte
		rand.Read(mid[:])

		dnsTransport := media.NewDNSTransport(d.engine)

		// I5: MediaLibp2pHardCap enforced inside SendChunks
		meta, err := dnsTransport.SendChunks(ctx, mid, req.MediaData, req.Filename, req.MimeType, media.MediaTypeFile)
		if err != nil {
			transfer.mu.Lock()
			transfer.Status = TransferFailed
			transfer.Error = err.Error()
			transfer.mu.Unlock()
			return nil, err
		}

		// I3: Set timestamp
		meta.Timestamp = time.Now().UnixMilli()
		meta.MessageID = msgID

		estimatedSec = int32(len(req.MediaData) / (15 * 200) * 100 / 1000) // DNS parallel estimate

		// I2: Send metadata as E2E-encrypted message addressed to peer
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
		if _, _, err := d.engine.SendMessage(ctx, ciphertext); err != nil {
			transfer.mu.Lock()
			transfer.Status = TransferFailed
			transfer.Error = err.Error()
			transfer.mu.Unlock()
			return nil, err
		}

		transfer.mu.Lock()
		transfer.Status = TransferSending
		transfer.Progress = 50
		transfer.mu.Unlock()

	} else if req.PreferredTransport == pb.SendMediaRequest_LIBP2P ||
		(len(req.MediaData) >= media.MediaDNSSizeThreshold && d.libp2pTransport != nil) {

		// C3: libp2p peer ID is X25519 pubkey — wrong.
		// For PoC, skip if we cannot resolve a proper peer ID.
		// TODO: Implement proper pubkey -> libp2p PeerID mapping.
		// Currently req.PeerPubkey is the X25519 public key, not the libp2p PeerID.
		peerID := "" // would need a mapping from pubkey -> peerID
		if peerID == "" {
			// No mapping available; this is a PoC limitation.
			// The real fix requires identifying libp2p peers by their PeerID,
			// which needs a mapping from X25519 pubkey to libp2p PeerID.
			transfer.mu.Lock()
			transfer.Status = TransferFailed
			transfer.Error = "libp2p peer ID mapping not available (PoC limitation)"
			transfer.mu.Unlock()
			return nil, status.Error(codes.Unimplemented, "libp2p peer ID mapping not available (PoC)")
		}

		transport = "libp2p"

		// C1: Encrypt file before sending over libp2p
		fileKey, err := media.GenerateFileKey()
		if err != nil {
			transfer.mu.Lock()
			transfer.Status = TransferFailed
			transfer.Error = err.Error()
			transfer.mu.Unlock()
			return nil, err
		}
		encryptedData, err := media.EncryptFile(fileKey, req.MediaData)
		if err != nil {
			transfer.mu.Lock()
			transfer.Status = TransferFailed
			transfer.Error = err.Error()
			transfer.mu.Unlock()
			return nil, err
		}

		// Build metadata with file key so peer can decrypt
		meta := &media.MediaMessage{
			MessageID:   msgID,
			Timestamp:   time.Now().UnixMilli(),
			MediaType:   media.MediaTypeFile,
			FileName:    req.Filename,
			MimeType:    req.MimeType,
			FileSize:    int64(len(req.MediaData)),
			Chunks:      0, // 0 = sent via libp2p
			FileKeyB64:  base64.StdEncoding.EncodeToString(fileKey),
		}

		// I2: Send metadata as E2E-encrypted message addressed to peer
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
		if _, _, err := d.engine.SendMessage(ctx, ciphertext); err != nil {
			transfer.mu.Lock()
			transfer.Status = TransferFailed
			transfer.Error = err.Error()
			transfer.mu.Unlock()
			return nil, err
		}

		// Send encrypted file via libp2p
		if err := d.libp2pTransport.SendFile(ctx, peerID, req.Filename, req.MimeType, encryptedData); err != nil {
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

		estimatedSec = int32(len(req.MediaData) / (1024 * 1024)) // ~1 MB/s est

	} else if req.PreferredTransport == pb.SendMediaRequest_AUTO &&
		len(req.MediaData) >= media.MediaDNSSizeThreshold &&
		d.libp2pTransport == nil {
		// I4: AUTO transport but file too large for DNS and libp2p unavailable
		transfer.mu.Lock()
		transfer.Status = TransferFailed
		transfer.Error = "file too large for DNS, libp2p unavailable"
		transfer.mu.Unlock()
		return nil, status.Error(codes.FailedPrecondition, "file too large for DNS, libp2p unavailable")
	}

	transfer.mu.Lock()
	transfer.Status = TransferComplete
	transfer.Progress = 100
	transfer.mu.Unlock()

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
			if msg.Retries >= 5 {
				slog.Warn("permanent failure, removing message", "id", msg.ID, "retries", msg.Retries)
				d.queue.Remove(msg.ID)
				continue
			}
			// Message already encrypted when queued — send ciphertext directly
			_, _, err = d.engine.SendMessage(context.Background(), msg.Ciphertext)
			if err != nil {
				slog.Error("queue send failed", "id", msg.ID, "error", err)
				d.queue.MarkFailed(msg.ID, err.Error())
				continue
			}
			slog.Info("queue message sent", "id", msg.ID)
			d.queue.Remove(msg.ID)
		}
	}
}
