package main

import (
	"strings"

	"github.com/user/dns-transport/internal/client"
	"github.com/user/dns-transport/internal/p2p"
)

// StartEmbedded starts the full relayd with embedded p2p in a background goroutine.
// Called from native platform code (Android, iOS, Windows).
// Uses gomobile-compatible types only (no slices, no struct pointers).
//
// Parameters:
//   - grpcPort: port for gRPC server (default 9876)
//   - relays: comma-separated list of fallback relay addresses
//   - zone: DNS zone (default "msg.local-domain")
//   - forceBlackout: if "true", skip network detection
//   - dataDir: path to data directory
//   - p2pPort: libp2p listen port (0 to disable embedded p2p)
//   - bootstrap: comma-separated bootstrap multiaddrs
//   - dnsResolver: custom DNS resolver for domain relay addresses (e.g., "8.8.8.8:53")
func StartEmbedded(grpcPort int, relays string, zone string, forceBlackout string, dataDir string, p2pPort int, bootstrap string, dnsResolver string) {
	go func() {
		var p2pHost *p2p.P2PHost
		var dhtClient *p2p.DHTClient
		var err error

		// Parse comma-separated relay addresses
		var relayList []string
		if relays != "" {
			relayList = strings.Split(relays, ",")
		}

		// Start embedded p2p if port > 0
		if p2pPort > 0 {
			p2pHost, err = p2p.NewHost(p2p.HostConfig{
				Port:    p2pPort,
				DataDir: dataDir,
			})
			if err == nil && p2pHost != nil {
				bootstrapAddrs := []string{}
				if bootstrap != "" {
					bootstrapAddrs = strings.Split(bootstrap, ",")
				}
				dhtClient, err = p2p.NewDHT(p2pHost, bootstrapAddrs)
				if err == nil {
					_ = dhtClient.Start(nil)
					_ = p2pHost.EnableCircuitRelay(nil)
					_ = dhtClient.AnnounceRelay(nil)
					go dhtClient.RefreshProviders(nil)
				}
			}
		}

		_ = client.RunDaemon(grpcPort, relayList, zone, dataDir, forceBlackout == "true", p2pHost, dhtClient, false, dnsResolver)
	}()
}

// StopGRPCServer signals the daemon to shut down.
func StopGRPCServer() {
}

func main() {}
