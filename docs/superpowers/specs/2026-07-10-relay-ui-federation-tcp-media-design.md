# Relay UI, Federation, TCP Media & DNS Resolver Design

**Date:** 2026-07-10
**Goal:** Implement custom relay input UI, client-side relay federation, TCP media fallback, and custom DNS resolver for domain relay addresses.

## P1: Custom Relay Input (Polish)

The `AddRelayDialog` + `addRelay`/`removeRelay` gRPC endpoints already work. Need:
- Validate `IP:port` or `domain:port` format
- Persist relay list to `<dataDir>/relays.json`
- `relay_provider.dart`: load from file on start, save on add/remove
- Show reachability status per relay (green/red indicator)

## P2: Client-Side Federation

`PollRelays()` currently stops on first relay that returns msgIDs. Change to poll ALL known relays and collect all unique msgIDs.

**Files:**
- `go/internal/client/dns_engine.go` — `PollRelays()` iterate all relays

## P3: TCP Media Proxy

**Server side (relayd):**
- Listen on TCP `:9877` in addition to UDP `:53`
- `POST /upload` — stores file, returns `file_id`
- `GET /download/<fileID>` — serves stored file
- Auto-cleanup old files after 7 days

**Client side (daemon):**
- If file > 200KB, upload via TCP to relay; else use DNS chunks

## P4: Custom DNS Resolver

**Goal:** Allow relay address as domain name (e.g., `relay.example.com:53`). Resolve it via a configurable DNS resolver (e.g., `8.8.8.8:53`).

### How it works
- UI: "DNS resolver" field (default `8.8.8.8:53`)
- When relay address is a domain, daemon resolves it via the custom DNS resolver before connecting
- Resolved IP is cached per domain

### Go side
- `DNSClientEngine`: new field `dnsResolver string`
- New method `resolveAddr(addr string) (string, error)` — if addr contains a domain, resolve via DNS resolver; otherwise return as-is
- `SendChunk` / `QueryChunk` / `PollRelays` call `resolveAddr()` before connecting

### Flutter side
- `AddRelayDialog`: add "DNS resolver" field (optional, uses default if empty)
- `relay_provider.dart`: persist DNS resolver alongside relays
- Pass `dnsResolver` to daemon via method channel

## Files Modified

| File | Change |
|------|--------|
| `flutter/lib/features/relay_config/screens/add_relay_dialog.dart` | Validate domain:port format, add DNS resolver field |
| `flutter/lib/features/relay_config/providers/relay_provider.dart` | Persist relays + DNS resolver to JSON |
| `flutter/lib/features/relay_config/widgets/relay_tile.dart` | Show reachability indicator |
| `go/internal/client/dns_engine.go` | Poll ALL relays, add domain resolution via custom DNS resolver |
| `go/internal/relay/server.go` | Add TCP listener on :9877 for file upload/download |
| `go/internal/client/daemon.go` | TCP upload/download, pass DNS resolver to engine |
| `go/cmd/relayd/main.go` | Accept --media-port flag |
| `flutter/lib/core/platform/go_bridge.dart` | Pass dnsResolver to daemon |
