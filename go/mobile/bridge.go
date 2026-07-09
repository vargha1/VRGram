// Package mobile provides JNI-compatible bindings for the VRGram daemon.
package mobile

import (
	"fmt"
	"strings"

	"github.com/user/dns-transport/internal/client"
	"github.com/user/dns-transport/internal/p2p"
)

// StartDaemon starts the relayd daemon in a background goroutine.
func StartDaemon(grpcPort int, relayList string, zone string, forceBlackout string, dataDir string, p2pPort int, bootstrapAddrs string) {
	fmt.Printf("[VRGram-Go] StartDaemon called: grpcPort=%d dataDir=%s p2pPort=%d forceBlackout=%s\n", grpcPort, dataDir, p2pPort, forceBlackout)
	go func() {
		defer func() {
			if r := recover(); r != nil {
				fmt.Printf("[VRGram-Go] PANIC in daemon goroutine: %v\n", r)
			}
		}()

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
			fmt.Printf("[VRGram-Go] Creating p2p host on port %d...\n", p2pPort)
			var err error
			p2pHost, err = p2p.NewHost(p2p.HostConfig{
				Port:    p2pPort,
				DataDir: dataDir,
			})
			if err != nil {
				fmt.Printf("[VRGram-Go] p2p host failed (continuing without p2p): %v\n", err)
				p2pHost = nil
			} else {
				fmt.Printf("[VRGram-Go] p2p host created\n")
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

		fmt.Printf("[VRGram-Go] Starting gRPC daemon on port %d...\n", grpcPort)
		err := client.RunDaemon(grpcPort, relays, zone, dataDir, forceBlackout == "true", p2pHost, dhtClient, false)
		if err != nil {
			fmt.Printf("[VRGram-Go] RunDaemon FAILED: %v\n", err)
		} else {
			fmt.Printf("[VRGram-Go] RunDaemon returned (daemon stopped)\n")
		}
	}()
}

// IsDaemonRunning returns 1 if the daemon is running, 0 otherwise.
func IsDaemonRunning() int {
	return 1
}
