# Phase 1: Message Timing & Ordering Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix message ordering so received messages display with relay-stamped timestamps and monotonic sequence numbers, replace millisecond-epoch IDs with collision-resistant UUIDs, and show sender nicknames instead of raw pubkeys.

**Architecture:** Relay stamps each message with `server_timestamp_ms` and a monotonic `sequence_number` when it stores the first chunk. These travel back to the client via an extended POLL response format. Flutter sorts by `(sequenceNumber, serverTimestamp)`. Sender attaches `client_timestamp_ms` for informational display.

**Tech Stack:** Go 1.26, protobuf, BoltDB (go.etcd.io/bbolt), Dart/Flutter, Riverpod, gRPC

## Global Constraints

- Go module: `github.com/user/dns-transport`
- Proto package: `relaypb`
- Flutter proto generated to: `flutter/lib/core/grpc/`
- Auth: gRPC metadata `x-auth-token` (local daemon only)
- Existing wire format: base32hex-encoded DNS labels, 63 chars max per label

---

## File Structure

### New files
| File | Purpose |
|------|---------|
| `go/internal/store/sequence.go` | BoltDB-backed monotonic sequence counter per recipient |

### Modified files
| File | Change |
|------|--------|
| `go/proto/relay.proto` | Add `server_timestamp_ms`, `sequence_number` to `ReceivedMessage`; add `client_timestamp_ms` to `SendRequest` |
| `go/internal/store/store.go` | Stamp `messageBuf` with timestamp + sequence on first chunk; add `GetMessageMeta()` |
| `go/internal/relay/server.go` | Initialize sequence counter; pass to store |
| `go/internal/client/dns_engine.go` | Parse extended POLL response (msgID + timestamp + sequence) |
| `go/internal/client/daemon.go` | Attach `client_timestamp_ms` on send; populate `server_timestamp_ms` + `sequence_number` on poll |
| `flutter/lib/features/chat/providers/chat_provider.dart` | UUID IDs, `sequenceNumber` field, sort by `(sequence, timestamp)` |
| `flutter/lib/features/chat/providers/message_list_provider.dart` | Use relay-stamped times, surface poll errors |
| `flutter/lib/features/chat/widgets/message_bubble.dart` | Nickname lookup for "from" label |
| `flutter/lib/features/peers/providers/peer_provider.dart` | Add `findByPubkey()` helper |

---

### Task 1: Proto changes

**Files:**
- Modify: `go/proto/relay.proto:62-84`
- Regenerate: `go/pkg/relaypb/relay.pb.go`, `go/pkg/relaypb/relay_grpc.pb.go`
- Regenerate: `flutter/lib/core/grpc/relay.pb.dart`, `flutter/lib/core/grpc/relay.pbgrpc.dart`

**Interfaces:**
- Consumes: nothing (first task)
- Produces: updated `SendRequest.client_timestamp_ms`, `ReceivedMessage.server_timestamp_ms`, `ReceivedMessage.sequence_number` available in generated code

- [ ] **Step 1: Update go/proto/relay.proto**

Add `client_timestamp_ms` to `SendRequest`:
```protobuf
message SendRequest {
  string peer_pubkey = 1;
  bytes plaintext = 2;
  uint64 client_timestamp_ms = 3;
}
```

Add `server_timestamp_ms` and `sequence_number` to `ReceivedMessage`:
```protobuf
message ReceivedMessage {
  string from_peer = 1;
  string message_id = 2;
  bytes plaintext = 3;
  int64 timestamp = 4;
  uint64 server_timestamp_ms = 5;
  uint64 sequence_number = 6;
}
```

- [ ] **Step 2: Regenerate Go protobuf**

Run from `go/` directory:
```bash
cd /c/Users/VaRgha/ZCodeProject/go
protoc --go_out=. --go_opt=paths=source_relative --go-grpc_out=. --go-grpc_opt=paths=source_relative proto/relay.proto
```

Verify `go/pkg/relaypb/relay.pb.go` contains `ServerTimestampMs` and `SequenceNumber` fields on `ReceivedMessage`, and `ClientTimestampMs` on `SendRequest`.

- [ ] **Step 3: Regenerate Flutter protobuf**

Run from `flutter/` directory (or copy the proto and use `protoc` with `--dart_out`):
```bash
cd /c/Users/VaRgha/ZCodeProject/flutter
protoc --dart_out=grpc:lib/core/grpc -I../go/proto ../go/proto/relay.proto
```

Verify `flutter/lib/core/grpc/relay.pb.dart` contains `serverTimestampMs`, `sequenceNumber`, `clientTimestampMs`.

- [ ] **Step 4: Commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
git add go/proto/relay.proto go/pkg/relaypb/ flutter/lib/core/grpc/relay.pb*.dart
git commit -m "proto: add server_timestamp_ms, sequence_number to ReceivedMessage; client_timestamp_ms to SendRequest"
```

---

### Task 2: Sequence counter (BoltDB-backed)

**Files:**
- Create: `go/internal/store/sequence.go`
- Create: `go/internal/store/sequence_test.go`

**Interfaces:**
- Consumes: nothing (standalone)
- Produces: `SequenceCounter.Next(peerID string) (uint64, error)`, `SequenceCounter.GetLast(peerID string) (uint64, error)`, `SequenceCounter.Close() error`

- [ ] **Step 1: Write the failing test**

Create `go/internal/store/sequence_test.go`:
```go
package store

import (
	"os"
	"path/filepath"
	"testing"
)

func TestSequenceCounter_Incrementing(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "seq.db")
	sc, err := NewSequenceCounter(dbPath)
	if err != nil {
		t.Fatalf("NewSequenceCounter: %v", err)
	}
	defer sc.Close()

	// First call for peer A should return 1
	seq, err := sc.Next("peerA")
	if err != nil {
		t.Fatalf("Next: %v", err)
	}
	if seq != 1 {
		t.Errorf("expected 1, got %d", seq)
	}

	// Second call for peer A should return 2
	seq, err = sc.Next("peerA")
	if err != nil {
		t.Fatalf("Next: %v", err)
	}
	if seq != 2 {
		t.Errorf("expected 2, got %d", seq)
	}

	// First call for peer B should return 1 (independent counter)
	seq, err = sc.Next("peerB")
	if err != nil {
		t.Fatalf("Next: %v", err)
	}
	if seq != 1 {
		t.Errorf("expected 1, got %d", seq)
	}
}

func TestSequenceCounter_Persistence(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "seq.db")

	// Write some sequences
	sc, _ := NewSequenceCounter(dbPath)
	sc.Next("peerA")
	sc.Next("peerA")
	sc.Next("peerA")
	sc.Close()

	// Reopen and verify continuation
	sc2, err := NewSequenceCounter(dbPath)
	if err != nil {
		t.Fatalf("NewSequenceCounter reopen: %v", err)
	}
	defer sc2.Close()

	seq, _ := sc2.Next("peerA")
	if seq != 4 {
		t.Errorf("expected 4 after reopen, got %d", seq)
	}
}

func TestSequenceCounter_GetLast(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "seq.db")
	sc, _ := NewSequenceCounter(dbPath)
	defer sc.Close()

	// GetLast on unknown peer returns 0
	seq, err := sc.GetLast("unknown")
	if err != nil {
		t.Fatalf("GetLast: %v", err)
	}
	if seq != 0 {
		t.Errorf("expected 0, got %d", seq)
	}

	sc.Next("peerA")
	sc.Next("peerA")

	seq, _ = sc.GetLast("peerA")
	if seq != 2 {
		t.Errorf("expected 2, got %d", seq)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /c/Users/VaRgha/ZCodeProject/go && go test ./internal/store/ -run TestSequenceCounter -v`
Expected: FAIL — `undefined: NewSequenceCounter`

- [ ] **Step 3: Add bbolt dependency**

```bash
cd /c/Users/VaRgha/ZCodeProject/go
go get go.etcd.io/bbolt@latest
```

- [ ] **Step 4: Implement sequence.go**

Create `go/internal/store/sequence.go`:
```go
package store

import (
	"encoding/binary"
	"fmt"
	"strconv"

	bolt "go.etcd.io/bbolt"
)

var sequenceBucket = []byte("sequences")

// SequenceCounter provides monotonic per-recipient sequence numbers,
// persisted to a BoltDB file. Survives process restarts.
type SequenceCounter struct {
	db *bolt.DB
}

// NewSequenceCounter opens (or creates) a BoltDB file for sequence tracking.
func NewSequenceCounter(dbPath string) (*SequenceCounter, error) {
	db, err := bolt.Open(dbPath, 0600, nil)
	if err != nil {
		return nil, fmt.Errorf("open sequence db: %w", err)
	}
	// Ensure bucket exists
	err = db.Update(func(tx *bolt.Tx) error {
		_, err := tx.CreateBucketIfNotExists(sequenceBucket)
		return err
	})
	if err != nil {
		db.Close()
		return nil, fmt.Errorf("create sequence bucket: %w", err)
	}
	return &SequenceCounter{db: db}, nil
}

// Next atomically increments and returns the next sequence number for peerID.
func (sc *SequenceCounter) Next(peerID string) (uint64, error) {
	var seq uint64
	err := sc.db.Update(func(tx *bolt.Tx) error {
		b := tx.Bucket(sequenceBucket)
		key := []byte(peerID)
		current := b.Get(key)
		if current != nil {
			seq = binary.BigEndian.Uint64(current)
		}
		seq++
		buf := make([]byte, 8)
		binary.BigEndian.PutUint64(buf, seq)
		return b.Put(key, buf)
	})
	return seq, err
}

// GetLast returns the current (most recent) sequence number for peerID.
// Returns 0 if no sequence has been assigned.
func (sc *SequenceCounter) GetLast(peerID string) (uint64, error) {
	var seq uint64
	err := sc.db.View(func(tx *bolt.Tx) error {
		b := tx.Bucket(sequenceBucket)
		val := b.Get([]byte(peerID))
		if val != nil {
			seq = binary.BigEndian.Uint64(val)
		}
		return nil
	})
	return seq, err
}

// Close closes the underlying BoltDB.
func (sc *SequenceCounter) Close() error {
	return sc.db.Close()
}

// peerIDFromPubkey derives a short peer ID string from a base64 pubkey
// for use as the sequence counter key.
func PeerIDFromPubkey(pubkey string) string {
	// Use first 8 chars of pubkey as stable short ID
	if len(pubkey) > 8 {
		return pubkey[:8]
	}
	return pubkey
}

// init ensures the strconv import is used (for future extensibility).
var _ = strconv.Itoa
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd /c/Users/VaRgha/ZCodeProject/go && go test ./internal/store/ -run TestSequenceCounter -v`
Expected: PASS (3 tests)

- [ ] **Step 6: Commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
git add go/internal/store/sequence.go go/internal/store/sequence_test.go go/go.sum go/go.mod
git commit -m "feat: add BoltDB-backed per-recipient sequence counter"
```

---

### Task 3: Store integration — stamp chunks with timestamp + sequence

**Files:**
- Modify: `go/internal/store/store.go:16-34,91-111`
- Modify: `go/internal/store/store_test.go` (create if missing)

**Interfaces:**
- Consumes: `SequenceCounter` from Task 2
- Produces: `ChunkStore` gains `SetSequenceCounter(sc *SequenceCounter)`, `GetMessageMeta(msgID [8]byte) (timestamp int64, sequence uint64, ok bool)`

- [ ] **Step 1: Write the failing test**

Create `go/internal/store/store_test.go`:
```go
package store

import (
	"path/filepath"
	"testing"
	"time"

	"github.com/user/dns-transport/internal/encoding"
)

func TestChunkStore_MessageMeta(t *testing.T) {
	dir := t.TempDir()
	sc, err := NewSequenceCounter(filepath.Join(dir, "seq.db"))
	if err != nil {
		t.Fatalf("NewSequenceCounter: %v", err)
	}
	defer sc.Close()

	store := NewChunkStore(0, 0) // no GC for test
	store.SetSequenceCounter(sc)

	// Create a test chunk
	var msgID [8]byte
	msgID[0] = 0x42
	chunk := encoding.NewChunk(msgID, 0, 1, []byte("hello"))

	before := time.Now().UnixMilli()
	_, err = store.Store(chunk)
	if err != nil {
		t.Fatalf("Store: %v", err)
	}
	after := time.Now().UnixMilli()

	// Get metadata
	ts, seq, ok := store.GetMessageMeta(msgID)
	if !ok {
		t.Fatal("GetMessageMeta: not found")
	}
	if ts < before || ts > after {
		t.Errorf("timestamp %d not in range [%d, %d]", ts, before, after)
	}
	if seq != 1 {
		t.Errorf("expected sequence 1, got %d", seq)
	}

	// Store another chunk for a different message
	var msgID2 [8]byte
	msgID2[0] = 0x99
	chunk2 := encoding.NewChunk(msgID2, 0, 1, []byte("world"))
	store.Store(chunk2)

	_, seq2, _ := store.GetMessageMeta(msgID2)
	if seq2 != 2 {
		t.Errorf("expected sequence 2 for second message, got %d", seq2)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /c/Users/VaRgha/ZCodeProject/go && go test ./internal/store/ -run TestChunkStore_MessageMeta -v`
Expected: FAIL — `store.SetSequenceCounter` undefined

- [ ] **Step 3: Modify store.go**

Add to `ChunkStore` struct (after line 33):
```go
sequenceCounter *SequenceCounter
```

Add new method after `SetMaxPerPeer`:
```go
// SetSequenceCounter attaches a BoltDB-backed sequence counter for timestamp/sequence stamping.
func (s *ChunkStore) SetSequenceCounter(sc *SequenceCounter) {
	s.sequenceCounter = sc
}
```

Modify `messageBuf` struct (line 16-20) to add:
```go
type messageBuf struct {
	chunks         map[uint16]*encoding.Chunk
	total          uint16
	createdAt      time.Time
	serverTimestamp int64  // relay-stamped UnixMilli
	sequenceNumber uint64 // monotonic per-recipient
}
```

Modify `Store()` method (line 91-111) — when creating a new `messageBuf`, stamp it:
```go
func (s *ChunkStore) Store(chunk *encoding.Chunk) (bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	buf, ok := s.messages[chunk.MsgID]
	if !ok {
		now := time.Now()
		buf = &messageBuf{
			chunks:         make(map[uint16]*encoding.Chunk),
			total:          chunk.TotalChunks,
			createdAt:      now,
			serverTimestamp: now.UnixMilli(),
		}
		// Stamp with sequence number if counter is available
		if s.sequenceCounter != nil && len(chunk.RecipientHash) > 0 {
			peerID := PeerIDFromPubkey(string(chunk.RecipientHash))
			seq, err := s.sequenceCounter.Next(peerID)
			if err == nil {
				buf.sequenceNumber = seq
			}
		}
		s.messages[chunk.MsgID] = buf
	}

	buf.chunks[chunk.ChunkIdx] = chunk

	if len(buf.chunks) == int(buf.total) {
		return true, nil
	}
	return false, nil
}
```

Add `GetMessageMeta` method:
```go
// GetMessageMeta returns the relay-stamped timestamp and sequence for a stored message.
func (s *ChunkStore) GetMessageMeta(msgID [8]byte) (timestamp int64, sequence uint64, ok bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	buf, exists := s.messages[msgID]
	if !exists {
		return 0, 0, false
	}
	return buf.serverTimestamp, buf.sequenceNumber, true
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /c/Users/VaRgha/ZCodeProject/go && go test ./internal/store/ -run TestChunkStore_MessageMeta -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
git add go/internal/store/store.go go/internal/store/store_test.go
git commit -m "feat: stamp chunks with server_timestamp_ms and sequence_number on store"
```

---

### Task 4: Relay — initialize sequence counter and pass metadata in POLL

**Files:**
- Modify: `go/internal/relay/server.go` (initialize sequence counter, pass to store)
- Modify: `go/internal/dns/dns.go` (return metadata in POLL response)
- Modify: `go/internal/dns/dns_test.go` (test extended POLL format)

**Interfaces:**
- Consumes: `SequenceCounter` from Task 2, `ChunkStore.SetSequenceCounter` from Task 3
- Produces: POLL DNS response includes `msgID:timestamp:sequence` TXT records; `QueryPollMetadata()` returns `[]PollMeta{MsgID, Timestamp, Sequence}`

- [ ] **Step 1: Write the failing test for extended POLL format**

Add to `go/internal/dns/dns_test.go`:
```go
func TestParsePollResponseExtended(t *testing.T) {
	// Simulate extended POLL response with metadata
	msgIDs := [][8]byte{{0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08}}
	timestamps := []uint64{1700000000000}
	sequences := []uint64{42}

	// Build TXT records in extended format: base32hex(msgID):base32hex(timestamp):base32hex(sequence)
	// This tests the parser, not the DNS layer

	meta, err := ParsePollMetadataExtended(msgIDs, timestamps, sequences)
	if err != nil {
		t.Fatalf("ParsePollMetadataExtended: %v", err)
	}
	if len(meta) != 1 {
		t.Fatalf("expected 1, got %d", len(meta))
	}
	if meta[0].Timestamp != 1700000000000 {
		t.Errorf("timestamp: expected 1700000000000, got %d", meta[0].Timestamp)
	}
	if meta[0].Sequence != 42 {
		t.Errorf("sequence: expected 42, got %d", meta[0].Sequence)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /c/Users/VaRgha/ZCodeProject/go && go test ./internal/dns/ -run TestParsePollMetadataExtended -v`
Expected: FAIL — `undefined: ParsePollMetadataExtended`

- [ ] **Step 3: Add PollMeta type and parser to dns.go**

Add to `go/internal/dns/dns.go`:
```go
// PollMeta holds metadata for a polled message.
type PollMeta struct {
	MsgID     [8]byte
	Timestamp int64
	Sequence  uint64
}

// ParsePollMetadataExtended parses extended POLL response metadata.
// If timestamps/sequences are provided, they are paired 1:1 with msgIDs.
func ParsePollMetadataExtended(msgIDs [][8]byte, timestamps []uint64, sequences []uint64) ([]PollMeta, error) {
	if len(timestamps) != len(msgIDs) || len(sequences) != len(msgIDs) {
		return nil, fmt.Errorf("length mismatch: %d msgIDs, %d timestamps, %d sequences",
			len(msgIDs), len(timestamps), len(sequences))
	}
	result := make([]PollMeta, len(msgIDs))
	for i := range msgIDs {
		result[i] = PollMeta{
			MsgID:     msgIDs[i],
			Timestamp: int64(timestamps[i]),
			Sequence:  sequences[i],
		}
	}
	return result, nil
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /c/Users/VaRgha/ZCodeProject/go && go test ./internal/dns/ -run TestParsePollMetadataExtended -v`
Expected: PASS

- [ ] **Step 5: Modify relay server.go to initialize sequence counter**

In `go/internal/relay/server.go`, find where `ChunkStore` is created and add:
```go
seqPath := filepath.Join(dbDir, "sequence.db")
seqCounter, err := store.NewSequenceCounter(seqPath)
if err != nil {
    slog.Warn("failed to open sequence counter, timestamps disabled", "error", err)
} else {
    chunkStore.SetSequenceCounter(seqCounter)
}
```

- [ ] **Step 6: Modify relay DNS handler to return metadata in POLL response**

In the relay's DNS handler for POLL queries, after calling `store.ListPeerMessages(peerID)`, also fetch metadata and encode it. The extended format appends `:timestamp:sequence` to each TXT record:

```go
// Extended POLL format: base32hex(msgID):base32hex(timestamp):base32hex(sequence)
// Backward compatible: old clients parse base32hex(msgID) and ignore the rest after ":"
for _, msgID := range msgIDs {
    ts, seq, ok := store.GetMessageMeta(msgID)
    if ok {
        txtRecord := fmt.Sprintf("%s:%s:%s",
            base32hex.EncodeToString(msgID[:]),
            base32hex.EncodeToString(binary.BigEndian.AppendUint64(nil, uint64(ts))),
            base32hex.EncodeToString(binary.BigEndian.AppendUint64(nil, seq)),
        )
        txt.Txt = append(txt.Txt, txtRecord)
    } else {
        txt.Txt = append(txt.Txt, base32hex.EncodeToString(msgID[:]))
    }
}
```

- [ ] **Step 7: Commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
git add go/internal/dns/dns.go go/internal/dns/dns_test.go go/internal/relay/server.go
git commit -m "feat: relay returns timestamp+sequence in extended POLL response"
```

---

### Task 5: Daemon — parse extended POLL response, populate ReceivedMessage metadata

**Files:**
- Modify: `go/internal/client/dns_engine.go:220-254,332-350,352-405`
- Modify: `go/internal/client/daemon.go:412-555`

**Interfaces:**
- Consumes: `dns.PollMeta` from Task 4
- Produces: `PolledMessage` gains `Timestamp int64` and `Sequence uint64` fields; `Daemon.PollMessages` populates `ReceivedMessage.ServerTimestampMs` and `ReceivedMessage.SequenceNumber`

- [ ] **Step 1: Extend PolledMessage struct**

In `go/internal/client/dns_engine.go`, modify `PolledMessage` (line 352-356):
```go
type PolledMessage struct {
	MsgID     [8]byte
	Data      []byte
	Timestamp int64  // relay-stamped UnixMilli
	Sequence  uint64 // monotonic per-recipient
}
```

- [ ] **Step 2: Update PollRelays to return metadata**

Modify `PollRelays` (line 220-254) to return `[]PolledMessage` instead of `[][8]byte`. Change the method signature and body:

```go
func (e *DNSClientEngine) PollRelays(recipientPubkey string) ([]PolledMessage, error) {
	if recipientPubkey == "" {
		return nil, nil
	}
	relays := e.discoverActiveRelays(nil)
	if len(relays) == 0 {
		e.debugWrite("PollRelays: no relays configured")
		return nil, nil
	}
	e.debugWrite("PollRelays: polling %d relays for %s", len(relays), recipientPubkey[:min(16, len(recipientPubkey))])

	hash := sha256.Sum256([]byte(recipientPubkey))
	peerID := base32hex.EncodeToString(hash[:])

	var allMsgs []PolledMessage
	seen := make(map[[8]byte]bool)

	for _, relay := range relays {
		msgs, err := e.pollRelayWithMeta(relay, peerID)
		if err != nil {
			slog.Warn("poll relay failed", "relay", relay, "error", err)
			continue
		}
		for _, m := range msgs {
			if !seen[m.MsgID] {
				seen[m.MsgID] = true
				allMsgs = append(allMsgs, m)
			}
		}
	}
	e.debugWrite("PollRelays: total unique msgIDs found=%d", len(allMsgs))
	return allMsgs, nil
}
```

Add `pollRelayWithMeta` method that parses extended POLL format:
```go
func (e *DNSClientEngine) pollRelayWithMeta(addr, peerID string) ([]PolledMessage, error) {
	resolved, err := e.resolveAddr(addr)
	if err != nil {
		return nil, fmt.Errorf("resolve %s: %w", addr, err)
	}

	queryLabels := []string{"POLL", peerID, e.zone}
	name := strings.Join(queryLabels, ".")

	m := new(mdns.Msg)
	m.SetQuestion(mdns.Fqdn(name), mdns.TypeTXT)
	m.RecursionDesired = false

	// Try TCP first, then UDP (same logic as pollRelay)
	var resp *mdns.Msg
	mode := e.GetTransportMode()
	switch mode {
	case dns.TransportTCP:
		tcpClient := &mdns.Client{Timeout: 5 * time.Second, Net: "tcp"}
		resp, _, err = tcpClient.Exchange(m, resolved)
	case dns.TransportUDP:
		udpClient := &mdns.Client{Timeout: 5 * time.Second, Net: "udp"}
		resp, _, err = udpClient.Exchange(m, resolved)
	default: // Auto
		tcpClient := &mdns.Client{Timeout: 5 * time.Second, Net: "tcp"}
		resp, _, err = tcpClient.Exchange(m, resolved)
		if err != nil || resp.Rcode != mdns.RcodeSuccess {
			udpClient := &mdns.Client{Timeout: 5 * time.Second, Net: "udp"}
			resp, _, err = udpClient.Exchange(m, resolved)
		}
	}
	if err != nil {
		return nil, err
	}
	if resp.Rcode != mdns.RcodeSuccess {
		return nil, fmt.Errorf("dns response code: %d", resp.Rcode)
	}

	return parsePollResponseWithMeta(resp), nil
}
```

Add parser that handles both old and extended formats:
```go
func parsePollResponseWithMeta(resp *mdns.Msg) []PolledMessage {
	var msgs []PolledMessage
	for _, ans := range resp.Answer {
		txt, ok := ans.(*mdns.TXT)
		if !ok {
			continue
		}
		for _, t := range txt.Txt {
			pm := parsePollRecord(t)
			if pm != nil {
				msgs = append(msgs, *pm)
			}
		}
	}
	return msgs
}

// parsePollRecord parses a single TXT record from a POLL response.
// Supports both old format (base32hex(msgID)) and extended format
// (base32hex(msgID):base32hex(timestamp):base32hex(sequence)).
func parsePollRecord(record string) *PolledMessage {
	// Split on ":" to detect extended format
	parts := strings.SplitN(record, ":", 3)

	idBytes, err := base32hex.DecodeString(parts[0])
	if err != nil || len(idBytes) != 8 {
		return nil
	}
	var mid [8]byte
	copy(mid[:], idBytes)

	pm := &PolledMessage{MsgID: mid}

	// Parse optional extended metadata
	if len(parts) == 3 {
		if tsBytes, err := base32hex.DecodeString(parts[1]); err == nil && len(tsBytes) == 8 {
			pm.Timestamp = int64(binary.BigEndian.Uint64(tsBytes))
		}
		if seqBytes, err := base32hex.DecodeString(parts[2]); err == nil && len(seqBytes) == 8 {
			pm.Sequence = binary.BigEndian.Uint64(seqBytes)
		}
	}

	return pm
}
```

Update `PollMessages` to use the new `PollRelays` return type:
```go
func (e *DNSClientEngine) PollMessages(recipientPubkey string) ([]PolledMessage, error) {
	polledMeta, err := e.PollRelays(recipientPubkey)
	if err != nil || len(polledMeta) == 0 {
		e.debugWrite("PollMessages: no msgIDs from relays count=%d err=%v", len(polledMeta), err)
		return nil, err
	}
	e.debugWrite("PollMessages: got %d msgIDs from relays", len(polledMeta))

	relays := e.discoverActiveRelays(nil)
	if len(relays) == 0 {
		return nil, fmt.Errorf("no relays to fetch from")
	}

	var messages []PolledMessage
	for _, pm := range polledMeta {
		// Skip already-fetched
		e.fetchedMu.Lock()
		if e.fetched[pm.MsgID] {
			e.fetchedMu.Unlock()
			continue
		}
		e.fetchedMu.Unlock()

		var data []byte
		var fetchErr error
		for _, relay := range relays {
			data, fetchErr = fetchAndReassemble(relay, e.zone, pm.MsgID, e.GetTransportMode())
			if fetchErr == nil {
				break
			}
			e.debugWrite("fetch from relay failed relay=%s msgID=%x err=%v", relay, pm.MsgID, fetchErr)
		}
		if fetchErr != nil {
			e.debugWrite("fetch message failed from all relays msgID=%x err=%v", pm.MsgID, fetchErr)
			continue
		}
		e.debugWrite("fetch message OK msgID=%x data_len=%d", pm.MsgID, len(data))

		e.fetchedMu.Lock()
		e.fetched[pm.MsgID] = true
		e.fetchedMu.Unlock()

		messages = append(messages, PolledMessage{
			MsgID:     pm.MsgID,
			Data:      data,
			Timestamp: pm.Timestamp,
			Sequence:  pm.Sequence,
		})
	}
	return messages, nil
}
```

- [ ] **Step 3: Update daemon.go PollMessages to populate metadata**

In `go/internal/client/daemon.go`, modify the `PollMessages` method (around line 555) to populate the new fields:

```go
		msgID := hex.EncodeToString(pm.MsgID[:])
		received := &pb.ReceivedMessage{
			MessageId: msgID,
			Plaintext: decrypted,
			FromPeer:  fromPeer,
		}
		// Populate relay-stamped metadata if available
		if pm.Timestamp > 0 {
			received.ServerTimestampMs = pm.Timestamp
		}
		if pm.Sequence > 0 {
			received.SequenceNumber = pm.Sequence
		}
		resp.Messages = append(resp.Messages, received)
```

- [ ] **Step 4: Update daemon.go SendMessage to attach client_timestamp_ms**

In `go/internal/client/daemon.go`, modify `SendMessage` (around line 312) to include the timestamp. The `SendRequest` already has `client_timestamp_ms` from the proto change. The daemon just needs to forward it — but currently Flutter doesn't send it. We'll set it server-side as a fallback:

In `SendMessage`, after building `signedPayload` (line 323), before encrypting, we can't easily inject `client_timestamp_ms` into the encrypted payload without changing the wire format. Instead, the approach is:

1. Flutter sends `client_timestamp_ms` in the `SendRequest`.
2. Daemon includes it as a header byte in the plaintext before signing.
3. Recipient extracts it after decryption.

**Simpler approach:** Include the timestamp in the signed payload. Modify `crypto.BuildSignedPayload` to accept an optional timestamp, or include it in the plaintext itself.

**Simplest approach for Phase 1:** The `client_timestamp_ms` is informational. We'll attach it to the proto but the actual display uses `server_timestamp_ms` from the relay. The sender's timestamp is a fallback for offline-queued messages. For now, Flutter sets it and daemon forwards it, but the relay stamp is authoritative.

In `daemon.go SendMessage`, the `SendRequest` already has `ClientTimestampMs`. No daemon change needed — it's already in the proto. Flutter just needs to set it when calling `sendMessage`.

- [ ] **Step 5: Verify Go compiles**

Run: `cd /c/Users/VaRgha/ZCodeProject/go && go build ./...`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
git add go/internal/client/dns_engine.go go/internal/client/daemon.go
git commit -m "feat: daemon parses extended POLL response with timestamp+sequence metadata"
```

---

### Task 7: Flutter — ChatMessage gains sequenceNumber, UUID IDs, sort by sequence

**Files:**
- Modify: `flutter/lib/features/chat/providers/chat_provider.dart:12-107,117-145,217-220`

**Interfaces:**
- Consumes: `ReceivedMessage.serverTimestampMs`, `ReceivedMessage.sequenceNumber` from proto
- Produces: `ChatMessage.sequenceNumber`, UUID-based `id`, sorted message list

- [ ] **Step 1: Add uuid dependency**

In `flutter/pubspec.yaml`, add under `dependencies`:
```yaml
  uuid: ^4.0.0
```

Run: `cd /c/Users/VaRgha/ZCodeProject/flutter && flutter pub get`

- [ ] **Step 2: Add sequenceNumber to ChatMessage**

In `flutter/lib/features/chat/providers/chat_provider.dart`, add field to `ChatMessage` class (after line 17):
```dart
  final int? sequenceNumber;
```

Add to constructor (after `localFilePath`):
```dart
    this.sequenceNumber,
```

Add to `copyWith` (after `localFilePath`):
```dart
    int? sequenceNumber,
```

Add to `copyWith` body:
```dart
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
```

Add to `toJson`:
```dart
    'sequenceNumber': sequenceNumber,
```

Add to `fromJson`:
```dart
    sequenceNumber: json['sequenceNumber'] as int?,
```

- [ ] **Step 3: Replace message IDs with UUIDs**

Add import at top:
```dart
import 'package:uuid/uuid.dart';
```

Add constant:
```dart
const _uuid = Uuid();
```

Replace the `sendMessage` method's ID generation (line 218):
```dart
    final msgId = _uuid.v4();
```

Replace `sendMediaProvider`'s ID generation (line 299):
```dart
  final msgId = _uuid.v4();
```

- [ ] **Step 4: Sort messages by (sequenceNumber, timestamp)**

Modify `addMessage` to insert in sorted order instead of appending:
```dart
  void addMessage(ChatMessage msg) {
    // Skip duplicates
    if (state.any((m) => m.id == msg.id)) return;
    final newList = [...state, msg];
    // Sort by sequenceNumber (nulls last), then by timestamp
    newList.sort((a, b) {
      final aSeq = a.sequenceNumber;
      final bSeq = b.sequenceNumber;
      if (aSeq != null && bSeq != null) {
        final cmp = aSeq.compareTo(bSeq);
        if (cmp != 0) return cmp;
      } else if (aSeq != null) {
        return -1; // sequenced messages first
      } else if (bSeq != null) {
        return 1;
      }
      return a.timestamp.compareTo(b.timestamp);
    });
    state = newList;
    _save();
  }
```

- [ ] **Step 5: Add serverTimestamp to ChatMessage**

Add `serverTimestamp` field to `ChatMessage` (for display, separate from `timestamp` which is the local receive time):
```dart
  final DateTime? serverTimestamp;
```

Add to constructor, copyWith, toJson, fromJson (same pattern as sequenceNumber).

In `fromJson`:
```dart
    serverTimestamp: json['serverTimestamp'] != null
        ? DateTime.parse(json['serverTimestamp'] as String)
        : null,
```

In `toJson`:
```dart
    'serverTimestamp': serverTimestamp?.toIso8601String(),
```

- [ ] **Step 6: Verify Flutter compiles**

Run: `cd /c/Users/VaRgha/ZCodeProject/flutter && flutter analyze lib/features/chat/providers/chat_provider.dart`
Expected: No errors

- [ ] **Step 7: Commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
git add flutter/pubspec.yaml flutter/pubspec.lock flutter/lib/features/chat/providers/chat_provider.dart
git commit -m "feat: ChatMessage gains sequenceNumber, UUID IDs, sorted by (sequence, timestamp)"
```

---

### Task 8: Flutter — message_list_provider uses relay-stamped times, surfaces errors

**Files:**
- Modify: `flutter/lib/features/chat/providers/message_list_provider.dart:11-30`

**Interfaces:**
- Consumes: `ReceivedMessage.serverTimestampMs`, `ReceivedMessage.sequenceNumber` from proto; `ChatMessage` with `sequenceNumber` and `serverTimestamp` from Task 7
- Produces: `pollMessagesProvider` uses relay timestamps, surfaces errors

- [ ] **Step 1: Update pollMessagesProvider to use relay metadata**

Replace the `pollMessagesProvider` (lines 11-30):
```dart
final pollMessagesProvider = StreamProvider<void>((ref) async* {
  while (true) {
    await Future.delayed(AppDurations.messagePollInterval);
    try {
      final client = GrpcClient();
      final resp = await client.stub.pollMessages(PollRequest());
      for (final msg in resp.messages) {
        // Use relay-stamped timestamp if available, else fall back to local time
        final serverTs = msg.hasServerTimestampMs() && msg.serverTimestampMs > 0
            ? DateTime.fromMillisecondsSinceEpoch(msg.serverTimestampMs.toInt())
            : DateTime.now();

        ref.read(chatProvider.notifier).addMessage(ChatMessage(
              id: msg.messageId,
              text: utf8.decode(msg.plaintext),
              timestamp: serverTs,
              serverTimestamp: msg.hasServerTimestampMs() && msg.serverTimestampMs > 0
                  ? DateTime.fromMillisecondsSinceEpoch(msg.serverTimestampMs.toInt())
                  : null,
              isSent: false,
              status: MessageStatus.received,
              fromPeer: msg.fromPeer,
              sequenceNumber: msg.hasSequenceNumber() && msg.sequenceNumber > 0
                  ? msg.sequenceNumber.toInt()
                  : null,
            ));
      }
    } catch (e) {
      // Log error for debugging; will retry on next poll
      debugPrint('[pollMessagesProvider] error: $e');
    }
    yield null;
  }
});
```

- [ ] **Step 2: Update receivedMediaProvider to include sender metadata**

Modify `receivedMediaProvider` to read `sender_pubkey` from the `.meta` sidecar (this will be written by Phase 4, but we can prepare the reader now):

In the media scan loop, after reading `.meta`:
```dart
        String? senderPubkey;
        if (await metaFile.exists()) {
          try {
            final meta = jsonDecode(await metaFile.readAsString());
            mimeType = meta['mime'] as String? ?? mimeType;
            filename = meta['filename'] as String? ?? filename;
            senderPubkey = meta['sender_pubkey'] as String?;
          } catch (_) {}
        }
```

And when creating the `ChatMessage`:
```dart
              fromPeer: senderPubkey, // will be null until Phase 4 writes this
```

- [ ] **Step 3: Verify Flutter compiles**

Run: `cd /c/Users/VaRgha/ZCodeProject/flutter && flutter analyze lib/features/chat/providers/message_list_provider.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
git add flutter/lib/features/chat/providers/message_list_provider.dart
git commit -m "feat: pollMessagesProvider uses relay-stamped timestamps, surfaces errors"
```

---

### Task 9: Flutter — message_bubble shows nickname instead of raw pubkey

**Files:**
- Modify: `flutter/lib/features/chat/widgets/message_bubble.dart:54-61`
- Modify: `flutter/lib/features/peers/providers/peer_provider.dart` (add helper)

**Interfaces:**
- Consumes: `ChatMessage.fromPeer` (base64 pubkey), `peerProvider` list
- Produces: Nickname display for received messages

- [ ] **Step 1: Add findByPubkey helper to peer_provider.dart**

In `flutter/lib/features/peers/providers/peer_provider.dart`, add to `PeerList` class:
```dart
  /// Find a peer's nickname by their public key.
  String? findNicknameByPubkey(String pubkey) {
    for (final peer in state) {
      if (peer.pubkey == pubkey) return peer.nickname;
    }
    return null;
  }
```

- [ ] **Step 2: Update message_bubble.dart to show nickname**

Modify `message_bubble.dart` to look up the nickname. Add import and provider reference:

At top of file, add:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/peers/providers/peer_provider.dart';
```

Change `MessageBubble` to accept `ref` or use `ConsumerWidget`:

Replace the class declaration and build method:
```dart
class MessageBubble extends ConsumerWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  IconData _statusIcon() {
    switch (message.status) {
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.queued:
        return Icons.access_time;
      case MessageStatus.failed:
        return Icons.error_outline;
      case MessageStatus.received:
        return Icons.check_circle_outline;
      case MessageStatus.sending:
        return Icons.hourglass_top;
    }
  }

  Color _statusColor() {
    switch (message.status) {
      case MessageStatus.sent:
        return Colors.grey;
      case MessageStatus.queued:
        return AppColors.queued;
      case MessageStatus.failed:
        return Colors.red;
      case MessageStatus.received:
        return AppColors.online;
      case MessageStatus.sending:
        return AppColors.queued;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgColor =
        message.isSent ? AppColors.sentBubble : AppColors.receivedBubble;
    final textColor = message.isSent ? Colors.white : Colors.black;
    final alignment =
        message.isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    // Resolve sender nickname from pubkey
    String? senderLabel;
    if (message.fromPeer != null) {
      final nickname = ref.read(peerProvider.notifier).findNicknameByPubkey(message.fromPeer!);
      senderLabel = nickname ?? message.fromPeer!.substring(0, min(16, message.fromPeer!.length));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (senderLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2, left: 8),
              child: Text(
                senderLabel,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          // ... rest of build method unchanged
```

Add `dart:math` import for `min`:
```dart
import 'dart:math' show min;
```

- [ ] **Step 3: Update any callers of MessageBubble**

Check `chat_screen.dart` for how `MessageBubble` is constructed. If it uses `const MessageBubble(...)`, the `ConsumerWidget` change requires removing `const` or adjusting. Verify the file compiles.

- [ ] **Step 4: Verify Flutter compiles**

Run: `cd /c/Users/VaRgha/ZCodeProject/flutter && flutter analyze lib/features/chat/widgets/message_bubble.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
git add flutter/lib/features/chat/widgets/message_bubble.dart flutter/lib/features/peers/providers/peer_provider.dart
git commit -m "feat: message bubble shows sender nickname instead of raw pubkey"
```

---

### Task 10: Update message bubble timestamp display to use serverTimestamp

**Files:**
- Modify: `flutter/lib/features/chat/widgets/message_bubble.dart`

**Interfaces:**
- Consumes: `ChatMessage.serverTimestamp` from Task 7
- Produces: Display server timestamp in bubble, local timestamp as fallback

- [ ] **Step 1: Show server timestamp in message bubble**

In `message_bubble.dart`, modify the timestamp display (around line 82):
```dart
                    Text(
                      DateFormat('HH:mm').format(
                          message.serverTimestamp ?? message.timestamp),
                      style: TextStyle(
                          fontSize: 10, color: textColor.withAlpha(150)),
                    ),
```

- [ ] **Step 2: Commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
git add flutter/lib/features/chat/widgets/message_bubble.dart
git commit -m "feat: message bubble displays relay-stamped server timestamp"
```

---

### Task 11: Sync Flutter proto source and verify full build

**Files:**
- Modify: `flutter/proto/relay.proto` (sync with Go proto)

**Interfaces:**
- Consumes: all previous tasks
- Produces: Flutter proto source matches Go proto; full build passes

- [ ] **Step 1: Copy go/proto/relay.proto to flutter/proto/relay.proto**

```bash
cp /c/Users/VaRgha/ZCodeProject/go/proto/relay.proto /c/Users/VaRgha/ZCodeProject/flutter/proto/relay.proto
```

- [ ] **Step 2: Verify Go builds**

Run: `cd /c/Users/VaRgha/ZCodeProject/go && go build ./...`
Expected: No errors

- [ ] **Step 3: Verify Flutter analyzes**

Run: `cd /c/Users/VaRgha/ZCodeProject/flutter && flutter analyze`
Expected: No errors (or only pre-existing warnings)

- [ ] **Step 4: Run Go tests**

Run: `cd /c/Users/VaRgha/ZCodeProject/go && go test ./internal/store/ ./internal/dns/ -v`
Expected: All tests pass

- [ ] **Step 5: Final commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
git add flutter/proto/relay.proto
git commit -m "chore: sync flutter proto with go proto (Phase 1 timing fields)"
```

---

## Verification Checklist

After completing all tasks:

- [ ] Go builds: `cd go && go build ./...`
- [ ] Go tests pass: `cd go && go test ./...`
- [ ] Flutter analyzes: `cd flutter && flutter analyze`
- [ ] Proto fields present: `ReceivedMessage` has `server_timestamp_ms`, `sequence_number`; `SendRequest` has `client_timestamp_ms`
- [ ] Sequence counter persists: write → close → reopen → next continues from last value
- [ ] Store stamps chunks: `GetMessageMeta` returns valid timestamp and sequence
- [ ] Daemon populates metadata: `PollMessages` returns `ReceivedMessage` with non-zero `server_timestamp_ms` and `sequence_number`
- [ ] Flutter sorts by sequence: messages display in monotonic order
- [ ] Flutter shows nickname: received messages show "Alice" not "base64pubkey..."
- [ ] Flutter shows server timestamp: bubbles display relay time, not local receive time
- [ ] UUID IDs: no two messages share the same `id`
