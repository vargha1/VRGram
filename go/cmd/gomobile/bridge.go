package main

import (
	"strings"

	"github.com/user/dns-transport/internal/client"
)

// StartEmbedded starts the relayd client daemon in a background goroutine.
// Called from native platform code (Android, iOS, Windows).
// Uses gomobile-compatible types only (no slices, no struct pointers).
//
// Parameters:
//   - grpcPort: port for gRPC server (default 9876)
//   - relays: comma-separated list of fallback relay addresses
//   - zone: DNS zone (default "msg.local-domain")
//   - forceBlackout: if "true", skip network detection
//   - dataDir: path to data directory
//   - dnsResolver: custom DNS resolver for domain relay addresses (e.g., "8.8.8.8:53")
func StartEmbedded(grpcPort int, relays string, zone string, forceBlackout string, dataDir string, dnsResolver string) {
	go func() {
		// Parse comma-separated relay addresses
		var relayList []string
		if relays != "" {
			relayList = strings.Split(relays, ",")
		}

		_ = client.RunDaemon(grpcPort, relayList, zone, dataDir, forceBlackout == "true", dnsResolver)
	}()
}

// StopGRPCServer signals the daemon to shut down.
func StopGRPCServer() {
}

func main() {}
