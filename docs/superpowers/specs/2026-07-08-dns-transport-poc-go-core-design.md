# DNS Transport Social Platform — PoC: Go Transport Core

## Overview

Build the Go-based DNS transport core for a censorship-resilient peer-to-peer
messaging system. This is Sub-Project 1 of the PoC phase (text messaging only,
no media). The Go core is a standalone binary (`relayd`) with two operating
modes that share the same code library.

## Architecture

```
┌──────────────────────────────────────────────┐
│                 relayd                        │
│                                               │
│  ┌──────────┐    ┌───────────────────────┐   │
│  │ DNS mode │    │    Client daemon mode  │   │
│  │ (server) │    │                       │   │
│  │ :53 UDP  │    │  ┌─────────────────┐  │   │
│  │          │    │  │ DNS query engine │  │   │
│  │          │    │  │ (outbound)       │  │   │
│  │          │    │  └────────┬────────┘  │   │
│  │          │    │           │           │   │
│  │          │    │  ┌────────▼────────┐  │   │
│  │          │    │  │ gRPC API server │  │   │
│  │          │    │  │ :9876           │  │   │
│  │          │    │  └─────────────────┘  │   │
│  └──────────┘    └───────────────────────┘   │
│                                               │
│  Shared library:                              │
│  ┌──────┐ ┌──────────┐ ┌────────┐ ┌───────┐ │
│  │dns   │ │ encoding │ │ crypto │ │store  │ │
│  │layer │ │ /chunk   │ │        │ │&fwd   │ │
│  └──────┘ └──────────┘ └────────┘ └───────┘ │
└──────────────────────────────────────────────┘
         ▲                    ▲
         │ DNS queries        │ gRPC (localhost)
         │ (UDP :53)          │
         ▼                    ▼
    Other peers           Flutter app
```

## Modes

### 1. Server mode (`relayd server`)

Authoritative DNS relay. Owns a zone (e.g. `msg.local-domain`).

- Listens on UDP :53
- Accepts incoming TXT queries carrying message chunks
- Validates format: base32hex-encoded labels with metadata
- Stores chunks in memory (TTL-bounded, GC every 60s)
- Returns acknowledgement or stored response data on matching msgID/chunkIndex
- Does NOT decrypt — ciphertext only
- Logs: peer public key (hash), query count, chunk size, timestamp
- Rate-limit: max 10 queries/sec per source IP; burst 20
- No recursion, no root-hints — authoritative only for its zone

### 2. Client daemon mode (`relayd client`)

Local daemon that Flutter talks to. Runs on user machine.

- Starts gRPC server on 127.0.0.1:9876
- Exposes protobuf API (see gRPC Contract section)
- Sends DNS queries to configured relay endpoints (list of IPs)
- Handles: chunking, reassembly, encryption, retry/backoff, failover
- Offline queue: chunks queue to disk (SQLite); retry every 30s
- Network-mode detector: try resolving a known domain via OS resolver; if fail,
  switch to direct-relay-only mode

## Message Encoding

### Subdomain label format

```
[msgID].[chunkIdx].[totalChunks].[checksum].[payload].[zone]
```

Each label max 63 bytes; total name max 253 bytes.

- `msgID`: 8 bytes, random, base32hex → 13 chars
- `chunkIdx`: 2 bytes, big-endian int, base32hex → 4 chars
- `totalChunks`: 2 bytes → 4 chars
- `checksum`: 2 bytes CRC16 of payload → 4 chars
- `payload`: up to 220 bytes, base32hex → ~352 chars, spread across labels
  (split at 63-char boundaries)
- `zone`: static suffix, e.g. `msg.local-domain`

Total overhead: ~25 chars of metadata per query.

### Example

```
abc123def4567.0001.0012.a1b2.<base32hex_payload_part1>.<base32hex_payload_part2>.msg.local-domain
```

Query type: TXT. Response: TXT record with ack (msgID + chunkIdx + OK/NAK).

### EDNS0 support

If UDP query returns TC (truncated) bit or response > 512B, client retries
over TCP/53 with EDNS0 (4KB buffer). Server always supports TCP.

## Chunking

- Max payload per chunk: 220 bytes (leaves margin after base32 expansion)
- Message broken into N chunks of 220 bytes, last chunk may be smaller
- Each chunk sent as independent DNS query
- Receiver reassembles via `msgID + chunkIdx` ordering
- Out-of-order: buffer holds all chunks; reassemble when all received or
  timeout (30s per message)
- Timeout GC: incomplete message sets purged after 60s

## Retry & Backoff

- Chunk retry: 3 attempts per chunk
- Backoff: 500ms, 1s, 2s (exponential with jitter ±25%)
- If all attempts fail for any chunk, entire message marked failed
- Flutter notified via gRPC status callback

## E2E Encryption

### Key exchange

- Each peer generates X25519 keypair on first run
- Public key is peer identity (base64-encoded, 44 chars)
- Public key fingerprints shared out-of-band for PoC (copy-paste)
- Shared secret derived via X25519 + BLAKE2b (keyed)

### Per-message encryption

```
plaintext → XChaCha20-Poly1305 (key = HChaCha20(subkey, msg_nonce))
  where subkey = BLAKE2b(shared_secret, key=conversation_key)
```

- 24-byte nonce (random, transmitted as metadata)
- 16-byte Poly1305 tag appended to ciphertext
- Total overhead per message: 40 bytes + ciphertext expansion
- Relay server never sees keys — only ciphertext + nonce

### Key storage

- Private key stored in file `~/.config/relayd/identity.key` (PEM-like format)
- Peer public keys stored in `~/.config/relayd/peers.json` (map of nickname→key)

## gRPC Contract (protobuf)

```protobuf
service RelayClient {
  // Send a text message to a peer
  rpc SendMessage(SendRequest) returns (SendResponse);

  // Poll for new received messages
  rpc PollMessages(PollRequest) returns (PollResponse);

  // Get status of configured relay endpoints
  rpc GetRelayStatus(Empty) returns (RelayStatusList);

  // Add/remove relay endpoint
  rpc AddRelay(RelayEndpoint) returns (Empty);
  rpc RemoveRelay(RelayEndpoint) returns (Empty);

  // Get own public key
  rpc GetIdentity(Empty) returns (IdentityInfo);

  // Add a peer's public key
  rpc AddPeer(PeerInfo) returns (Empty);
}

message SendRequest {
  string peer_pubkey = 1;     // Recipient's public key (base64)
  bytes plaintext = 2;        // Unencrypted message content
}

message SendResponse {
  string message_id = 1;      // Assigned msgID
  bool queued = 2;            // Queued for delivery
  int32 chunk_count = 3;      // Total chunks
}

message PollResponse {
  repeated ReceivedMessage messages = 1;
}

message ReceivedMessage {
  string from_peer = 1;       // Sender public key hash
  string message_id = 2;
  bytes plaintext = 3;        // Decrypted content
  int64 timestamp = 4;
}

message RelayEndpoint {
  string address = 1;         // IP:port or domain:port
}

message RelayStatusList {
  repeated RelayStatus endpoints = 1;
}

message RelayStatus {
  string address = 1;
  bool reachable = 2;
  int64 latency_ms = 3;
  string last_error = 4;
}

message IdentityInfo {
  string pubkey = 1;          // base64-encoded
}

message PeerInfo {
  string nickname = 1;
  string pubkey = 2;
}
```

## Network Mode Detector

On startup and every 60s:
1. Try resolving `google.com` via system resolver (timeout 3s)
2. If success → "normal" mode (can use full DNS if needed, but still
   uses relay list for messaging to minimize fingerprint)
3. If failure → "blackout" mode: use only configured relay IP list,
   skip all public resolver interactions
4. Flutter gRPC endpoint `GetRelayStatus` returns mode info

## Rate-Limiting & Fingerprint Reduction

- Random padding: 0–64 random bytes appended to each chunk before encoding
- Query timing jitter: delay between chunks randomized ±500ms around base
- Per-peer cap: max 5 chunks/sec sustained
- Per-peer burst: max 10 chunks in 2s window, then rate-limited
- Code comment: "This reduces but does not eliminate traffic analysis
  signature. DNS tunneling is detectable by sophisticated DPI."

## CLI Flags

```
relayd server --port 53 --zone msg.local-domain --db /var/lib/relayd
relayd client --relay 203.0.113.1 --relay 198.51.100.2 --grpc-port 9876
```

- `server`: `--port` (default 53), `--zone`, `--db` (path to storage)
- `client`: `--relay` (repeatable), `--grpc-port` (default 9876),
  `--data-dir` (config/keys/queue path)

## Project Structure

```
go/
├── cmd/
│   └── relayd/
│       ├── main.go           # Entry, flag parse, mode dispatch
│       └── server.go         # Server mode setup
├── internal/
│   ├── dns/                  # DNS query/response handling (miekg/dns)
│   ├── encoding/             # Base32hex, chunking, reassembly
│   ├── crypto/               # X25519, XChaCha20-Poly1305
│   ├── store/                # In-memory store-and-forward, GC
│   ├── client/               # Client daemon: gRPC server, dns engine
│   └── ratelimit/            # Token bucket per-IP/per-peer
├── pkg/
│   └── relaypb/              # Generated protobuf Go code
├── proto/
│   └── relay.proto           # gRPC contract definition
├── go.mod
└── go.sum
flutter/
└── (Sub-Project 2 — separate spec)
```

## Out of scope (PoC)

- Image/file transfer
- Voice/video notes
- Group chat (1:1 only)
- Signed config distribution
- TCP fallback for EDNS0 (PoC uses UDP + optional TCP)
- iOS support (Android + desktop PoC)
- Fancy UI — basic chat interface sufficient

## Dependency graph

```
relayd → github.com/miekg/dns
       → google.golang.org/grpc
       → google.golang.org/protobuf
       → golang.org/x/crypto (XChaCha20-Poly1305, X25519)
       → github.com/mattn/go-sqlite3 (offline queue)
```

## Error Handling

- DNS query timeout → retry with next relay endpoint in list
- All retries exhausted → store chunk in offline queue (SQLite)
- gRPC returns status: OK, QUEUED, FAILED, OFFLINE
- Server returns SERVFAIL for malformed queries; NXDOMAIN for unknown msgID
- Client logs all errors to stderr with structured logging (log/slog)

## Testing Strategy

- Unit tests per package (encoding, crypto, chunking)
- Integration test: spin up server mode, send queries via client mode,
  verify message delivery end-to-end
- Use `testing/slow` build tag for integration tests (DNS timeouts)
- Mock DNS server for encoding/decoding tests (no real network needed)

## Threat Model Note

This transport uses DNS protocol for messaging. It is detectable by DPI
systems that inspect DNS query content and volume patterns. The
rate-limiting and padding are mitigations, not guarantees. If identified,
operators may need to rotate relay IPs and vary zone names. This residual
risk is inherent to the approach, not a bug in this implementation.
