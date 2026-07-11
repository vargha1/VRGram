// Package mobile provides JNI-compatible bindings for the VRGram daemon.
package mobile

import (
	"fmt"
	"log/slog"
	"os"
	"strings"

	"github.com/user/dns-transport/internal/client"
)

// StartDaemon starts the relayd daemon in a background goroutine.
func StartDaemon(grpcPort int, relayList string, zone string, forceBlackout string, dataDir string, dnsResolver string) {
	// Enable debug logging so DNS exchange errors appear in logcat
	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelDebug})))

	fmt.Printf("[VRGram-Go] StartDaemon: grpcPort=%d dataDir=%s dnsResolver=%s\n", grpcPort, dataDir, dnsResolver)
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

		err := client.RunDaemon(grpcPort, relays, zone, dataDir, forceBlackout == "true", dnsResolver)
		if err != nil {
			fmt.Printf("[VRGram-Go] RunDaemon FAILED: %v\n", err)
		} else {
			fmt.Printf("[VRGram-Go] RunDaemon exited\n")
		}
	}()
}
