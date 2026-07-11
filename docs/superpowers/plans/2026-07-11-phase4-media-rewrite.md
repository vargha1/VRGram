# Phase 4: Full Media Rewrite — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Streaming gRPC upload, real transfer state machine, TCP-primary DNS-fallback, resume, relay persistence, sender attribution, voice recording.

**Architecture:** Client-streaming gRPC (`SendMediaStream`) replaces the single `SendMediaRequest`. Daemon tracks transfers via SQLite for resume. Relay chunks stored in BoltDB. Media >128KB uses TCP (HTTP). Voice uses `record` package.

**Tech Stack:** Go 1.26, protobuf, gRPC streaming, SQLite (go-sqlite3), BoltDB, Flutter/Riverpod, record/audioplayers

## Global Constraints
- Go module: `github.com/user/dns-transport`
- Flutter gRPC streaming via `grpc-dart`
- `MediaMaxHardCap = 50 * 1024 * 1024` (50MB)
- `MediaDNSSizeThreshold = 128 * 1024` (128KB)
- gRPC stream chunk size: 256KB

---

## File Structure

### New files
| File | Purpose |
|------|---------|
| `go/internal/media/transfer.go` | Transfer state machine, SQLite resume |

### Modified files
| File | Change |
|------|--------|
| `go/proto/relay.proto` | Streaming RPC `SendMediaStream`, `MediaUploadChunk` message, `MediaMessage.sender_pubkey` |
| `go/internal/client/daemon.go` | Streaming `SendMediaStream` handler, real state machine, resume, sender attribution in meta |
| `go/internal/media/dns_transport.go` | Parallel DNS chunk send, updated constants |
| `go/internal/media/types.go` | Updated `MediaMessage` with `sender_pubkey` |
| `go/internal/client/dns_engine.go` | Parallel `fetchAndReassemble` for receiver |
| `go/internal/media/dns_transport.go` | TCP-primary logic |
| `flutter/lib/core/media/media_service.dart` | Streaming upload, real progress |
| `flutter/lib/features/chat/providers/chat_provider.dart` | Real `GetMediaStatus` tracking |
| `flutter/lib/features/chat/screens/chat_input.dart` | Voice recording integration |
| `flutter/pubspec.yaml` | Add `record` and `audioplayers` packages |

---

### Task 1: Proto — streaming RPC + sender_pubkey

**Files:**
- Modify: `go/proto/relay.proto`

Add to `service RelayClient`:
```protobuf
rpc SendMediaStream(stream MediaUploadChunk) returns (SendMediaResponse);
```

Add after `CancelSendRequest`:
```protobuf
message MediaUploadChunk {
  string transfer_id = 1;
  bytes data = 2;
  uint32 chunk_index = 3;
}
```

Add `string sender_pubkey = 6;` to `MediaMessage` (in `types.go`, not proto — it's JSON).

Then regenerate:
```bash
cd /c/Users/VaRgha/ZCodeProject/go && rm -f pkg/relaypb/*.go proto/*.go
/c/Users/VaRgha/.local/bin/protoc --go_out=pkg/relaypb --go_opt=paths=source_relative --go-grpc_out=pkg/relaypb --go-grpc_opt=paths=source_relative -I. proto/relay.proto
cp pkg/relaypb/proto/*.go pkg/relaypb/ && rm -rf pkg/relaypb/proto
cd /c/Users/VaRgha/ZCodeProject/flutter && cp ../go/proto/relay.proto proto/relay.proto
/c/Users/VaRgha/.local/bin/protoc --dart_out=grpc:lib/core/grpc -Iproto --plugin=protoc-gen-dart="C:/Users/VaRgha/AppData/Local/Pub/Cache/bin/protoc-gen-dart.bat" proto/relay.proto
```

Commit: `git add go/proto/relay.proto go/pkg/relaypb/ flutter/ && git commit -m "proto: add SendMediaStream streaming RPC"`

---

### Task 2: Go — transfer state machine + SQLite resume

**Files:**
- Create: `go/internal/media/transfer.go`
- Create: `go/internal/media/transfer_test.go`

Implementation of `TransferState` with SQLite persistence for resume.

```go
package media

import (
    "database/sql"
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"
    "sync"
    "time"
    _ "github.com/mattn/go-sqlite3"
)

type TransferStatus int32
const (
    TransferQueued    TransferStatus = 0
    TransferEncrypting TransferStatus = 1
    TransferUploading  TransferStatus = 2
    TransferConfirming TransferStatus = 3
    TransferComplete   TransferStatus = 4
    TransferFailed     TransferStatus = 5
    TransferCancelled  TransferStatus = 6
)

type TransferEntry struct {
    ID           string         `json:"id"`
    PeerPubkey   string         `json:"peer_pubkey"`
    FileName     string         `json:"file_name"`
    MimeType     string         `json:"mime_type"`
    FileSize     int64          `json:"file_size"`
    Status       TransferStatus `json:"status"`
    Progress     int32          `json:"progress"`
    ChunksSent   int32          `json:"chunks_sent"`
    TotalChunks  int32          `json:"total_chunks"`
    AvgChunkTime int64          `json:"avg_chunk_time_ms"`
    Error        string         `json:"error"`
    CreatedAt    int64          `json:"created_at"`
    TempFilePath string         `json:"temp_file_path"`
}

type TransferStore struct {
    db *sql.DB
    mu sync.Mutex
}

func NewTransferStore(dbPath string) (*TransferStore, error) {
    os.MkdirAll(filepath.Dir(dbPath), 0700)
    db, err := sql.Open("sqlite3", dbPath)
    if err != nil { return nil, err }
    _, err = db.Exec(`CREATE TABLE IF NOT EXISTS transfers (
        id TEXT PRIMARY KEY,
        peer_pubkey TEXT, file_name TEXT, mime_type TEXT,
        file_size INTEGER, status INTEGER, progress INTEGER,
        chunks_sent INTEGER, total_chunks INTEGER,
        avg_chunk_time_ms INTEGER, error TEXT,
        created_at INTEGER, temp_file_path TEXT
    )`)
    if err != nil { return nil, err }
    return &TransferStore{db: db}, nil
}

func (s *TransferStore) Create(entry *TransferEntry) error {
    s.mu.Lock(); defer s.mu.Unlock()
    _, err := s.db.Exec(`INSERT INTO transfers VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`,
        entry.ID, entry.PeerPubkey, entry.FileName, entry.MimeType,
        entry.FileSize, int(entry.Status), entry.Progress,
        entry.ChunksSent, entry.TotalChunks, entry.AvgChunkTime,
        entry.Error, entry.CreatedAt, entry.TempFilePath)
    return err
}

func (s *TransferStore) Update(id string, status TransferStatus, progress int32, chunksSent int32) error {
    s.mu.Lock(); defer s.mu.Unlock()
    _, err := s.db.Exec(`UPDATE transfers SET status=?, progress=?, chunks_sent=? WHERE id=?`,
        int(status), progress, chunksSent, id)
    return err
}

func (s *TransferStore) Get(id string) (*TransferEntry, error) {
    row := s.db.QueryRow(`SELECT * FROM transfers WHERE id=?`, id)
    e := &TransferEntry{}
    err := row.Scan(&e.ID, &e.PeerPubkey, &e.FileName, &e.MimeType, &e.FileSize,
        &e.Status, &e.Progress, &e.ChunksSent, &e.TotalChunks,
        &e.AvgChunkTime, &e.Error, &e.CreatedAt, &e.TempFilePath)
    if err == sql.ErrNoRows { return nil, nil }
    return e, err
}

func (s *TransferStore) ListPending() ([]*TransferEntry, error) {
    rows, err := s.db.Query(`SELECT * FROM transfers WHERE status IN (0,1,2) ORDER BY created_at`)
    if err != nil { return nil, err }
    defer rows.Close()
    var entries []*TransferEntry
    for rows.Next() {
        e := &TransferEntry{}; rows.Scan(...)
        entries = append(entries, e)
    }
    return entries, nil
}

func (s *TransferStore) Close() error { return s.db.Close() }
```

Test: Write and read a transfer entry, verify persistence, verify update.

Commit: `git add go/internal/media/transfer.go go/internal/media/transfer_test.go && git commit -m "feat: transfer state machine with SQLite resume"`

---

### Task 3: Go daemon — streaming SendMediaStream handler

**Files:**
- Modify: `go/internal/client/daemon.go` (SendMedia → streaming handler)

Replace the existing `SendMedia` method with a new streaming handler:

```go
func (d *Daemon) SendMediaStream(stream pb.RelayClient_SendMediaStreamServer) error {
    var transfer *media.TransferEntry
    var tempFile *os.File
    var totalSize int64

    for {
        chunk, err := stream.Recv()
        if err == io.EOF {
            break
        }
        if err != nil {
            if transfer != nil {
                d.transferMu.Lock()
                d.transfers[transfer.ID].Status = media.TransferFailed
                d.transferMu.Unlock()
                d.transferStore.Update(transfer.ID, media.TransferFailed, 0, 0)
            }
            return err
        }

        if transfer == nil {
            // First chunk — create transfer
            transfer = &media.TransferEntry{
                ID: chunk.TransferId,
                Status: media.TransferQueued,
                CreatedAt: time.Now().UnixMilli(),
            }
            d.transferMu.Lock()
            d.transfers[transfer.ID] = &MediaTransfer{Status: TransferQueued}
            d.transferMu.Unlock()

            // Create temp file
            tempFile, _ = os.CreateTemp("", "media-upload-*")
            transfer.TempFilePath = tempFile.Name()
        }

        if tempFile != nil {
            n, _ := tempFile.Write(chunk.Data)
            totalSize += int64(n)
        }

        if totalSize > media.MediaMaxHardCap {
            tempFile.Close()
            os.Remove(tempFile.Name())
            return status.Errorf(codes.InvalidArgument, "file too large (max %d bytes)", media.MediaMaxHardCap)
        }
    }

    // Process the uploaded file
    if transfer == nil || tempFile == nil {
        return status.Error(codes.InvalidArgument, "no data received")
    }
    tempFile.Close()
    defer os.Remove(tempFile.Name())

    // Read back, encrypt, send via transport
    fileData, _ := os.ReadFile(tempFile.Name())
    estimatedSec := int32(len(fileData) / (100 * 1024) * 100 / 1000)
    if estimatedSec < 5 { estimatedSec = 5 }

    // Choose transport and send
    // ... (existing logic from SendMedia, adapted)
    
    stream.SendAndClose(&pb.SendMediaResponse{
        MessageId: transfer.ID,
        EstimatedSeconds: estimatedSec,
        Transport: transport,
    })
    return nil
}
```

Commit: `git add go/internal/client/daemon.go && git commit -m "feat: streaming SendMediaStream handler with temp file assembly"`

---

### Task 7: Flutter — media_service streaming upload + real progress

**Files:**
- Modify: `flutter/lib/core/media/media_service.dart`
- Modify: `flutter/lib/features/chat/providers/chat_provider.dart`

Replace `sendFile` with streaming upload:

```dart
Future<SendMediaResponse> sendFile({
  required String peerPubkey,
  required String filePath,
  required String mimeType,
}) async {
  final file = File(filePath);
  final fileSize = await file.length();
  final transferId = Uuid().v4();
  
  final stream = _createUploadStream(transferId, file, fileSize);
  try {
    final resp = await stub.sendMediaStream(stream).timeout(
      Duration(seconds: _estimateTimeout(fileSize)),
    );
    return resp;
  } catch (e) {
    debugPrint('sendMediaStream failed: $e');
    rethrow;
  }
}

Stream<MediaUploadChunk> _createUploadStream(
    String transferId, File file, int fileSize) async* {
  final chunkSize = 256 * 1024; // 256KB
  int index = 0;
  final stream = file.openRead();
  await for (final data in stream) {
    for (int offset = 0; offset < data.length; offset += chunkSize) {
      final end = (offset + chunkSize > data.length) ? data.length : offset + chunkSize;
      yield MediaUploadChunk(
        transferId: transferId,
        data: data.sublist(offset, end),
        chunkIndex: index++,
      );
    }
  }
}
```

Update `chat_provider.dart` to use the new streaming method and track real progress via `GetMediaStatus` polling.

Commit: `git add flutter/lib/core/media/media_service.dart flutter/lib/features/chat/providers/chat_provider.dart && git commit -m "feat: streaming gRPC upload with real progress tracking"`

---

### Task 8: Flutter — voice recording

**Files:**
- Modify: `flutter/pubspec.yaml` (add `record`, `audioplayers`)
- Modify: `flutter/lib/features/chat/screens/chat_input.dart`

Replace the fake `FilePicker.pickFiles(FileType.audio)` with actual recording:

```dart
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

final _audioRecorder = AudioRecorder();
bool _isRecording = false;

void _toggleRecording() async {
  if (_isRecording) {
    final path = await _audioRecorder.stop();
    _isRecording = false;
    if (path != null) {
      // Send as media
      ref.read(sendMediaProvider(SendMediaParams(
        peerPubkey: widget.peerPubkey,
        filePath: path,
        mimeType: 'audio/m4a',
      )));
    }
  } else {
    final hasPermission = await _audioRecorder.hasPermission();
    if (hasPermission) {
      await _audioRecorder.start(const RecordConfig(
        encoder: AudioEncoder.aacLc,
        extension: 'm4a',
      ));
      _isRecording = true;
    }
  }
}
```

Add a microphone button next to the send button:
```dart
IconButton(
  icon: Icon(_isRecording ? Icons.stop : Icons.mic),
  onPressed: _toggleRecording,
  color: _isRecording ? Colors.red : null,
),
```

Commit: `git add flutter/pubspec.yaml flutter/pubspec.lock flutter/lib/features/chat/screens/chat_input.dart && git commit -m "feat: voice recording with record/audioplayers packages"`

---

### Verification Checklist

- [ ] Go builds: `go build ./...`
- [ ] Go tests pass: `go test ./internal/...`
- [ ] Flutter analyzes: `flutter analyze`
- [ ] Transfer state machine: create, update, get, list pending
- [ ] Streaming upload: file sent in 256KB chunks, reassembled on daemon
- [ ] Real progress: `GetMediaStatus` returns actual `chunks_sent / total_chunks`
- [ ] Sender attribution: `.meta` sidecar includes `sender_pubkey`
- [ ] DNS chunks: parallel send (not sequential)
- [ ] Receiver fetch: parallel chunk fetch
