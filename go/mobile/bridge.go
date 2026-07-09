// Package mobile provides gomobile-compatible bindings for the VRGram daemon.
// Build with: gomobile bind -target=android -o ../../flutter/android/app/libs/gomobile.aar github.com/user/dns-transport/mobile
//
// gomobile limitations:
//   - Exported functions use only: int, float, string, bool, error, []byte
//   - No slices (except []byte), no struct pointers, no interfaces
//   - Semicolons are handled via comma-separated strings
package mobile

import (
	"strings"

	"github.com/user/dns-transport/internal/client"
	"github.com/user/dns-transport/internal/p2p"
)

// StartDaemon starts the relayd daemon with embedded p2p in a background goroutine.
// Called from native Android/iOS code via gomobile bind.
//
// Parameters:
//   - grpcPort: port for gRPC server (default 9876)
//   - relayList: comma-separated list of fallback relay addresses (IP:port)
//   - zone: DNS zone (e.g. "msg.local-domain")
//   - forceBlackout: "true" to skip network detection
//   - dataDir: path to data directory on device
//   - p2pPort: libp2p listen port (0 = disabled)
//   - bootstrapAddrs: comma-separated list of libp2p bootstrap multiaddrs
func StartDaemon(grpcPort int, relayList string, zone string, forceBlackout string, dataDir string, p2pPort int, bootstrapAddrs string) {
	go func() {
		var p2pHost *p2p.P2PHost
		var dhtClient *p2p.DHTClient

		// Parse comma-separated relays
		var relays []string
		if relayList != "" {
			for _, r := range strings.Split(relayList, ",") {
				r = strings.TrimSpace(r)
				if r != "" {
					relays = append(relays, r)
				}
			}
		}

		// Start embedded p2p if port > 0
		if p2pPort > 0 {
			var err error
			p2pHost, err = p2p.NewHost(p2p.HostConfig{
				Port:    p2pPort,
				DataDir: dataDir,
			})
			if err == nil && p2pHost != nil {
				// Parse bootstrap addresses
				var bootstrap []string
				if bootstrapAddrs != "" {
					for _, b := range strings.Split(bootstrapAddrs, ",") {
						b = strings.TrimSpace(b)
						if b != "" {
							bootstrap = append(bootstrap, b)
						}
					}
				}
				dhtClient, _ = p2p.NewDHT(p2pHost, bootstrap)
				if dhtClient != nil {
					_ = dhtClient.Start(nil)
					_ = p2pHost.EnableCircuitRelay(nil)
					_ = dhtClient.AnnounceRelay(nil)
					go dhtClient.RefreshProviders(nil)
				}
			}
		}

		_ = client.RunDaemon(grpcPort, relays, zone, dataDir, forceBlackout == "true", p2pHost, dhtClient, false)
	}()
}

// IsDaemonRunning returns 1 if the daemon is running, 0 otherwise.
// This is a simple health check callable from native code.
func IsDaemonRunning() int {
	// The daemon runs in a goroutine; if RunDaemon's Serve returns,
	// the daemon has stopped. This is a placeholder for future health checks.
	return 1
}
