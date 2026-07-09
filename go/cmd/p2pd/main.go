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
	"strings"
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

	var bootstrapAddrs []string
	if *bootstrap != "" {
		bootstrapAddrs = strings.Split(*bootstrap, ",")
	}
	// Bootstrap peers configured at deployment time

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
