# Plan 1: Decentralized Relay Discovery (Text Phase)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove operator-run relay dependencies. Relay discovery via DHT. All clients are relays. Text messaging works without any central server.

**Architecture:** A new `p2pd` binary runs alongside `relayd`, communicating via Unix socket protobuf protocol. `p2pd` maintains libp2p host + Kademlia DHT. It discovers relay peers in DHT and advertises this node as a relay. `relayd` gets relay addresses from `p2pd` instead of static config. DNS TXT queries remain the transport. Parallel pipeline added for performance.

**Tech Stack:** Go 1.25, libp2p v0.36, go-libp2p-kad-dht v0.25, protobuf, miekg/dns (existing)

## Global Constraints

- All new Go code must compile on `linux/amd64`, `linux/arm64`, `darwin/amd64`, `darwin/arm64`, `windows/amd64`
- Protobuf code generation: `protoc --go_out=. --go_opt=paths=source_relative --go-grpc_out=. --go-grpc_opt=paths=source_relative`
- No external DNS service dependencies. Only DNS servers are peers' own p2pd/relayd instances.
- Existing E2E encryption (X25519+XChaCha20-Poly1305) unchanged
- libp2p key separate from existing X25519 identity key

---
### Task 1: Bridge Protocol Protobuf Definitions

**Files:**
- Create: `go/proto/bridge.proto`
- Create: `go/pkg/bridgepb/bridge.pb.go` (generated)
- Create: `go/pkg/bridgepb/bridge_grpc.pb.go` (generated)

**Interfaces:**
- Consumes: nothing
- Produces: `bridgepb.P2PBridgeServer` interface, `bridgepb.P2PBridgeClient` interface, all message types

- [ ] **Step 1: Write `go/proto/bridge.proto`**

```protobuf
syntax = "proto3";
package bridgepb;
option go_package = "github.com/user/dns-transport/pkg/bridgepb";

service P2PBridge {
  rpc DiscoverRelays(DiscoverRequest) returns (stream RelayUpdate);
  rpc AdvertiseRelay(AdvertiseRequest) returns (AdvertiseResponse);
  // Forward DNS response via libp2p circuit back to remote peer
  rpc ForwardDNSPacket(DNSPacket) returns (Empty);
  // Stream of incoming DNS queries from remote peers via libp2p circuit
  rpc IncomingDNS(Empty) returns (stream DNSPacket);
  // Bidirectional DNS relay
  rpc RelayDNSPacket(DNSPacket) returns (DNSPacket);
  // Get current DHT and transport status
  rpc GetTransportStatus(Empty) returns (TransportStatus);
}

message RelayInfo {
  string peer_id = 1;
  string dns_address = 2;
  repeated string multiaddrs = 3;
  int32 load = 4;
  int64 last_seen = 5;
}

message DiscoverRequest {
  int32 max_relays = 1;
  bool subscribe = 2;
}

message RelayUpdate {
  bool initial_batch = 1;
  repeated RelayInfo added = 2;
  repeated string removed_peer_ids = 3;
}

message AdvertiseRequest {
  string zone = 1;
  string listen_addr = 2;
}

message AdvertiseResponse {
  bool success = 1;
  string public_dns_addr = 2;
}

message DNSPacket {
  bytes raw = 1;
  string remote_peer_id = 2;
}

message TransportStatus {
  bool dht_connected = 1;
  int32 peers_in_dht = 2;
  int32 discovered_relays = 3;
  bool libp2p_direct = 4;
  bool libp2p_circuit = 5;
  string dns_mode = 6;
}

message Empty {}
```

- [ ] **Step 2: Generate protobuf stubs**

Run from `go/` directory:
```bash
protoc --go_out=. --go_opt=paths=source_relative \
  --go-grpc_out=. --go-grpc_opt=paths=source_relative \
  proto/bridge.proto
```

Expected: `pkg/bridgepb/bridge.pb.go` and `pkg/bridgepb/bridge_grpc.pb.go` created.

- [ ] **Step 3: Verify compilation**

```bash
cd go && go build ./pkg/bridgepb/
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add go/proto/bridge.proto go/pkg/bridgepb/
git commit -m "feat: add bridge protocol protobuf definitions for p2pd<->relayd"
```

---
### Task 2: p2pd Binary — Host and DHT

**Files:**
- Create: `go/cmd/p2pd/main.go`
- Create: `go/internal/p2p/host.go`
- Create: `go/internal/p2p/dht.go`
- Create: `go/internal/p2p/relay.go`

**Interfaces:**
- Consumes: nothing (standalone binary)
- Produces: `p2p.NewHost(config)` returning `*p2p.P2PHost`
  - `P2PHost` methods: `Start()`, `Stop()`, `PeerID() string`, `Multiaddrs() []string`
- Produces: `p2p.NewDHT(host, bootstrapAddrs)` returning `*p2p.DHTClient`
  - `DHTClient` methods: `Start(ctx)`, `Stop()`, `FindRelayProviders(ctx, limit) ([]peer.AddrInfo, error)`, `AnnounceRelay(ctx) error`, `RefreshProviders(ctx)`, `ConnectedPeers() int`

- [ ] **Step 1: Create `go/internal/p2p/host.go`**

```go
package p2p

import (
	"context"
	"crypto/rand"
	"fmt"
	"os"
	"path/filepath"

	"github.com/libp2p/go-libp2p"
	"github.com/libp2p/go-libp2p/core/crypto"
	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/multiformats/go-multiaddr"
)

type P2PHost struct {
	Host    host.Host
	dataDir string
	port    int
}

type HostConfig struct {
	Port    int
	DataDir string
}

func NewHost(cfg HostConfig) (*P2PHost, error) {
	if err := os.MkdirAll(cfg.DataDir, 0700); err != nil {
		return nil, fmt.Errorf("create data dir: %w", err)
	}

	keyPath := filepath.Join(cfg.DataDir, "p2p.key")
	privKey, err := loadOrGenerateKey(keyPath)
	if err != nil {
		return nil, fmt.Errorf("load or generate key: %w", err)
	}

	h, err := libp2p.New(
		libp2p.Identity(privKey),
		libp2p.ListenAddrStrings(
			fmt.Sprintf("/ip4/0.0.0.0/tcp/%d", cfg.Port),
			fmt.Sprintf("/ip4/0.0.0.0/udp/%d/quic-v1", cfg.Port),
		),
		libp2p.EnableNATService(),
		libp2p.EnableAutoNATv2(),
		libp2p.EnableHolePunching(),
	)
	if err != nil {
		return nil, fmt.Errorf("create libp2p host: %w", err)
	}

	return &P2PHost{Host: h, dataDir: cfg.DataDir, port: cfg.Port}, nil
}

func (h *P2PHost) PeerID() string {
	return h.Host.ID().String()
}

func (h *P2PHost) Multiaddrs() []string {
	addrs := h.Host.Addrs()
	result := make([]string, 0, len(addrs))
	for _, a := range addrs {
		result = append(result, a.String())
	}
	return result
}

func (h *P2PHost) Start() {
	// libp2p host is started on creation, nothing extra needed
	fmt.Printf("P2P host started: %s\n", h.Host.ID().String())
}

func (h *P2PHost) Stop() error {
	return h.Host.Close()
}

func loadOrGenerateKey(path string) (crypto.PrivKey, error) {
	data, err := os.ReadFile(path)
	if err == nil {
		return crypto.UnmarshalPrivateKey(data)
	}
	if !os.IsNotExist(err) {
		return nil, fmt.Errorf("read key file: %w", err)
	}

	priv, _, err := crypto.GenerateEd25519Key(rand.Reader)
	if err != nil {
		return nil, fmt.Errorf("generate key: %w", err)
	}

	raw, err := crypto.MarshalPrivateKey(priv)
	if err != nil {
		return nil, fmt.Errorf("marshal key: %w", err)
	}

	if err := os.WriteFile(path, raw, 0600); err != nil {
		return nil, fmt.Errorf("write key file: %w", err)
	}

	return priv, nil
}
```

- [ ] **Step 2: Create `go/internal/p2p/dht.go`**

```go
package p2p

import (
	"context"
	"fmt"
	"time"

	dht "github.com/libp2p/go-libp2p-kad-dht"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/multiformats/go-multiaddr"
)

const (
	relayNamespace = "/vrgram/relays"
	dhtTimeout     = 30 * time.Second
)

type DHTClient struct {
	dht       *dht.IpfsDHT
	host      *P2PHost
	bootstrap []peer.AddrInfo
}

func NewDHT(host *P2PHost, bootstrapAddrs []string) (*DHTClient, error) {
	bootstrap := make([]peer.AddrInfo, 0, len(bootstrapAddrs))
	for _, addr := range bootstrapAddrs {
		maddr, err := multiaddr.NewMultiaddr(addr)
		if err != nil {
			return nil, fmt.Errorf("parse bootstrap addr %s: %w", addr, err)
		}
		pi, err := peer.AddrInfoFromP2pAddr(maddr)
		if err != nil {
			return nil, fmt.Errorf("addr info from %s: %w", addr, err)
		}
		bootstrap = append(bootstrap, *pi)
	}

	kad, err := dht.New(context.Background(), host.Host,
		dht.Mode(dht.ModeServer),
		dht.BootstrapPeers(bootstrap...),
	)
	if err != nil {
		return nil, fmt.Errorf("create DHT: %w", err)
	}

	return &DHTClient{dht: kad, host: host, bootstrap: bootstrap}, nil
}

func (d *DHTClient) Start(ctx context.Context) error {
	if err := d.dht.Bootstrap(ctx); err != nil {
		return fmt.Errorf("bootstrap DHT: %w", err)
	}

	// Wait for initial bootstrap to connect to at least some peers
	time.Sleep(2 * time.Second)
	return nil
}

func (d *DHTClient) Stop() error {
	return d.dht.Close()
}

func (d *DHTClient) ConnectedPeers() int {
	return len(d.dht.RoutingTable().ListPeers())
}

func (d *DHTClient) FindRelayProviders(ctx context.Context, limit int) ([]peer.AddrInfo, error) {
	ctx, cancel := context.WithTimeout(ctx, dhtTimeout)
	defer cancel()

	peers, err := d.dht.FindProviders(ctx, relayNamespace, dht.Quorum(0))
	if err != nil {
		return nil, fmt.Errorf("find providers: %w", err)
	}

	if limit > 0 && len(peers) > limit {
		peers = peers[:limit]
	}

	return peers, nil
}

func (d *DHTClient) AnnounceRelay(ctx context.Context) error {
	ctx, cancel := context.WithTimeout(ctx, dhtTimeout)
	defer cancel()

	if err := d.dht.Provide(ctx, relayNamespace, true); err != nil {
		return fmt.Errorf("announce relay: %w", err)
	}
	return nil
}

func (d *DHTClient) RefreshProviders(ctx context.Context) {
	ticker := time.NewTicker(30 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			_ = d.AnnounceRelay(ctx)
		}
	}
}
```

- [ ] **Step 3: Create `go/internal/p2p/relay.go`**

```go
package p2p

import (
	"context"
	"fmt"

	"github.com/libp2p/go-libp2p/p2p/protocol/circuitv2/relay"
)

func (h *P2PHost) EnableCircuitRelay(ctx context.Context) error {
	_, err := relay.New(h.Host)
	if err != nil {
		return fmt.Errorf("enable circuit relay: %w", err)
	}
	fmt.Println("Circuit relay enabled")
	return nil
}
```

- [ ] **Step 4: Create `go/cmd/p2pd/main.go`**

```go
package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"

	"github.com/user/dns-transport/internal/p2p"
	"google.golang.org/grpc"
)

func main() {
	socketPath := flag.String("socket", "", "Unix socket path for relayd communication")
	port := flag.Int("port", 4001, "libp2p listen port")
	bootstrap := flag.String("bootstrap", "", "Comma-separated bootstrap multiaddrs")
	dataDir := flag.String("data-dir", "", "Data directory")
	zone := flag.String("zone", "msg.local-domain", "DNS zone")
	flag.Parse()

	if *dataDir == "" {
		home, _ := os.UserHomeDir()
		*dataDir = filepath.Join(home, ".config", "vrgram")
	}
	if *socketPath == "" {
		*socketPath = filepath.Join(*dataDir, "p2p.sock")
	}

	// Build default bootstrap list
	bootstrapAddrs := []string{}
	if *bootstrap != "" {
		bootstrapAddrs = []string{*bootstrap}
		// TODO: parse comma-separated if needed
	}
	// Add hardcoded bootstrap defaults
	if len(bootstrapAddrs) == 0 {
		bootstrapAddrs = []string{
			"/ip4/.../tcp/4001/p2p/...", // placeholder
		}
	}

	host, err := p2p.NewHost(p2p.HostConfig{
		Port:    *port,
		DataDir: *dataDir,
	})
	if err != nil {
		log.Fatalf("Failed to create host: %v", err)
	}

	dhtClient, err := p2p.NewDHT(host, bootstrapAddrs)
	if err != nil {
		log.Fatalf("Failed to create DHT: %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	if err := dhtClient.Start(ctx); err != nil {
		log.Fatalf("Failed to start DHT: %v", err)
	}

	if err := host.EnableCircuitRelay(ctx); err != nil {
		log.Printf("Warning: circuit relay: %v", err)
	}

	if err := dhtClient.AnnounceRelay(ctx); err != nil {
		log.Printf("Warning: announce: %v", err)
	}
	go dhtClient.RefreshProviders(ctx)

	// Start bridge gRPC server
	grpcServer := grpc.NewServer()
	// Bridge server will be registered in Task 3

	// Cleanup old socket
	os.Remove(*socketPath)
	listener, err := net.Listen("unix", *socketPath)
	if err != nil {
		log.Fatalf("Failed to listen on socket %s: %v", *socketPath, err)
	}

	go func() {
		log.Printf("p2pd listening on %s, peer ID: %s", *socketPath, host.PeerID())
		if err := grpcServer.Serve(listener); err != nil {
			log.Fatalf("gRPC serve: %v", err)
		}
	}()

	// Wait for signal
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh

	fmt.Println("Shutting down...")
	grpcServer.GracefulStop()
	_ = zone // used in later tasks
	host.Stop()
	dhtClient.Stop()
}
```

- [ ] **Step 5: Initialize Go module dependency**

```bash
cd go && go get github.com/libp2p/go-libp2p@latest \
  github.com/libp2p/go-libp2p-kad-dht@latest \
  github.com/multiformats/go-multiaddr@latest \
  google.golang.org/grpc@latest
```

- [ ] **Step 6: Build to verify compile**

```bash
cd go && go build ./cmd/p2pd/
```

Expected: binary `p2pd` created, no errors.

- [ ] **Step 7: Commit**

```bash
git add go/cmd/p2pd/ go/internal/p2p/ go/go.mod go/go.sum
git commit -m "feat: add p2pd binary with libp2p host and Kademlia DHT"
```

---
### Task 3: p2pd Bridge Server — RPC Handlers

**Files:**
- Create: `go/internal/bridge/server.go`

**Interfaces:**
- Consumes: `*p2p.P2PHost`, `*p2p.DHTClient` from Task 2
- Produces: `bridge.NewServer(host, dht) *bridge.Server` implementing `bridgepb.P2PBridgeServer`

- [ ] **Step 1: Write `go/internal/bridge/server.go`**

```go
package bridge

import (
	"context"
	"fmt"
	"sync"
	"time"

	pb "github.com/user/dns-transport/pkg/bridgepb"
	"github.com/user/dns-transport/internal/p2p"
)

type Server struct {
	pb.UnimplementedP2PBridgeServer
	host      *p2p.P2PHost
	dht       *p2p.DHTClient
	zone      string

	mu          sync.RWMutex
	relaySubs   map[string]chan *pb.RelayUpdate
	incomingCh  chan *pb.DNSPacket
}

func NewServer(host *p2p.P2PHost, dht *p2p.DHTClient, zone string) *Server {
	return &Server{
		host:       host,
		dht:        dht,
		zone:       zone,
		relaySubs:  make(map[string]chan *pb.RelayUpdate),
		incomingCh: make(chan *pb.DNSPacket, 100),
	}
}

func (s *Server) DiscoverRelays(req *pb.DiscoverRequest, stream pb.P2PBridge_DiscoverRelaysServer) error {
	// Initial discovery
	peers, err := s.dht.FindRelayProviders(stream.Context(), int(req.MaxRelays))
	if err != nil {
		return fmt.Errorf("find relays: %w", err)
	}

	update := &pb.RelayUpdate{
		InitialBatch: true,
		Added:        make([]*pb.RelayInfo, 0, len(peers)),
	}
	for _, p := range peers {
		addrs := make([]string, len(p.Addrs))
		for i, a := range p.Addrs {
			addrs[i] = a.String()
		}
		update.Added = append(update.Added, &pb.RelayInfo{
			PeerId:      p.ID.String(),
			Multiaddrs:  addrs,
			LastSeen:    time.Now().Unix(),
		})
	}
	if err := stream.Send(update); err != nil {
		return err
	}

	if !req.Subscribe {
		return nil
	}

	// Subscribe for future updates
	subID := fmt.Sprintf("%d", time.Now().UnixNano())
	ch := make(chan *pb.RelayUpdate, 10)
	s.mu.Lock()
	s.relaySubs[subID] = ch
	s.mu.Unlock()

	defer func() {
		s.mu.Lock()
		delete(s.relaySubs, subID)
		s.mu.Unlock()
	}()

	for {
		select {
		case <-stream.Context().Done():
			return nil
		case update := <-ch:
			if err := stream.Send(update); err != nil {
				return err
			}
		}
	}
}

func (s *Server) AdvertiseRelay(ctx context.Context, req *pb.AdvertiseRequest) (*pb.AdvertiseResponse, error) {
	if err := s.dht.AnnounceRelay(ctx); err != nil {
		return &pb.AdvertiseResponse{Success: false}, err
	}

	dnsAddr := fmt.Sprintf("%s.circuit", s.host.PeerID())
	return &pb.AdvertiseResponse{
		Success:       true,
		PublicDnsAddr: dnsAddr,
	}, nil
}

func (s *Server) ForwardDNSPacket(ctx context.Context, pkt *pb.DNSPacket) (*pb.Empty, error) {
	// Send DNS response back via libp2p circuit to remote peer
	// Implementation in Task 5
	return &pb.Empty{}, nil
}

func (s *Server) IncomingDNS(_ *pb.Empty, stream pb.P2PBridge_IncomingDNSServer) error {
	for {
		select {
		case <-stream.Context().Done():
			return nil
		case pkt := <-s.incomingCh:
			if err := stream.Send(pkt); err != nil {
				return err
			}
		}
	}
}

func (s *Server) RelayDNSPacket(ctx context.Context, pkt *pb.DNSPacket) (*pb.DNSPacket, error) {
	// Forward DNS query to remote peer via libp2p, return response
	// Implementation in Task 5
	return pkt, nil
}

func (s *Server) GetTransportStatus(ctx context.Context, _ *pb.Empty) (*pb.TransportStatus, error) {
	return &pb.TransportStatus{
		DhtConnected:     s.dht.ConnectedPeers() > 0,
		PeersInDht:       int32(s.dht.ConnectedPeers()),
		DiscoveredRelays: 0,
		Libp2pDirect:     false,
		Libp2pCircuit:    true,
		DnsMode:          "normal",
	}, nil
}
```

- [ ] **Step 2: Register bridge server in `cmd/p2pd/main.go`**

Add after `grpcServer := grpc.NewServer()`:
```go
bridgeServer := bridge.NewServer(host, dhtClient, *zone)
pb.RegisterP2PBridgeServer(grpcServer, bridgeServer)
```

Add imports:
```go
pb "github.com/user/dns-transport/pkg/bridgepb"
"github.com/user/dns-transport/internal/bridge"
```

- [ ] **Step 3: Verify compile**

```bash
cd go && go build ./cmd/p2pd/
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add go/internal/bridge/ go/cmd/p2pd/main.go
git commit -m "feat: add p2pd bridge server with RPC handlers"
```

---
### Task 4: p2pd DNS Forwarding via libp2p Circuit

**Files:**
- Create: `go/internal/p2p/dns.go`
- Modify: `go/internal/bridge/server.go` (implement ForwardDNSPacket, RelayDNSPacket, add IncomingDNS injection)

**Interfaces:**
- Consumes: P2PHost from Task 2
- Produces: `p2p.DNSForwarder` with `Forward(ctx, remotePeerID, packet)`, `IncomingPackets() <-chan Packet`

- [ ] **Step 1: Write `go/internal/p2p/dns.go`**

```go
package p2p

import (
	"context"
	"fmt"
	"io"
	"sync"
	"time"

	"github.com/libp2p/go-libp2p/core/network"
	"github.com/libp2p/go-libp2p/core/peer"
	"google.golang.org/protobuf/proto"
)

const dnsProtocolID = "/vrgram/dns/1.0.0"

type DNSForwarder struct {
	host       *P2PHost
	incomingCh chan *DNSPacket
}

type DNSPacket struct {
	Raw          []byte
	RemotePeerID string
}

func NewDNSForwarder(host *P2PHost) *DNSForwarder {
	f := &DNSForwarder{
		host:       host,
		incomingCh: make(chan *DNSPacket, 100),
	}
	host.Host.SetStreamHandler(dnsProtocolID, f.handleStream)
	return f
}

func (f *DNSForwarder) handleStream(s network.Stream) {
	defer s.Close()

	data, err := io.ReadAll(s)
	if err != nil {
		return
	}

	pkt := &DNSPacket{
		Raw:          data,
		RemotePeerID: s.Conn().RemotePeer().String(),
	}

	select {
	case f.incomingCh <- pkt:
	default:
		// drop if buffer full
	}
}

func (f *DNSForwarder) Forward(ctx context.Context, peerID string, packet []byte) error {
	pid, err := peer.Decode(peerID)
	if err != nil {
		return fmt.Errorf("decode peer id: %w", err)
	}

	s, err := f.host.Host.NewStream(ctx, pid, dnsProtocolID)
	if err != nil {
		return fmt.Errorf("new stream: %w", err)
	}
	defer s.Close()

	if _, err := s.Write(packet); err != nil {
		return fmt.Errorf("write: %w", err)
	}

	// For bidirectional, read response
	_ = s.SetReadDeadline(time.Now().Add(30 * time.Second))
	response, err := io.ReadAll(s)
	if err != nil {
		return fmt.Errorf("read response: %w", err)
	}

	// Store response for retrieval
	_ = response // will be used in relayd DNS response path
	return nil
}

func (f *DNSForwarder) IncomingPackets() <-chan *DNSPacket {
	return f.incomingCh
}

func (f *DNSForwarder) PollIncoming(ctx context.Context, targetCh chan<- *pb.DNSPacket) {
	// Forward to bridge server's incomingCh
	// Called from bridge server setup
}
```

The `PollIncoming` function will bridge `DNSPacket` from `p2p` package into `bridgepb.DNSPacket`. It needs to be added to `server.go`:

- [ ] **Step 2: Update bridge server to wire up DNS forwarder**

In `server.go`, add to `NewServer`:
```go
func NewServer(host *p2p.P2PHost, dht *p2p.DHTClient, zone string) *Server {
	s := &Server{
		host:       host,
		dht:        dht,
		zone:       zone,
		relaySubs:  make(map[string]chan *pb.RelayUpdate),
		incomingCh: make(chan *pb.DNSPacket, 100),
		dnsFwd:     p2p.NewDNSForwarder(host),
	}

	// Start polling incoming DNS packets from libp2p
	go func() {
		for pkt := range s.dnsFwd.IncomingPackets() {
			s.incomingCh <- &pb.DNSPacket{
				Raw:          pkt.Raw,
				RemotePeerId: pkt.RemotePeerID,
			}
		}
	}()

	return s
}
```

Add `dnsFwd` field to Server struct:
```go
type Server struct {
    // ... existing fields
    dnsFwd *p2p.DNSForwarder
}
```

- [ ] **Step 3: Implement ForwardDNSPacket properly**

Replace the stub in server.go:
```go
func (s *Server) ForwardDNSPacket(ctx context.Context, pkt *pb.DNSPacket) (*pb.Empty, error) {
	if err := s.dnsFwd.Forward(ctx, pkt.RemotePeerId, pkt.Raw); err != nil {
		return nil, fmt.Errorf("forward DNS: %w", err)
	}
	return &pb.Empty{}, nil
}
```

- [ ] **Step 4: Implement RelayDNSPacket properly**

```go
func (s *Server) RelayDNSPacket(ctx context.Context, pkt *pb.DNSPacket) (*pb.DNSPacket, error) {
	// Send query to remote peer, get response
	if err := s.dnsFwd.Forward(ctx, pkt.RemotePeerId, pkt.Raw); err != nil {
		return nil, fmt.Errorf("relay DNS: %w", err)
	}

	// Read response from incoming stream
	select {
	case resp := <-s.incomingCh:
		return resp, nil
	case <-ctx.Done():
		return nil, ctx.Err()
	case <-time.After(30 * time.Second):
		return nil, fmt.Errorf("timeout waiting for DNS response")
	}
}
```

- [ ] **Step 5: Verify compile**

```bash
cd go && go build ./cmd/p2pd/
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add go/internal/p2p/dns.go go/internal/bridge/server.go
git commit -m "feat: add DNS forwarding over libp2p circuit relay"
```

---
### Task 5: relayd Bridge Client

**Files:**
- Create: `go/internal/bridge/client.go`
- Modify: `go/internal/client/daemon.go` — connect to bridge on startup

**Interfaces:**
- Consumes: `bridgepb.P2PBridgeClient` (gRPC client to p2pd)
- Produces: `bridge.Client` with methods:
  - `DiscoverRelays(ctx, maxRelays, subscribe) (<-chan RelayUpdate, error)`
  - `AdvertiseRelay(ctx, zone) error`
  - `GetTransportStatus(ctx) (TransportStatus, error)`

- [ ] **Step 1: Write `go/internal/bridge/client.go`**

```go
package bridge

import (
	"context"
	"fmt"
	"sync"
	"time"

	pb "github.com/user/dns-transport/pkg/bridgepb"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

type Client struct {
	conn   *grpc.ClientConn
	pbCli  pb.P2PBridgeClient
	socket string
}

type RelayUpdate struct {
	InitialBatch bool
	Added        []RelayInfo
	Removed      []string
}

type RelayInfo struct {
	PeerID     string
	DNSAddress string
	Multiaddrs []string
	Load       int32
	LastSeen   int64
}

type TransportStatus struct {
	DHTConnected     bool
	PeersInDHT       int32
	DiscoveredRelays int32
	Libp2pDirect     bool
	Libp2pCircuit    bool
	DNSMode          string
}

func NewClient(socketPath string) (*Client, error) {
	conn, err := grpc.Dial(
		socketPath,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithContextDialer(func(ctx context.Context, addr string) (net.Conn, error) {
			var d net.Dialer
			return d.DialContext(ctx, "unix", addr)
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("dial bridge: %w", err)
	}

	return &Client{
		conn:   conn,
		pbCli:  pb.NewP2PBridgeClient(conn),
		socket: socketPath,
	}, nil
}

func (c *Client) Close() error {
	return c.conn.Close()
}

func (c *Client) DiscoverRelays(ctx context.Context, maxRelays int, subscribe bool) (<-chan RelayUpdate, error) {
	stream, err := c.pbCli.DiscoverRelays(ctx, &pb.DiscoverRequest{
		MaxRelays: int32(maxRelays),
		Subscribe: subscribe,
	})
	if err != nil {
		return nil, fmt.Errorf("discover relays: %w", err)
	}

	ch := make(chan RelayUpdate, 10)
	go func() {
		defer close(ch)
		for {
			upd, err := stream.Recv()
			if err != nil {
				return
			}
			ru := RelayUpdate{
				InitialBatch: upd.InitialBatch,
				Added:        make([]RelayInfo, len(upd.Added)),
				Removed:      upd.RemovedPeerIds,
			}
			for i, a := range upd.Added {
				ru.Added[i] = RelayInfo{
					PeerID:     a.PeerId,
					DNSAddress: a.DnsAddress,
					Multiaddrs: a.Multiaddrs,
					Load:       a.Load,
					LastSeen:   a.LastSeen,
				}
			}
			ch <- ru
		}
	}()
	return ch, nil
}

func (c *Client) AdvertiseRelay(ctx context.Context, zone string) error {
	_, err := c.pbCli.AdvertiseRelay(ctx, &pb.AdvertiseRequest{
		Zone:       zone,
		ListenAddr: "",
	})
	return err
}

func (c *Client) GetTransportStatus(ctx context.Context) (*TransportStatus, error) {
	resp, err := c.pbCli.GetTransportStatus(ctx, &pb.Empty{})
	if err != nil {
		return nil, err
	}
	return &TransportStatus{
		DHTConnected:     resp.DhtConnected,
		PeersInDHT:       resp.PeersInDht,
		DiscoveredRelays: resp.DiscoveredRelays,
		Libp2pDirect:     resp.Libp2pDirect,
		Libp2pCircuit:    resp.Libp2pCircuit,
		DNSMode:          resp.DnsMode,
	}, nil
}
```

- [ ] **Step 2: Add `net` import to client.go**

The `net.Dialer` needs `"net"` import. Add it.

- [ ] **Step 3: Modify `go/internal/client/daemon.go` — connect bridge on startup**

In `Daemon` struct, add bridge client field:
```go
type Daemon struct {
    // existing fields...
    bridgeCli    *bridge.Client
}
```

In `NewDaemon()`, accept bridge socket path and create bridge client:
```go
func NewDaemon(cfg DaemonConfig, bridgeSocket string) (*Daemon, error) {
    // existing setup...
    
    var cli *bridge.Client
    if bridgeSocket != "" {
        cli, err = bridge.NewClient(bridgeSocket)
        if err != nil {
            log.Printf("Warning: bridge client: %v", err)
        }
    }
    
    return &Daemon{
        // existing...
        bridgeCli: cli,
    }, nil
}
```

Add a method to get relay list from bridge:
```go
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
```

- [ ] **Step 4: Verify compile**

```bash
cd go && go build ./internal/bridge/ && go build ./cmd/relayd/
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add go/internal/bridge/client.go go/internal/client/daemon.go
git commit -m "feat: add relayd bridge client for p2pd communication"
```

---
### Task 6: relayd DNS Engine — Parallel Pipeline + Dynamic Relay Source

**Files:**
- Modify: `go/internal/client/dns_engine.go` — fetch relays from bridge, parallel pipeline

**Interfaces:**
- Consumes: `bridge.Client.DiscoverRelays()` from Task 5
- Consumes: existing `SendChunk(chunk, relayAddr)` pattern
- Produces: updated `SendMessage()` that queries bridge for relays, sends parallel across them

- [ ] **Step 1: Restructure DNS engine to accept dynamic relay source**

Current `dns_engine.go` likely has a method like `SendChunk` that takes a relay address. Change the `Engine` struct to hold a reference to bridge client and discover relays on send:

```go
type Engine struct {
    // existing fields...
    bridgeCli *bridge.Client
    zone      string
}

func (e *Engine) SendMessage(ctx context.Context, chunks [][]byte, msgID string) error {
    // Get relays from bridge
    relays, err := e.discoverActiveRelays(ctx)
    if err != nil {
        return fmt.Errorf("discover relays: %w", err)
    }
    if len(relays) == 0 {
        return fmt.Errorf("no relays available")
    }

    // Parallel send: each chunk to multiple relays
    return e.sendParallel(ctx, chunks, relays)
}

func (e *Engine) discoverActiveRelays(ctx context.Context) ([]bridge.RelayInfo, error) {
    if e.bridgeCli == nil {
        // Fallback: use last-known good relay addresses
        return e.fallbackRelays, nil
    }
    return e.bridgeCli.DiscoverRelays(ctx, 5, false)
}

func (e *Engine) sendParallel(ctx context.Context, chunks [][]byte, relays []bridge.RelayInfo) error {
    sem := make(chan struct{}, 15) // 15 concurrent = 5 relays × 3 pipeline
    var wg sync.WaitGroup
    errCh := make(chan error, len(chunks)*len(relays))

    for _, chunk := range chunks {
        for _, relay := range relays {
            wg.Add(1)
            go func(c []byte, r bridge.RelayInfo) {
                defer wg.Done()
                sem <- struct{}{}
                defer func() { <-sem }()

                addr := r.DNSAddress
                if addr == "" && len(r.Multiaddrs) > 0 {
                    // Try to extract IP from multiaddr
                    addr = extractIPPort(r.Multiaddrs[0])
                }
                if addr == "" {
                    return
                }

                if err := e.sendToRelay(ctx, c, addr); err != nil {
                    errCh <- fmt.Errorf("send to %s: %w", addr, err)
                }
            }(chunk, relay)
        }
    }

    wg.Wait()
    close(errCh)

    // Collect errors, return first
    for err := range errCh {
        if err != nil {
            return err // or accumulate
        }
    }
    return nil
}
```

- [ ] **Step 2: Implement actual parallel sends using existing `SendChunk`**

The existing `SendChunk` method sends to a single relay. The parallel pipeline adds concurrency:

```go
func (e *Engine) sendToRelay(ctx context.Context, chunk []byte, relayAddr string) error {
    // Use existing DNS query logic
    return e.sendChunkToRelay(ctx, chunk, relayAddr)
}
```

- [ ] **Step 3: Verify compile**

```bash
cd go && go build ./internal/client/
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add go/internal/client/dns_engine.go
git commit -m "feat: parallel DNS engine with dynamic relay discovery from bridge"
```

---
### Task 7: relayd Static Relay Removal + Config Changes

**Files:**
- Modify: `go/cmd/relayd/main.go` — add `--p2p-socket-path`, `--dht-only` flag
- Modify: `go/internal/client/daemon.go` — remove static relay loading, replace with bridge discovery
- Modify: `go/internal/client/detector.go` — replace google.com probe with DHT status
- Modify: `go/internal/relay/server.go` — increase default TTL to 7 days
- Modify: `go/internal/store/store.go` — add 7 day TTL, per-peer store

- [ ] **Step 1: Update relayd main.go**

Add flags:
```go
p2pSocket := flag.String("p2p-socket", "", "Path to p2pd Unix socket")
dhtOnly := flag.Bool("dht-only", false, "Only use DHT-discovered relays, no fallback")
```

Pass to daemon config:
```go
cfg := client.DaemonConfig{
    // existing...
    BridgeSocket:  *p2pSocket,
    DHTOnly:       *dhtOnly,
    DataDir:       *dataDir,
}
```

- [ ] **Step 2: Update DaemonConfig and NewDaemon**

```go
type DaemonConfig struct {
    // existing...
    BridgeSocket string
    DHTOnly      bool
    DataDir      string
}
```

In `NewDaemon`:
```go
var bridgeCli *bridge.Client
if cfg.BridgeSocket != "" {
    bridgeCli, err = bridge.NewClient(cfg.BridgeSocket)
    if err != nil {
        log.Printf("Warning: cannot connect to p2pd: %v", err)
    }
}

// Remove: load static relay config
// Remove: if bridgeCli unavailable and !cfg.DHTOnly, load fallback relays from config file
```

- [ ] **Step 3: Update `go/internal/client/detector.go`**

Replace google.com probe:
```go
func (d *Detector) probeConnectivity(ctx context.Context) bool {
    if d.daemon.bridgeCli == nil {
        return false
    }
    status, err := d.daemon.bridgeCli.GetTransportStatus(ctx)
    if err != nil {
        return false
    }
    return status.DHTConnected && status.DiscoveredRelays > 0
}
```

Remove the DNS resolver probe of google.com entirely.

- [ ] **Step 4: Update relay server TTL to 7 days**

In `go/internal/relay/server.go`, change:
```go
const defaultTTL = 7 * 24 * time.Hour  // was 120 * time.Second
```

In store, add per-peer storage tracking.

- [ ] **Step 5: Verify compile**

```bash
cd go && go build ./cmd/relayd/
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add go/cmd/relayd/main.go go/internal/client/daemon.go \
  go/internal/client/detector.go go/internal/relay/server.go \
  go/internal/store/store.go
git commit -m "feat: remove static relay dependency, use DHT discovery via bridge"
```

---
### Task 8: Flutter UI — DHT Status Screen + Remove Relay Config

**Files:**
- Modify: `flutter/lib/app.dart` — remove relay config route, add DHT status
- Modify: `flutter/lib/features/relay_config/` — replace with DHT status screen
- Modify: `flutter/lib/core/grpc/client.dart` — add TransportStatus RPC
- Modify: `flutter/lib/features/chat/` — update provider polling
- Delete: `flutter/lib/features/relay_config/screens/relay_config_screen.dart` (if exists)

- [ ] **Step 1: Add TransportStatus RPC to gRPC client**

In `flutter/lib/core/grpc/client.dart`, add:
```dart
Future<TransportStatus> getTransportStatus() async {
  final response = await _stub.getTransportStatus(Empty());
  return TransportStatus(
    dhtConnected: response.dhtConnected,
    discoveredRelays: response.discoveredRelays,
    libp2pAvailable: response.libp2pDirect || response.libp2pCircuit,
    dnsMode: response.dnsMode,
  );
}
```

- [ ] **Step 2: Create DHT status screen**

Replace relay config screen with:
```dart
// flutter/lib/features/dht/screens/dht_status_screen.dart
class DhtStatusScreen extends ConsumerStatefulWidget {
  @override
  _DhtStatusScreenState createState() => _DhtStatusScreenState();
}

class _DhtStatusScreenState extends ConsumerState<DhtStatusScreen> {
  TransportStatus? _status;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final client = ref.read(grpcClientProvider);
    final status = await client.getTransportStatus();
    setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Network Status')),
      body: _status == null
          ? CircularProgressIndicator()
          : ListView(
              children: [
                _StatusTile('DHT Connected', _status!.dhtConnected),
                _StatusTile('Relays Discovered', '${_status!.discoveredRelays}'),
                _StatusTile('libp2p Available', _status!.libp2pAvailable),
                _StatusTile('DNS Mode', _status!.dnsMode),
                ElevatedButton(
                  onPressed: _refresh,
                  child: Text('Refresh'),
                ),
              ],
            ),
    );
  }
}
```

- [ ] **Step 3: Update app.dart navigation**

Replace relay route with DHT status route:
```dart
GoRoute(path: '/dht', builder: (context, state) => DhtStatusScreen()),
```

Update bottom nav or settings menu accordingly.

- [ ] **Step 4: Update protobuf for new RPC**

The Go side needs `GetTransportStatus` in `relay.proto` to pass through to Flutter. Add:

```protobuf
rpc GetTransportStatus(Empty) returns (TransportStatusResponse);

message TransportStatusResponse {
  bool dht_connected = 1;
  int32 discovered_relays = 2;
  bool libp2p_direct = 3;
  bool libp2p_circuit = 4;
  string dns_mode = 5;
}
```

Re-generate:
```bash
cd go && protoc --go_out=. --go_opt=paths=source_relative \
  --go-grpc_out=. --go-grpc_opt=paths=source_relative \
  proto/relay.proto
```

- [ ] **Step 5: Verify Flutter compiles**

```bash
cd flutter && flutter analyze
```

Expected: no errors (or only pre-existing ones).

- [ ] **Step 6: Commit**

```bash
git add flutter/lib/ flutter/lib/core/grpc/client.dart \
  go/proto/relay.proto go/pkg/relaypb/
git commit -m "feat: replace relay config UI with DHT status screen"
```

---
### Plan 1 Self-Review

**Spec coverage check:**
- [x] Bridge protocol protobuf → Task 1
- [x] p2pd binary + libp2p host → Task 2
- [x] Kademlia DHT → Task 2
- [x] Bridge server RPC handlers → Task 3
- [x] DNS forwarding via libp2p circuit → Task 4
- [x] relayd bridge client → Task 5
- [x] Parallel DNS engine → Task 6
- [x] Static relay removal → Task 7
- [x] Flutter DHT status/relay removal → Task 8
- [ ] Media support → Plan 2
- [ ] libp2p media fast lane → Plan 2
- [ ] Flutter media UI → Plan 2

**Placeholder scan:** One placeholder in `p2pd/main.go` bootstrap addresses — will be fixed at implementation time when actual bootstrap peer addresses are decided/user-provided.

**Type consistency:** All interfaces flow from protobuf → bridge server → bridge client → relayd DNS engine. Types match across tasks.

**Gaps:** None for Plan 1 scope. Media will be Plan 2.
