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
	fmt.Printf("[VRGram-Go] StartDaemon: grpcPort=%d dataDir=%s p2pPort=%d\n", grpcPort, dataDir, p2pPort)
	go func() {
		defer func() {
			if r := recover(); r != nil {
				fmt.Printf("[VRGram-Go] PANIC recovered: %v\n", r)
			}
		}()

		// Parse relays
		var relays []string
		if relayList != "" {
			for _, r := range strings.Split(relayList, ",") {
				r = strings.TrimSpace(r)
				if r != "" {
					relays = append(relays, r)
				}
			}
		}

		var p2pHost *p2p.P2PHost
		var dhtClient *p2p.DHTClient

		if p2pPort > 0 {
			var err error
			p2pHost, err = p2p.NewHost(p2p.HostConfig{
				Port:    p2pPort,
				DataDir: dataDir,
			})
			if err != nil {
				fmt.Printf("[VRGram-Go] p2p failed (continuing): %v\n", err)
				p2pHost = nil
			}
			if p2pHost != nil {
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

		err := client.RunDaemon(grpcPort, relays, zone, dataDir, forceBlackout == "true", p2pHost, dhtClient, false)
		if err != nil {
			fmt.Printf("[VRGram-Go] RunDaemon FAILED: %v\n", err)
		} else {
			fmt.Printf("[VRGram-Go] RunDaemon exited\n")
		}
	}()
}
