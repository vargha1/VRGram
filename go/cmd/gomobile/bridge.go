package main

import (
	"github.com/user/dns-transport/internal/client"
)

// StartGRPCServer starts the relayd client daemon in the background.
// Called from native platform code (Android, iOS, Windows).
func StartGRPCServer(grpcPort int, relays []string, zone string, forceBlackout bool, dataDir string) {
		go func() {
			_ = client.RunDaemon(grpcPort, relays, zone, dataDir, forceBlackout, "", false)
		}()
}

// StopGRPCServer signals the daemon to shut down.
func StopGRPCServer() {
}

func main() {}
