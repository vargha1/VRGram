## libp2p Removal Plan

**Goal**: Remove libp2p entirely. DNS transport is the only working path. libp2p code is all optional/unimplemented (DHT discovery, circuit relay, direct P2P media all return "PoC limitation" or are optional). Removing it will cut `libvrgram.so` from 47MB to ~5-8MB.

**Go side changes**:
1. Delete `go/internal/p2p/` (5 files: host.go, dht.go, dns.go, relay.go, media.go)
2. Delete `go/internal/bridge/` (server.go + client.go - bridge between p2pd and relayd)
3. Delete `go/pkg/bridgepb/` (generated protobuf for bridge)
4. Delete `go/cmd/p2pd/` (standalone p2p daemon)
5. Delete `go/proto/bridge.proto`
6. Modify `go/cmd/relayd/main.go` - remove p2p host/DHT creation from client mode
7. Modify `go/mobile/bridge.go` - remove p2p host/DHT creation
8. Modify `go/cmd/gomobile/bridge.go` - remove p2p host/DHT creation
9. Modify `go/internal/client/daemon.go`:
   - Remove `p2pHost`, `dhtClient`, `libp2pTransport` from Daemon struct
   - Remove `Libp2pTransport` interface
   - Remove `GetP2PStatus()` method
   - Remove `DiscoverRelaysFromDHT()` method
   - Simplify `SendMedia()` - remove libp2p code path (was returning "PoC limitation" anyway)
   - Simplify `GetTransportStatus()` - no DHT checks
10. Modify `go/internal/client/detector.go` - remove DHT check, just check if relays exist
11. Modify `go/internal/media/types.go` - remove unused libp2p import (if any)
12. Run `go mod tidy` to purge all 48 libp2p-related deps

**Flutter side changes**:
1. Delete `flutter/lib/features/dht/` (dht_provider.dart, dht_status_screen.dart)
2. Modify `flutter/lib/app.dart` - remove /dht route
3. Modify `flutter/lib/features/chat/screens/chat_list_screen.dart` - remove DHT status button

**No functional impact**: DNS transport handles all messaging. Configured relays (static list) replace DHT discovery.