# VRGram — Decentralized Relay Discovery & Media Support

**Date:** 2026-07-09
**Status:** Draft
**Applies to:** VRGram (dns-transport Go core + Flutter UI)

## Overview

VRGram evolves from operator-run relay servers to a **fully decentralized P2P relay network** using libp2p Kademlia DHT. All clients are also relays. DNS TXT queries remain the primary transport for text and small media. libp2p provides a fast lane for larger media when direct connectivity exists.

**Key design decisions:**
- **libp2p** (`go-libp2p-kad-dht`) for DHT relay discovery and media fast lane
- **All clients are relays** — every node stores chunks for others
- **Separate p2pd bridge process** communicates with relayd via Unix socket/protobuf
- **DNS stays primary transport** for text and small media
- **Hybrid media** — DNS for small, libp2p stream for large when available
- **Auto-select transport** based on file size and connectivity

---

## Architecture

```
┌──────────┐  gRPC :9876  ┌────────────┐  Unix socket  ┌──────────────┐
│  Flutter  │◄────────────►│  relayd     │◄─────────────►│  p2pd        │
│  (UI)     │              │ (client)    │               │ (DHT+libp2p) │
└──────────┘              │ DNS engine  │               └──────┬───────┘
                           │ chunk store │                     │
                           │ offline q   │              libp2p TCP/QUIC
                           │ media mgr   │                     │
                           └────────────┘              ┌───────▼───────┐
                                                        │  Other peers  │
                                                        │  (also p2pd)  │
                                                        └───────────────┘
```

### Two processes, one purpose

| Process | Binary | Role |
|---------|--------|------|
| **relayd** | `relayd` | Client daemon — DNS send/receive, chunk store, offline queue, gRPC API, media handling, encryption. Runs per-user, platform daemon. |
| **p2pd** | `p2pd` | P2P bridge — libp2p host, Kademlia DHT, NAT traversal, relay advertisement/discovery, media stream transport. Runs alongside relayd, new binary. |

Communication between relayd and p2pd via **Unix socket** (Linux/macOS/Android) or **named pipe** (Windows). Protobuf-based protocol.

---

## Bridge Protocol: relayd ↔ p2pd

Protobuf service over local Unix socket:

```protobuf
service P2PBridge {
  rpc DiscoverRelays(DiscoverRequest) returns (stream RelayUpdate);
  rpc AdvertiseRelay(AdvertiseRequest) returns (AdvertiseResponse);
  // Send DNS response back via libp2p circuit to remote peer
  rpc ForwardDNSPacket(DNSPacket) returns (Empty);
  // Stream of incoming DNS queries from remote peers via libp2p circuit
  rpc IncomingDNS(Empty) returns (stream DNSPacket);
  // Bidirectional DNS relay: send query, get response (for relay-to-relay forwarding)
  rpc RelayDNSPacket(DNSPacket) returns (DNSPacket);
  rpc GetTransportStatus(Empty) returns (TransportStatus);
  rpc StreamMedia(MediaStreamRequest) returns (stream MediaChunk);
  rpc SendMedia(stream MediaChunk) returns (MediaResult);
}

message RelayInfo {
  string peer_id = 1;
  string dns_address = 2;       // "publicIP:53" or "circuit:peerid"
  repeated string multiaddrs = 3;
  int32 load = 4;               // 0-100
  int64 last_seen = 5;
}

message DiscoverRequest {
  int32 max_relays = 1;   // max relays to return (default 20)
  bool subscribe = 2;     // if true, continue streaming updates after initial response
}

message RelayUpdate {
  bool initial_batch = 1; // true = initial discovery results, false = incremental change
  repeated RelayInfo added = 2;
  repeated string removed_peer_ids = 3;
}

message AdvertiseRequest {
  string zone = 1;
  string listen_addr = 2;       // local DNS listen addr, e.g. "127.0.0.1:53"
}

message AdvertiseResponse {
  bool success = 1;
  string public_dns_addr = 2;   // "(peerid).circuit" if NAT'd, "ip:port" if public
}

message DNSPacket {
  bytes raw = 1;
  string remote_peer_id = 2;
}

message TransportStatus {
  bool dht_connected = 1;
  int32 peers_in_dht = 2;
  int32 discovered_relays = 3;
  bool libp2p_direct = 4;       // can reach target peer directly
  bool libp2p_circuit = 5;      // can reach via circuit relay
  string dns_mode = 6;          // "normal" | "blackout" | "offline"
}

message MediaStreamRequest {
  string target_peer_id = 1;
  string message_id = 2;
  string filename = 3;
  string mime_type = 4;
  int64 file_size = 5;
}

message MediaChunk {
  string message_id = 1;
  bytes data = 2;
  int32 sequence = 3;
  bool is_last = 4;
}

message MediaResult {
  bool success = 1;
  string error = 2;
}
```

---

## DHT Relay Discovery

### Namespace

Kademlia DHT well-known key: `/vrgram/relays`

All relay-capable peers advertise as providers for this key.

### Peer Identity

- libp2p keypair generated on first run, saved to `~/.config/vrgram/p2p.key`
- libp2p PeerID derived from public key
- Distinct from X25519 identity key used for E2E encryption

### Advertisement (p2pd startup)

1. Start libp2p host on ports 4001 (TCP) + 4001 (QUIC)
2. Bootstrap DHT from hardcoded bootstrap nodes
3. Announce as provider for `/vrgram/relays`
4. Set metadata in peer record: zone, public DNS address (if public), load %, software version
5. Re-announce every 30 minutes
6. Store recent messages in memory for offline recipients (7 day TTL)

### Discovery (relayd → p2pd: DiscoverRelays)

1. p2pd queries DHT for providers of `/vrgram/relays`
2. Gets list of PeerIDs advertising relay capability
3. Dials each to fetch peer record (multiaddrs, metadata)
4. Filters: alive only, exclude self, max N (default 20)
5. Returns to relayd as stream of RelayUpdate messages
6. p2pd continues streaming updates as peers join/leave DHT

### Bootstrap Nodes

5-10 hardcoded bootstrap peers. Standard Kademlia bootstrap — only entry points, not relays. DNS-mapped domain recommended: `bootstrap.vrgram.net`.

Users can add custom bootstrap addresses via config file or Flutter UI.

### Relay Selection

relayd scores discovered relays every 5 minutes:

```
score = uptime_weight(40%) + latency_weight(30%) + version_weight(20%) + capacity_weight(10%)
```

Selects top 5 relays for active use. Rotates on failure or blackout.

---

## Data Flow — Sending a Text Message

1. User types message in Flutter, taps Send
2. Flutter → relayd: `SendMessage{peer_pubkey, plaintext}`
3. relayd encrypts with X25519+XChaCha20-Poly1305 (existing code)
4. relayd → p2pd: `DiscoverRelays{max_relays: 5}`
5. p2pd returns relay set from DHT
6. relayd chunks ciphertext (220 bytes per chunk, existing code)
7. relayd sends each chunk via DNS TXT to each selected relay (existing engine, parallelized)
8. relayd marks message sent → Flutter shows delivery status

---

## Data Flow — Receiving a Message (Receiver Behind NAT)

1. Relays store incoming chunks in memory (7 day TTL)
2. relayd polls discovered relays: `QueryChunk{msg_id}` every 5 seconds (same as current PollMessages, now queries DHT relays)
3. On receiving all chunks: reassemble, decrypt, notify Flutter
4. Flutter shows new message bubble

For libp2p-connected peers: p2pd notifies relayd immediately when chunk arrives via IncomingDNS stream, skipping poll interval.

### Data Flow — Direct DNS (Receiver on Public IP)

Same as current server mode. relayd listens on UDP :53 (or configured port). Other peers' DNS queries arrive directly. p2pd advertises `publicIP:53` in DHT.

---

## Media Transport

### Size-based transport selection

| Media type | Typical size | Default transport | Estimated delivery time |
|-----------|-------------|------------------|----------------------|
| Text | < 1 KB | DNS | 0.1s |
| Voice note | ~240 KB | DNS (or libp2p if available) | ~6s DNS / ~0.5s libp2p |
| Photo | ~2 MB | DNS (or libp2p if available) | ~45s DNS / ~2s libp2p |
| File | > 2 MB | libp2p preferred | ~30s libp2p |
| Video | > 10 MB | libp2p required | ~min libp2p |

### Threshold: 240 KB

- **≤ 240 KB**: Send via DNS (parallelized). libp2p also acceptable if available.
- **> 240 KB**: Send via libp2p. If libp2p unavailable, show user warning: "This file will take ~X minutes via DNS. Continue?"
- **> 10 MB**: libp2p required. DNS blocked for files this large.

### DNS media path (voice, small photos, small files)

1. File binary → E2E encrypt with per-file AES-256 key
2. Split into 200-byte chunks
3. Send metadata message (includes filename, mime, size, AES key, checksum) via DNS
4. Send chunks via parallel DNS TXT to 3 relays (redundancy)
5. Recipient polls relays, receives chunks, reassembles file
6. Decrypts using per-file key from metadata message

### libp2p media path

1. relayd tells p2pd: `SendMedia{target_peer_id, message_id, filename, mime, size}`
2. p2pd opens libp2p stream to recipient's p2pd (direct or circuit)
3. Stream transfers encrypted file bytes in 64 KB chunks
4. On completion: sender relayd creates notification
5. Recipient p2pd writes encrypted file to local cache
6. Recipient relayd decrypts and pushes to Flutter

### Thumbnails

Images and video generate 256x256 thumbnail before send. Thumbnail sent via DNS (small). Full media sent via libp2p or DNS depending on size.

---

## Offline & Queue

### Message Receipt & Notification

- Relay stores chunks for 7 days. Longer TTL than current 120s — necessary for offline delivery.
- Sender-chosen TTL (1-7 days) included in chunk metadata header.
- If recipient hasn't polled, relay marks "unclaimed." Sender notified after TTL expiry.

### libp2p offline handling

- p2pd checks: is target peer online in DHT?
- If online: send via libp2p stream immediately
- If offline: fall back to DNS, send via discovered relays

### Offline queue (existing, now enhanced)

- Outbound messages queued in SQLite when DNS relays also unreachable
- Retry every 30s (existing)
- When connectivity restores: flush queue via DNS
- Media in queue: skip DNS for files > 240 KB, queue until libp2p available

---

## relayd Changes

### Modified files

| File | Change |
|------|--------|
| `internal/client/daemon.go` | Add p2pd bridge client connection at startup. Remove static relay config loading. Add bridge health check and auto-restart. Replace `AddRelay RPC` with DHT status. |
| `internal/client/dns_engine.go` | Get relay list from bridge client instead of static config. Add parallel pipeline (3-5 concurrent sends per relay, send to 5 relays in parallel). |
| `internal/client/queue.go` | Add media-aware queuing. Skip DNS for files > 240 KB. Store file metadata alongside message. |
| `internal/encoding/encoding.go` | Add media chunk metadata (file_name, mime_type, ttl). Add media message type flag to chunk encoding. |
| `internal/relay/server.go` | Increase default TTL from 120s to 7 days. Add storage limit per peer (10 MB). Add per-peer storage quota. |
| `internal/store/store.go` | Add 7 day TTL. Replace simple map with per-peer store. Add storage limits with LRU eviction. Add cleanup by TTL expiry. |
| `internal/client/detector.go` | Remove google.com probe. Replace with p2pd connectivity status. DHT-connected = network OK. libp2p circuit reachable + at least 1 relay = blackout mode off. |
| `internal/media/media.go` | **New file.** Media metadata encoding/decoding, thumbnail generation, media type detection from binary. |
| `internal/media/thumbnail.go` | **New file.** Thumbnail generator for images/video (Go standard lib + ffmpeg exec). 256x256 JPEG. |
| `cmd/relayd/main.go` | Add `--p2p-socket-path` flag. Support running without p2pd (fallback to hardcoded bootstrap routers as relays, blackout mode only). |

### New p2pd dependency in go.mod

```
github.com/libp2p/go-libp2p v0.36.x
github.com/libp2p/go-libp2p-kad-dht v0.25.x
github.com/libp2p/go-libp2p-pubsub (optional, for future)
github.com/multiformats/go-multiaddr v0.12.x
```

---

## p2pd Process (new binary)

### `cmd/p2pd/main.go`

```go
Usage: p2pd [--socket /path/to/p2p.sock] [--port 4001] [--bootstrap addrs...]

Flags:
  --socket string      Unix socket path for relayd communication (default: ~/.config/vrgram/p2p.sock)
  --port int           libp2p listen port (default: 4001)
  --quic-port int     QUIC listen port (default: same as --port)
  --bootstrap strings Comma-separated bootstrap multiaddrs
  --zone string       DNS zone for relay advertisement (default: msg.local-domain)
  --data-dir string   Data directory for keypair (default: ~/.config/vrgram)
  --log-level string   debug | info | warn | error (default: info)
  --announce-interval  DHT re-announce interval in minutes (default: 30)
  --max-relay-peers    Max relay connections (default: 50)
```

### Internal packages

| Package | File | Purpose |
|---------|------|--------|
| `internal/p2p/host.go` | `go/internal/p2p/host.go` | libp2p host setup, key loading/generation, NAT traversal (AutoNAT, hole-punch) |
| `internal/p2p/dht.go` | `go/internal/p2p/dht.go` | Kademlia DHT — bootstrap, provider announce, provider discovery, peer routing |
| `internal/p2p/relay.go` | `go/internal/p2p/relay.go` | Circuit relay host/relay logic. Act as relay for other NAT'd peers. |
| `internal/p2p/media.go` | `go/internal/p2p/media.go` | libp2p stream for media transfer. Opening streams, reading/writing chunks. |
| `internal/p2p/dns.go` | `go/internal/p2p/dns.go` | DNS packet forwarding between relayd and remote peers via libp2p circuit. |
| `internal/bridge/server.go` | `go/internal/bridge/server.go` | Bridge protocol — protobuf service for relayd communication. Wire up all bridge RPCs. |
| `internal/bridge/client.go` | `go/internal/bridge/client.go` | Bridge client lib (imported by relayd). Connects to p2pd Unix socket. |

### Architecture — p2pd internals

```
p2pd
  │
  ├── libp2p host
  │     ├── Kademlia DHT (discovery + advertisement)
  │     ├── Circuit relay v2 (NAT traversal)
  │     ├── AutoNAT (detect public/NAT'd)
  │     ├── Hole-punch (direct connection through NAT)
  │     └── Stream handlers (media, DNS forwarding)
  │
  ├── Bridge server (Unix socket)
  │     ├── DiscoverRelays → DHT lookup
  │     ├── AdvertiseRelay → DHT provider announce
  │     ├── ForwardDNS → libp2p circuit relay
  │     ├── IncomingDNS → incoming DNS traffic
  │     ├── SendMedia → libp2p stream send
  │     ├── ReceiveMedia → libp2p stream recv
  │     └── GetTransportStatus → DHT + connectivity report
  │
  └── Bootstrap manager
        ├── Hardcoded bootstrap peers
        └── DNS-resolvable bootstrap list
```

---

## Flutter UI Changes

### New screens & modifications

| Screen | Change |
|--------|--------|
| Chat input | Add **📷 image**, **🎤 voice**, **📎 file**, **🎥 video** buttons. Show estimated time before send when DNS path. |
| Chat message | **Media bubble** — image thumbnail, video thumbnail with play, voice waveform with play/pause, file icon with name/size. Download progress bar when chunks arriving. |
| Media viewer | Full-screen image viewer (gesture zoom). Video player (exo_player on Android, AVPlayer on iOS). Voice player (waveform). |
| Bottom nav | Add **Chats**, **Peers**, **Settings** tabs. Remove **Relays** tab. Add DHT relay count badge to Settings. |
| Settings | **Relay config removed** (replaced by DHT auto-discovery). Show DHT status: connected/disconnected, discovered relay count, libp2p connectivity. Show bootstrap peers. |
| Peer settings | Add per-peer transport status: "DNS only" vs "libp2p available". |
| Peer add | Same — copy/paste X25519 public key. |

### New Flutter packages needed

```
flutter_picker_image   — camera/gallery image selection
flutter_sound          — voice recording
flutter_video_player   — video playback
flutter_file_picker     — file selection
flutter_image_viewer    — full-screen image viewer
```

### New gRPC endpoints

```protobuf
service RelayDaemon {
  // Existing:
  rpc SendMessage(SendRequest) returns (SendResponse);
  rpc PollMessages(PollRequest) returns (PollResponse);
  rpc GetRelayStatus(Empty) returns (RelayStatus);
  rpc AddRelay(AddRelayRequest) returns (AddRelayResponse);
  rpc RemoveRelay(RemoveRelayRequest) returns (RemoveRelayResponse);
  rpc GetIdentity(Empty) returns (IdentityResponse);
  rpc AddPeer(AddPeerRequest) returns (AddPeerResponse);

  // New:
  rpc GetTransportStatus(Empty) returns (TransportStatusResponse);
  rpc SendMedia(SendMediaRequest) returns (SendMediaResponse);
  rpc GetMediaStatus(GetMediaStatusRequest) returns (MediaStatusResponse);
  rpc CancelSend(CancelSendRequest) returns (Empty);
}

message TransportStatusResponse {
  bool dht_connected = 1;
  int32 discovered_relays = 2;
  bool libp2p_available = 3;
  int32 peers_online = 4;
  string current_dns_mode = 5;  // "normal" | "blackout" | "offline"
}

message SendMediaRequest {
  string peer_pubkey = 1;
  bytes media_data = 2;
  string filename = 3;
  string mime_type = 4;
  enum Transport {
    AUTO = 0;
    DNS = 1;
    LIBP2P = 2;
  }
  Transport preferred_transport = 5;
}

message SendMediaResponse {
  string message_id = 1;
  int32 estimated_seconds = 2;
  string transport = 3;  // "dns" | "libp2p"
}

message MediaStatusResponse {
  string message_id = 1;
  enum Status {
    QUEUED = 0;
    SENDING = 1;
    ARRIVING = 2;
    COMPLETE = 3;
    FAILED = 4;
  }
  Status status = 2;
  int32 progress_pct = 3;       // only meaningful during SENDING/ARRIVING
  string error = 4;
}
```

---

## Media Metadata & Encryption

### Per-file E2E encryption

```
File (binary)
  ↓
AES-256-GCM with random 256-bit file_key
  ↓
Encrypted file data
  ↓
Split into 200-byte chunks (for DNS) or 64 KB chunks (libp2p)
  ↓
Each chunk sent separately
```

### Metadata message (sent before or alongside file)

Encrypted with existing X25519+XChaCha20-Poly1305 per-peer key:

```json
{
  "message_id": "...",
  "timestamp": 1700000000,
  "type": "image",
  "text": null,
  "file": {
    "name": "photo.jpg",
    "mime": "image/jpeg",
    "size": 2048576,
    "chunks": 9547,
    "chunk_size": 200,
    "file_key_b64": "base64...",
    "checksum": "sha256:abc123..."
  },
  "has_thumbnail": true,
  "thumbnail": {
    "mime": "image/jpeg",
    "size": 15360,
    "chunks": 72
  }
}
```

Thumbnail sent separately via DNS (small, always fits in DNS, always sent via DNS).

### Local file storage

```
~/.config/vrgram/
  media/
    incoming/
      {message_id}/
        encrypted_file.bin
        metadata.json
        thumbnail.jpg
        decrypted_original.jpg  (after decryption)
    outgoing/
      {message_id}/
        original_file.jpg
        thumbnail.jpg
        encrypted_file.bin
```

---

## Optimized DNS Engine

### Parallel pipeline

```
For each chunk:
  ├── Relay 1 → chunk_a
  ├── Relay 2 → chunk_a     (redundancy)
  ├── Relay 3 → chunk_a
  ├── Relay 4 → chunk_b     (next chunk, same relays)
  ├── Relay 5 → chunk_b
  └── ...
  │
  ├── Batch 1: chunks 1-5 (send to 5 relays simultaneously)
  ├── Batch 2: chunks 6-10
  └── ...
```

- 5 relay targets × 3 concurrency = 15 parallel queries
- Pipeline depth: send next batch while awaiting responses
- Timeout per query: 10 seconds
- Retry failed chunk on same relay (3 attempts)
- Retry all chunks on new relay if primary relay fails completely

### Better encoding

- Use base32hex without padding (existing, good)
- Consider base64url for 33% better density in labels (but - vs _ might confuse DNS: use base32hex)
- Max 220 bytes per chunk (existing, keep)
- Could optimize to 235 bytes with tighter overhead calculation

### Chunk acknowledgement

Relay returns TXT record with chunk ID and timestamp. Sender knows chunk stored. If no ACK within 10s, retry on different relay.

---

## Error Handling & Reliability

### Relay failure

- relayd tracks ACK/nack ratio per relay
- If a relay fails 3+ consecutive: deprioritize, remove from active set
- Notify p2pd to deprioritize in future DiscoverRelays
- If no relays available: queue offline (existing)

### libp2p stream failure

- If libp2p send fails mid-stream: fall back to DNS for any remaining file
- If file > 10 MB: abort, notify user "libp2p connection lost, try again later"
- Auto-retry libp2p connection every 60s

### NAT traversal failure

- If p2pd can't establish circuit relay to relay: DNS only mode
- If p2pd can't hole-punch: keep using circuit relay

### Bridge failure (p2pd crash)

- relayd detects Unix socket disconnection
- Wait 3 seconds, restart p2pd process
- If restart fails 3 times: fallback to DNS with hardcoded bootstrap routers as static relays

---

## Security & Trust

### Relay trust model

- **No trust required.** All messages E2E encrypted before reaching relay.
- Relay can see: sender IP, chunk count, timing (metadata leakage)
- Chunk padding (existing 0-64 bytes random) extended to 0-255 bytes for media to obscure file size estimation
- Relay cannot decrypt content, cannot correlate chunks without both sender and recipient PeerID

### Relay storage limits

- Per-peer storage quota: 10 MB (configurable)
- Total relay storage: 100 MB (configurable, LRU eviction)
- Chunk TTL: sender-specified 1-7 days

### libp2p security

- libp2p encrypted by default (TLS 1.3 or Noise)
- PeerIDs authenticated via libp2p keypair
- libp2p circuit relay uses relay v2 with ACLs (only relay DNS/media, no abuse)
- Rate limit per connection: 10 MB/min for media, 50 chunks/min for DNS forwarding

---

## Migration Path from Current Architecture

1. **Phase 0:** Write p2pd binary and bridge protocol (text only, no media)
2. **Phase 1:** Integrate p2pd into relayd startup. relayd gets relays from p2pd instead of static config.
3. **Phase 2:** Remove static relay config from Flutter UI. Add DHT status UI.
4. **Phase 3:** Add media support (voice, image, file, video)
5. **Phase 4:** Add media via libp2p fast lane

### Backward compatibility

- Old `relayd` (non-DHT) nodes will be discovered as providers by new `p2pd`
- Old static relay IPs can be configured as bootstrap routers for p2pd
- Mixed network: some users on old relays, some on DHT — messages routed via whichever relays sender knows
- Deprecation: hardcoded bootstrap routers replaced by DHT-only after 90 days

---

## Open Questions

1. Bootstrap nodes — are these run by project maintainers? 5 nodes on VPS sufficient.
2. Android background service — p2pd needs to keep running. Use Android Foreground Service notification.
3. Storage quotas on phone — phones have limited storage. Relay storage capped at 100 MB default. Configurable.
4. Voice recording: Flutter Sound or Native codec? Flutter Sound package for PoC.
5. Video encoding: Send raw H.264 or transcode? Send raw for speed, transcode optional.
6. Thumbnail generation: server-side (in relayd) or client-side? Client-side (Flutter UI generates thumbnail before send, sends alongside file).

---

**Decision requested:** Does this spec look good? Any revisions needed before I do self-review and you approve?