package client

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log/slog"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"time"

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

	engine     *DNSClientEngine
	detector   *Detector
	queue      *OfflineQueue
	identity   *crypto.KeyPair
	peers      map[string]string // nickname -> pubkey
	dataDir    string
	dhtOnly    bool
	grpcServer *grpc.Server
	bridgeCli  *bridge.Client
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
	}

	// Start gRPC server
	lis, err := net.Listen("tcp", net.JoinHostPort("127.0.0.1", strconv.Itoa(grpcPort)))
	if err != nil {
		return err
	}

	s := grpc.NewServer()
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
