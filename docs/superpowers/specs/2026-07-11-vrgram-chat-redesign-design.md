# VRGram Chat Redesign — Design Spec

**Date:** 2026-07-11
**Status:** Approved
**Scope:** Chat peer model, invite codes, group chat, media rewrite, message timing/ordering

---

## Context

VRGram is a censorship-resilient P2P messaging app over DNS transport with decentralized relay discovery. The Flutter frontend talks to a local Go daemon (`relayd`) over gRPC. Current limitations:

- Both sides must manually exchange X25519 public keys (copy/paste full base64).
- No group chat — peer model, crypto (pairwise ECDH), relay indexing (`RecipientHash`), and proto are all 1:1.
- Media sending has real bugs: status reports complete before chunks are uploaded, sender attribution lost on receive, zero time estimates, entire file loaded into one gRPC message.
- Message ordering is by poll-arrival time, not send-time — `PollMessages` never sets `Timestamp`. Message IDs are `millisecondsSinceEpoch` (collision risk).
- Adding a peer through the UI doesn't push it to the daemon (gRPC `addPeer` unused by the screen). Daemon only learns peers at startup.

This redesign addresses all of the above in 4 independently-shippable phases.

---

## Phase 1: Message Timing & Ordering Fix

### Problem

- `PollMessages` never sets `ReceivedMessage.timestamp`. Received messages show poll-arrival time.
- Message IDs are `DateTime.now().millisecondsSinceEpoch.toString()` — collision risk.
- Message ordering is by insertion into flat list, not by authoritative time.
- `message_bubble.dart` shows raw base64 pubkey as "from" label.

### Design

#### Relay-stamped timestamps

- Relay maintains a monotonic `uint64` counter per-recipient, persisted to a BoltDB file (`sequence.db`) alongside the in-memory `ChunkStore`.
- When `ChunkStore.Store()` receives a chunk, it stamps it with `time.Now().UnixMilli()` as `server_timestamp_ms` and increments the per-recipient sequence counter.
- Sequence counter survives relay restarts via BoltDB persistence.

#### Proto changes

Add to `ReceivedMessage`:
```protobuf
uint64 server_timestamp_ms = 5;
uint64 sequence_number = 6;
```

Add to `SendRequest`:
```protobuf
uint64 client_timestamp_ms = 3; // sender's clock, informational
```

#### Daemon changes

- `SendMessage`: attach `client_timestamp_ms` to outgoing request.
- `PollMessages`: return `server_timestamp_ms` and `sequence_number` from relay. The relay already provides these via the `Chunk` metadata.

#### Flutter changes

- `ChatMessage` gains `sequenceNumber` (int).
- Sort messages by `(sequenceNumber, serverTimestamp)` — primary by sequence, tie-break by timestamp.
- `pollMessagesProvider` uses relay-stamped times instead of `DateTime.now()`.
- `receivedMediaProvider` includes `sequenceNumber` from the `.meta` sidecar.

#### Message IDs

Change from `DateTime.now().millisecondsSinceEpoch.toString()` to random hex (crypto/rand on Go side, `dart:crypto` random on Flutter side). Format: 32-char hex string (128 bits, collision-resistant).

#### "From" label fix

`message_bubble.dart`: look up `fromPeer` pubkey in `peerProvider` list to show nickname instead of raw base64.

#### Error visibility

`pollMessagesProvider` currently swallows all exceptions (`catch (_) {}`). Change to log errors and surface a connection-lost indicator in the UI.

### Bugs fixed

1. `PollMessages` never sets `Timestamp`
2. Message ID collision risk
3. Received messages show arrival time, not send time
4. Raw pubkey shown in "from" label
5. `pollMessagesProvider` swallowing all errors silently

### Files touched

| File | Change |
|------|--------|
| `go/proto/relay.proto` | Add `server_timestamp_ms`, `sequence_number` to `ReceivedMessage`; add `client_timestamp_ms` to `SendRequest` |
| `go/internal/client/daemon.go` | Attach timestamp to send, return relay-stamped times on poll |
| `go/internal/client/dns_engine.go` | Thread relay metadata through |
| `go/internal/store/store.go` | Stamp chunks with timestamp + sequence on store |
| `go/internal/store/sequence.go` | **New** — BoltDB-backed per-recipient sequence counter |
| `flutter/lib/features/chat/providers/chat_provider.dart` | `ChatMessage.sequenceNumber`, UUID IDs, sort by sequence |
| `flutter/lib/features/chat/providers/message_list_provider.dart` | Use relay-stamped times, surface poll errors |
| `flutter/lib/features/chat/widgets/message_bubble.dart` | Nickname lookup for "from" label |
| `flutter/lib/main.dart` | Remove `_syncPeers` (prep for Phase 2, daemon becomes peer authority) |

---

## Phase 2: One-Way Invite + Auto-Sync Peer Model

### Problem

- Both sides must manually exchange X25519 public keys.
- No in-app invite/flow — entirely out-of-band.
- Adding a peer through the UI doesn't push to the daemon.
- No `RemovePeer` RPC. Daemon peer map keyed by nickname (collision risk).

### Design

#### Invite code format

```
v1:<base32(pubkey_32bytes)>:<base32(nonce_8bytes)>
```

- Total ~70 chars. Copy/paste friendly.
- Nonce prevents the code from being the raw pubkey (privacy tag, not authentication).
- Pubkey is encoded in the code itself — no relay lookup needed. Works offline.

#### One-way invite flow

1. **Alice** taps "Generate Invite Code". Flutter calls `gRPC GenerateInviteCode{nickname}`.
2. Daemon creates the code: `v1:<base32(alice_pub)>:<base32(nonce_8)>`. Stores the nonce in-memory with 24h TTL (pending hellos).
3. **Alice** shares the code with Bob (copy, text, etc.).
4. **Bob** enters the code in "Join via Invite Code" dialog. Flutter calls `gRPC JoinViaCode{code}`.
5. Bob's daemon parses the code, extracts `alice_pub`, `nickname`. Adds Alice as a peer.
6. Bob's daemon derives `hello_key = HKDF(nonce, "vrgram-hello")` from the invite nonce. Encrypts hello with `hello_key` using XChaCha20. Plaintext: `{"type":"hello","pubkey":"<bob_pub_base64>","nickname":"<bob_nickname>"}`. Sends via relay addressed to Alice's recipient hash.

**Why not ECDH?** Bob can compute `ECDH(bob_priv, alice_pub)`, but Alice can't compute `ECDH(alice_priv, bob_pub)` — she doesn't have bob_pub yet (it's inside the hello). The invite nonce serves as a pre-shared key for this one initial message. After Alice extracts bob_pub from the hello, all subsequent messages use normal ECDH.

7. **Alice** polls, receives Bob's hello. `PollMessages` tries to decrypt with `hello_key` derived from each of her active invite nonces. Decryption succeeds. Extracts Bob's pubkey + nickname. Adds Bob as a peer. Optionally shows notification: "Bob wants to chat." Removes the nonce from pending (used once).

#### RemovePeer RPC

New gRPC RPC `RemovePeer{pubkey}`. Daemon removes from peer map. Flutter removes from local `peers.json` cache.

#### Daemon as peer authority

- Peer map in daemon keyed by **pubkey** (not nickname) to prevent collision.
- `peers.json` in Flutter becomes a local cache for UI only.
- Remove `_syncPeers()` from `main.dart` — daemon owns the source of truth.
- UI `addPeer` calls gRPC `AddPeer` (wire up the unused `addPeerProvider`).

#### Remove nickname-collision risk

Two peers with different nicknames but the same pubkey = impossible (same identity). Two peers with different pubkeys but the same nickname = allowed (pubkey is the key, nickname is display). Daemon maps `pubkey → PeerInfo{nickname}`.

### Files touched

| File | Change |
|------|--------|
| `go/proto/relay.proto` | New RPCs: `GenerateInviteCode`, `JoinViaCode`, `RemovePeer` |
| `go/internal/client/daemon.go` | Invite logic, peer-keyed map, hello auto-add, RemovePeer |
| `flutter/lib/main.dart` | Remove `_syncPeers()`, remove `_syncRelays()` (daemon owns both) |
| `flutter/lib/features/peers/providers/peer_provider.dart` | Use pubkey-keyed map, gRPC calls for add/remove |
| `flutter/lib/features/peers/screens/add_peer_dialog.dart` | Add "Join via Invite Code" option |
| `flutter/lib/features/peers/screens/peer_list_screen.dart` | Wire up `addPeerProvider` gRPC call |
| `flutter/lib/features/peers/screens/invite_code_screen.dart` | **New** — generate + share invite code, enter received code |
| `flutter/lib/core/grpc/relay.proto` | Sync with Go proto (currently stale) |

---

## Phase 3: Group Chat with Group Key Ratchet

### Problem

- No group chat support anywhere.
- Peer model, crypto (pairwise ECDH), relay indexing (`RecipientHash`), proto (`peer_pubkey`) are all 1:1.

### Design

#### Data model

```protobuf
message GroupInfo {
  string group_id = 1;
  string name = 2;
  string admin_pubkey = 3;
  repeated GroupMember members = 4;
  uint64 key_epoch = 5;
}

message GroupMember {
  string pubkey = 1;
  string nickname = 2;
  string role = 3; // "admin" | "member"
}
```

Flutter: `Group { id, name, adminPubkey, members[], groupKey (bytes), keyEpoch }`. Persisted as `groups.json`.

#### Group creation flow

1. Creator taps "New Group", enters name, picks members from peer list.
2. Flutter calls `gRPC CreateGroup{name, member_pubkeys[]}`.
3. Daemon:
   - Generates `group_id` (UUID), `group_key` (random 32 bytes).
   - For each member, encrypts `group_key` with ECDH(member_pub, creator_priv) and sends a "group-key-distribution" message.
   - Stores group locally with `key_epoch = 1`.
4. Members receive group key distribution, decrypt, store group + key.

#### Message encryption (fan-out with group key)

- Group message plaintext → encrypt with `group_key` using XChaCha20-Poly1305.
- Send encrypted message to **each member** as a separate `SendMessage` with `group_id` field.
- Each member polls, receives message addressed to them, tagged with `group_id`. Decrypts with their copy of `group_key`.

#### Key rotation (epoch-based)

- When a member leaves (or is removed by admin), admin generates new `group_key`, re-distributes to remaining members, increments `key_epoch`.
- Each message carries `key_epoch`. Receiver ignores messages from older epochs.
- No per-message ratchet — epoch-level rotation on membership change.

#### Group invite

- Admin generates group invite code: `group_v1:<base32(group_id)>:<base32(encrypted_group_key_for_recipient)>`.
- Recipient enters code → daemon decrypts group key → adds to local group list → sends "member joined" notification to admin.

#### Relay-side changes

- `SendRequest` gets `optional string group_id`. If present, relay indexes message under ALL members' recipient hashes (fan-out at relay level).
- New `AddGroupMember` / `RemoveGroupMember` RPCs.
- Relay stores group membership metadata.

#### UI

- `group_list_screen.dart` — list of groups.
- `group_chat_screen.dart` — similar to `chat_screen.dart`, member list drawer, admin controls.
- `create_group_dialog.dart` — name + member picker.

### Files touched

| File | Change |
|------|--------|
| `go/proto/relay.proto` | `GroupInfo`, `GroupMember`, new RPCs: `CreateGroup`, `JoinGroup`, `LeaveGroup`, `RemoveGroupMember`, `ListGroupMessages` |
| `go/internal/client/daemon.go` | Group CRUD, fan-out send, key distribution, member management |
| `go/internal/store/store.go` | Group message indexing (multi-recipient) |
| `go/internal/crypto/group.go` | **New** — group key encryption, rotation, epoch validation |
| `flutter/lib/features/group/providers/group_provider.dart` | **New** — `Group`, `GroupList`, group CRUD |
| `flutter/lib/features/group/screens/group_chat_screen.dart` | **New** — group chat UI |
| `flutter/lib/features/group/screens/create_group_dialog.dart` | **New** — group creation |
| `flutter/lib/features/group/screens/group_list_screen.dart` | **New** — group list |
| `flutter/lib/features/chat/screens/chat_list_screen.dart` | Add groups section |

---

## Phase 4: Full Media Rewrite

### Problem

- `SendMedia` reports COMPLETE before chunks are uploaded.
- Sender attribution lost (`.meta` sidecar lacks sender).
- Entire file loaded into one gRPC message (no streaming).
- Sequential chunk sending (~3s each), 60KB DNS cap.
- No resume. No relay persistence (in-memory only).
- `estimatedSeconds` computes to ~0.
- Voice recording is fake (file picker, not recorder).

### Design

#### Streaming gRPC upload

Replace single `SendMediaRequest{media_data}` with a client-streaming RPC:
```protobuf
rpc SendMediaStream(stream MediaUploadChunk) returns (SendMediaResponse);
message MediaUploadChunk {
  string transfer_id = 1;
  bytes data = 2;
  uint32 chunk_index = 3;
}
```

Flutter sends file chunks over gRPC stream (chunk size: 256KB). Daemon assembles in temp file, then encrypts. Eliminates 10MB in-memory load and `MaxRecvMsgSize(100MB)` hack.

#### Transfer state machine

States: `QUEUED → ENCRYPTING → UPLOADING → CONFIRMING → COMPLETE | FAILED`

- `GetMediaStatus` returns real progress: `progress_pct = (chunks_sent / total_chunks) * 100`.
- Transfer ID returned immediately. Poll `GetMediaStatus` for real progress.
- `estimatedSeconds = (remaining_chunks * avg_chunk_time)` using rolling average.

#### TCP-primary, DNS-fallback

- Files >128KB: TCP (HTTP) relay upload by default. Sub-second transfers.
- Files <128KB: DNS transport (parallel chunk sending with `parallelism=15`).
- `MaxDNSChunkSize` bumped to configurable 32-200 bytes (existing UI slider).
- `MediaMaxHardCap = 50 * 1024 * 1024` (50MB, match relay `maxUploadSize`).

#### Resume

- Daemon tracks transfer chunks in SQLite. If daemon restarts mid-transfer, resumes from last confirmed chunk.
- Receiver side: `fetchAndReassemble` parallelized — fetch all chunks concurrently (respecting 15-goroutine pool).

#### Relay persistence

- `ChunkStore` backed by BoltDB instead of pure in-memory.
- Chunks stored with TTL (7 days). `ListPeerMessages` indexed with hash map (not linear scan).
- Media files stored to disk immediately (already does for TCP — extend to DNS chunks).

#### Sender attribution

- `MediaMessage` JSON includes `sender_pubkey`.
- Receiver's `.meta` sidecar includes `sender_pubkey`.
- `receivedMediaProvider` reads it and sets `fromPeer`.

#### Voice recording

- Replace fake `FilePicker.pickFiles` with actual audio recording via `record` package.
- Mic → m4a → send as media.
- Playback via `audioplayers` package in `media_bubble.dart`.

#### Constants

| Constant | Current | New |
|----------|---------|-----|
| `MaxDNSChunkSize` | 1000 | Configurable 32-200 (default 200) |
| `MediaDNSSizeThreshold` | 60KB | 128KB |
| `MediaMaxHardCap` | 10MB | 50MB |
| gRPC stream chunk | N/A (single message) | 256KB |
| Max upload size | 10MB (Flutter) | 50MB (match relay) |

### Files touched

| File | Change |
|------|--------|
| `go/proto/relay.proto` | Streaming `SendMediaStream` RPC, updated `MediaMessage` with `sender_pubkey` |
| `go/internal/client/daemon.go` | Streaming receive, state machine, resume, sender attribution |
| `go/internal/media/dns_transport.go` | Parallel chunk sending, TCP-primary logic |
| `go/internal/client/dns_engine.go` | Parallel fetch, receiver-side parallelism |
| `go/internal/store/store.go` | BoltDB persistence, hash-map index |
| `go/internal/relay/server.go` | BoltDB media persistence, group indexing |
| `go/internal/media/types.go` | Updated `MediaMessage` schema |
| `go/internal/media/transfer.go` | **New** — transfer state machine + resume logic |
| `flutter/lib/core/media/media_service.dart` | Streaming upload, real progress tracking |
| `flutter/lib/features/chat/providers/chat_provider.dart` | Real media status tracking |
| `flutter/lib/features/chat/widgets/media_bubble.dart` | Sender label, voice playback |
| `flutter/lib/features/chat/providers/message_list_provider.dart` | Sender attribution from sidecar |
| `flutter/lib/features/chat/screens/chat_input.dart` | Voice recording integration |

---

## Cross-cutting concerns

### Proto sync

`flutter/proto/relay.proto` is currently stale (missing media/transport RPCs). Phase 2 will sync it. All future phases regenerate from the single `go/proto/relay.proto` source of truth.

### Auth

Existing gRPC auth (local token file, `x-auth-token` metadata) is unchanged. New RPCs use the same interceptor.

### Persistence locations

| Data | Location | Authority |
|------|----------|-----------|
| Identity key | `dataDir/identity.key` | Daemon |
| Auth token | `dataDir/auth_token` | Daemon |
| Peers | `dataDir/peers.json` (daemon), `appDataDir/peers.json` (Flutter cache) | Daemon |
| Messages | `appDataDir/messages.json` | Flutter |
| Groups | `dataDir/groups.json` (daemon), `appDataDir/groups.json` (Flutter cache) | Daemon |
| Media transfers | `dataDir/transfers.db` (SQLite) | Daemon |
| Relay chunks | `dbPath/chunks.db` (BoltDB) | Relay |
| Relay sequence | `dbPath/sequence.db` (BoltDB) | Relay |

### Testing strategy

- Phase 1: Unit tests for sequence counter, timestamp attachment, UUID generation. Integration test for poll→display flow.
- Phase 2: Unit tests for invite code encode/decode, hello message auto-add. Integration test for full invite flow (generate→share→join→auto-add).
- Phase 3: Unit tests for group key encryption/rotation, epoch validation. Integration test for create→add member→send→receive→rotate.
- Phase 4: Unit tests for transfer state machine, resume logic, chunk parallelism. Integration test for streaming upload→relay store→receiver reassemble.

### Risk areas

1. **Group key ratchet** — most complex new code. Key distribution must be reliable; losing a group key means losing all group history. Mitigate: persist group keys to disk immediately, retry distribution on failure.
2. **Streaming gRPC** — Flutter gRPC streaming requires careful lifecycle management (cancel on app background, resume on foreground). Mitigate: daemon-side resume from SQLite.
3. **BoltDB migration** — replacing in-memory `ChunkStore` with BoltDB. Mitigate: same interface, just persistent backend. Test TTL GC still works.
4. **Relay sequence counter** — must be monotonic and survive restarts. BoltDB transaction guarantees atomicity. Mitigate: test crash-during-write scenarios.
