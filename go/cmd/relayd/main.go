package main

import (
	"context"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"strings"
	"time"

	"github.com/user/dns-transport/internal/client"
	"github.com/user/dns-transport/internal/p2p"
	"github.com/user/dns-transport/internal/ratelimit"
	"github.com/user/dns-transport/internal/relay"
	"github.com/user/dns-transport/internal/store"
)

func main() {
	// Server mode flags
	serverCmd := flag.NewFlagSet("server", flag.ExitOnError)
	serverAddr := serverCmd.String("addr", ":53", "listen address")
	serverZone := serverCmd.String("zone", "msg.local-domain", "DNS zone")
	serverDB := serverCmd.String("db", "/var/lib/relayd", "data directory")

	// Client mode flags
	clientCmd := flag.NewFlagSet("client", flag.ExitOnError)
	clientGRPC := clientCmd.Int("grpc-port", 9876, "gRPC port")
	clientZone := clientCmd.String("zone", "msg.local-domain", "DNS zone")
	clientDataDir := clientCmd.String("data-dir", "", "data directory (default: ~/.config/relayd)")
	clientForceBlackout := clientCmd.Bool("force-blackout", false, "skip network detector, use only configured relays")
	clientP2PPort := clientCmd.Int("p2p-port", 4001, "libp2p listen port")
	clientBootstrap := clientCmd.String("bootstrap", "", "comma-separated bootstrap multiaddrs")
	clientDHTOnly := clientCmd.Bool("dht-only", false, "only use DHT-discovered relays, no fallback")

	// Relay endpoints (for client mode)
	var clientRelays relayList
	clientCmd.Var(&clientRelays, "relay", "relay endpoint (repeatable)")

	if len(os.Args) < 2 {
		fmt.Println("usage: relayd <server|client> [flags]")
		fmt.Println("\nserver mode: relayd server --addr :53 --zone msg.local-domain")
		fmt.Println("client mode: relayd client --relay 203.0.113.1:53 --force-blackout")
		os.Exit(1)
	}

	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelInfo})))

	switch os.Args[1] {
	case "server":
		serverCmd.Parse(os.Args[2:])
		runServer(*serverAddr, *serverZone, *serverDB)
		case "client":
			clientCmd.Parse(os.Args[2:])
			runClient(*clientGRPC, *clientZone, *clientDataDir, clientRelays, *clientForceBlackout, *clientP2PPort, *clientBootstrap, *clientDHTOnly)
	default:
		fmt.Fprintf(os.Stderr, "unknown mode: %s (use 'server' or 'client')\n", os.Args[1])
		os.Exit(1)
	}
}

func runServer(addr, zone, db string) {
	if err := os.MkdirAll(db, 0755); err != nil {
		slog.Error("failed to create data directory", "error", err)
		os.Exit(1)
	}

	s := store.NewChunkStore(60*time.Second, relay.DefaultChunkTTL)
	rl := ratelimit.NewIPRateLimiter(10, 20)

	slog.Info("starting relay server", "addr", addr, "zone", zone)
	if err := relay.RunServer(addr, zone, s, rl); err != nil {
		slog.Error("server failed", "error", err)
		os.Exit(1)
	}
}

func runClient(grpcPort int, zone, dataDir string, relays []string, forceBlackout bool, p2pPort int, bootstrap string, dhtOnly bool) {
	if len(relays) == 0 {
		slog.Warn("no relay endpoints configured, use --relay flag")
	}

	if dataDir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			slog.Error("cannot determine home directory", "error", err)
			os.Exit(1)
		}
		dataDir = home + "/.config/relayd"
	}

	// Create embedded p2p host and DHT
	var p2pHost *p2p.P2PHost
	var dhtClient *p2p.DHTClient

	host, err := p2p.NewHost(p2p.HostConfig{Port: p2pPort, DataDir: dataDir})
	if err != nil {
		slog.Error("failed to create p2p host", "error", err)
		os.Exit(1)
	}
	p2pHost = host
	p2pHost.Start()

	if bootstrap != "" {
		addrs := strings.Split(bootstrap, ",")
		dht, err := p2p.NewDHT(p2pHost, addrs)
		if err != nil {
			slog.Error("failed to create DHT", "error", err)
			os.Exit(1)
		}
		if err := dht.Start(context.Background()); err != nil {
			slog.Error("failed to start DHT", "error", err)
			os.Exit(1)
		}
		if err := p2pHost.EnableCircuitRelay(context.Background()); err != nil {
			slog.Warn("failed to enable circuit relay", "error", err)
		}
		if err := dht.AnnounceRelay(context.Background()); err != nil {
			slog.Warn("failed to announce relay", "error", err)
		}
		go dht.RefreshProviders(context.Background())
		dhtClient = dht
	}

	if err := client.RunDaemon(grpcPort, relays, zone, dataDir, forceBlackout, p2pHost, dhtClient, dhtOnly); err != nil {
		slog.Error("client daemon failed", "error", err)
		os.Exit(1)
	}
}

// relayList implements flag.Value for repeatable --relay flags
type relayList []string

func (r *relayList) String() string {
	return fmt.Sprintf("%v", *r)
}

func (r *relayList) Set(value string) error {
	*r = append(*r, value)
	return nil
}
