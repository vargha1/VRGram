package client

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
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
)

// Daemon implements the RelayClient gRPC service.
type Daemon struct {
	pb.UnimplementedRelayClientServer

	engine      *DNSClientEngine
	detector    *Detector
	queue       *OfflineQueue
	identity    *crypto.KeyPair
	peers       map[string]string // nickname -> pubkey
	peersMu     sync.RWMutex
	peersPath   string // path to peers.json
	dataDir     string
	grpcServer  *grpc.Server

	// Media transfer tracking
	transfers  map[string]*MediaTransfer // messageID -> transfer
	transferMu sync.Mutex

	// Auth token for gRPC
	authToken     []byte
	authTokenPath string

	debugLog *os.File // DNS debug log, written to dataDir/relayd_debug.log
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
		peers:         make(map[string]string),
		peersPath:     filepath.Join(dataDir, "daemon_peers.json"),
		dataDir:       dataDir,
		transfers:     make(map[string]*MediaTransfer),
		authToken:     authToken,
		authTokenPath: authTokenPath,
	}
	// Open debug log (append, create if missing)
	dl, err := os.OpenFile(filepath.Join(dataDir, "relayd_debug.log"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err == nil {
		daemon.debugLog = dl
	}
	daemon.loadPeers()
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
func loadOrGenerateAuthToken(path string) ([]byte, error) {
	data, err := os.ReadFile(path)
	if err == nil && len(data) == authTokenLen {
		return data, nil
	}
	token := make([]byte, authTokenLen)
	if _, err := rand.Read(token); err != nil {
		return nil, fmt.Errorf("generate auth token: %w", err)
	}
	if err := os.WriteFile(path, token, 0600); err != nil {
		return nil, fmt.Errorf("save auth token: %w", err)
	}
	return token, nil
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
	if len(tokens[0]) != authTokenLen {
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
	polled, err := d.engine.PollMessages(myPubkey)
	if err != nil {
		slog.Warn("poll messages failed", "error", err)
		return &pb.PollResponse{}, nil
	}

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
		peersSnapshot := make(map[string]string, len(d.peers))
		for k, v := range d.peers {
			peersSnapshot[k] = v
		}
		d.peersMu.RUnlock()
		d.debugWrite("PollMessages: decrypt trying %d peers msgID=%x", len(peersSnapshot), pm.MsgID)
		for nickname, pubkeyStr := range peersSnapshot {
			pubkey, err := base64.StdEncoding.DecodeString(pubkeyStr)
			if err != nil {
				d.debugWrite("PollMessages: bad pubkey for peer %s", nickname)
				continue
			}
			ss, err := crypto.SharedSecret(d.identity.PrivateKey, pubkey)
			if err != nil {
				d.debugWrite("PollMessages: shared secret failed for peer %s", nickname)
				continue
			}
			plaintext, err := crypto.DecryptMessage(ss, nonce, ciphertext)
			if err != nil {
				d.debugWrite("PollMessages: decrypt failed for peer %s err=%v", nickname, err)
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
		if decrypted == nil {
			d.debugWrite("PollMessages: could not decrypt msgID=%x from any known peer", pm.MsgID)
			continue
		}

		msgID := hex.EncodeToString(pm.MsgID[:])
		resp.Messages = append(resp.Messages, &pb.ReceivedMessage{
			MessageId: msgID,
			Plaintext: decrypted,
			FromPeer:  fromPeer,
		})
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

// GetIdentity returns the daemon's public key.
func (d *Daemon) GetIdentity(ctx context.Context, req *pb.Empty) (*pb.IdentityInfo, error) {
	return &pb.IdentityInfo{
		Pubkey: base64.StdEncoding.EncodeToString(d.identity.PublicKey),
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
	d.peers[req.Nickname] = req.Pubkey
	d.peersMu.Unlock()
	d.savePeers()
	return &pb.Empty{}, nil
}

// loadPeers reads peers from JSON file into memory.
func (d *Daemon) loadPeers() {
	data, err := os.ReadFile(d.peersPath)
	if err != nil {
		if !os.IsNotExist(err) {
			slog.Warn("failed to read peers file", "path", d.peersPath, "error", err)
		}
		return
	}
	var loaded map[string]string
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

// SendMedia sends media data (file, image, etc.) to a peer over DNS transport.
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

	if len(req.MediaData) >= media.MediaDNSSizeThreshold {
		transfer.mu.Lock()
		transfer.Status = TransferFailed
		transfer.Error = fmt.Sprintf("file too large for DNS transport (max %d bytes)", media.MediaDNSSizeThreshold)
		transfer.mu.Unlock()
		return nil, status.Errorf(codes.FailedPrecondition, "file too large for DNS transport (max %d bytes)", media.MediaDNSSizeThreshold)
	}

	// DNS path
	var mid [8]byte
	rand.Read(mid[:])

	dnsTransport := media.NewDNSTransport(&media.SendMessageAdapter{Engine: d.engine})

	meta, err := dnsTransport.SendChunks(ctx, mid, req.MediaData, req.Filename, req.MimeType, media.MediaTypeFile)
	if err != nil {
		transfer.mu.Lock()
		transfer.Status = TransferFailed
		transfer.Error = err.Error()
		transfer.mu.Unlock()
		return nil, err
	}

	meta.Timestamp = time.Now().UnixMilli()
	meta.MessageID = msgID

	estimatedSec = int32(len(req.MediaData) / (15 * 200) * 100 / 1000) // DNS parallel estimate

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
	transfer.Status = TransferSending
	transfer.Progress = 50
	transfer.mu.Unlock()

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
