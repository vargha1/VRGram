# Phase 2+3: Invite Codes + Group Chat — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One-way invite codes (generate/join, auto-add peer) and group chat with epoch-based group key ratchet, fan-out relay indexing.

**Architecture:** Invite codes encode pubkey+nonce in base32; nonce acts as pre-shared key for initial hello. Groups use a shared group key (XChaCha20) distributed to each member via pairwise ECDH. Relay indexes group messages under all members' recipient hashes.

**Tech Stack:** Go 1.26, protobuf, BoltDB, Flutter/Riverpod, gRPC

## Global Constraints

- Go module: `github.com/user/dns-transport`
- Proto package: `relaypb`
- Auth: gRPC metadata `x-auth-token` (local daemon only)
- All existing crypto (X25519 ECDH, XChaCha20-Poly1305) unchanged
- Peer map keyed by **pubkey** (not nickname) to prevent collision

---

## File Structure

### New files
| File | Purpose |
|------|---------|
| `go/internal/crypto/invite.go` | Invite code encode/decode, HKDF hello key derivation |
| `go/internal/crypto/group.go` | Group key encryption/decryption, epoch rotation |
| `flutter/lib/features/peers/screens/invite_code_screen.dart` | Generate + enter invite code UI |
| `flutter/lib/features/group/providers/group_provider.dart` | Group model, GroupList notifier, persistence |
| `flutter/lib/features/group/screens/group_list_screen.dart` | Group list screen |
| `flutter/lib/features/group/screens/create_group_dialog.dart` | Create group dialog |
| `flutter/lib/features/group/screens/group_chat_screen.dart` | Group chat screen |

### Modified files
| File | Change |
|------|--------|
| `go/proto/relay.proto` | New RPCs + GroupInfo/GroupMember messages |
| `go/internal/client/daemon.go` | Invite logic, RemovePeer, group CRUD, fan-out send, group key distribution |
| `go/internal/store/store.go` | Multi-recipient indexing for group messages |
| `go/internal/relay/server.go` | Group relay-side changes |
| `flutter/lib/main.dart` | Remove `_syncPeers()` |
| `flutter/lib/features/peers/providers/peer_provider.dart` | Pubkey-keyed map, gRPC add/remove |
| `flutter/lib/features/peers/screens/add_peer_dialog.dart` | Add "Join via Invite Code" option |
| `flutter/lib/features/chat/screens/chat_list_screen.dart` | Add groups section |

---

### Task 1: Proto — invite + group RPCs

**Files:**
- Modify: `go/proto/relay.proto`
- Regenerate: Go + Flutter protobuf

**Interfaces:**
- Produces: `GenerateInviteCodeRequest{name}`, `GenerateInviteCodeResponse{code}`, `JoinViaCodeRequest{code}`, `JoinViaCodeResponse{}`, `RemovePeerRequest{pubkey}`, `CreateGroupRequest{name, member_pubkeys}`, `CreateGroupResponse{group_id}`, `GroupInfo`, `GroupMember`, `SendRequest.group_id`

- [ ] **Step 1: Add to go/proto/relay.proto**

```protobuf
// --- Invite RPCs ---
rpc GenerateInviteCode(GenerateInviteCodeRequest) returns (GenerateInviteCodeResponse);
rpc JoinViaCode(JoinViaCodeRequest) returns (Empty);
rpc RemovePeer(PeerInfo) returns (Empty);

message GenerateInviteCodeRequest {
  string nickname = 1;
}

message GenerateInviteCodeResponse {
  string code = 1;
}

message JoinViaCodeRequest {
  string code = 1;
}

// --- Group RPCs ---
rpc CreateGroup(CreateGroupRequest) returns (CreateGroupResponse);
rpc ListGroups(Empty) returns (ListGroupsResponse);
rpc LeaveGroup(LeaveGroupRequest) returns (Empty);
rpc RemoveGroupMember(RemoveGroupMemberRequest) returns (Empty);

message CreateGroupRequest {
  string name = 1;
  repeated string member_pubkeys = 2;
}

message CreateGroupResponse {
  string group_id = 1;
}

message LeaveGroupRequest {
  string group_id = 1;
}

message RemoveGroupMemberRequest {
  string group_id = 1;
  string member_pubkey = 2;
}

message ListGroupsResponse {
  repeated GroupInfo groups = 1;
}

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

Also add `group_id` to `SendRequest`:
```protobuf
message SendRequest {
  string peer_pubkey = 1;
  bytes plaintext = 2;
  uint64 client_timestamp_ms = 3;
  string group_id = 4; // optional, for group messages
}
```

Add `group_id` to `ReceivedMessage`:
```protobuf
message ReceivedMessage {
  string from_peer = 1;
  string message_id = 2;
  bytes plaintext = 3;
  int64 timestamp = 4;
  uint64 server_timestamp_ms = 5;
  uint64 sequence_number = 6;
  string group_id = 7; // optional, populated for group messages
}
```

- [ ] **Step 2: Regenerate Go protobuf**

```bash
cd /c/Users/VaRgha/ZCodeProject/go
rm -f pkg/relaypb/relay.pb.go pkg/relaypb/relay_grpc.pb.go proto/relay.pb.go
/c/Users/VaRgha/.local/bin/protoc --go_out=pkg/relaypb --go_opt=paths=source_relative --go-grpc_out=pkg/relaypb --go-grpc_opt=paths=source_relative -I. proto/relay.proto
cp pkg/relaypb/proto/relay.pb.go pkg/relaypb/relay.pb.go
cp pkg/relaypb/proto/relay_grpc.pb.go pkg/relaypb/relay_grpc.pb.go
rm -rf pkg/relaypb/proto
```

- [ ] **Step 3: Regenerate Flutter protobuf**

```bash
cd /c/Users/VaRgha/ZCodeProject/flutter
cp ../go/proto/relay.proto proto/relay.proto
/c/Users/VaRgha/.local/bin/protoc --dart_out=grpc:lib/core/grpc -Iproto --plugin=protoc-gen-dart="C:/Users/VaRgha/AppData/Local/Pub/Cache/bin/protoc-gen-dart.bat" proto/relay.proto
```

- [ ] **Step 4: Verify Go builds**

```bash
cd /c/Users/VaRgha/ZCodeProject/go && go build ./...
```

- [ ] **Step 5: Commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
git add go/proto/relay.proto go/pkg/relaypb/ flutter/proto/relay.proto flutter/lib/core/grpc/
git commit -m "proto: add invite + group RPCs and messages"
```

---

### Task 2: Go crypto — invite code encode/decode + HKDF hello key

**Files:**
- Create: `go/internal/crypto/invite.go`
- Create: `go/internal/crypto/invite_test.go`

**Interfaces:**
- Produces: `GenerateInviteCode(pubkey []byte) (string, []byte, error)` — returns code + nonce
  `ParseInviteCode(code string) (pubkey []byte, nonce []byte, nickname string, error)`
  `DeriveHelloKey(nonce []byte) []byte`
  `EncryptHello(helloKey []byte, payload []byte) ([]byte, error)`
  `DecryptHello(helloKey []byte, ciphertext []byte) ([]byte, error)`

- [ ] **Step 1: Write the failing test**

`go/internal/crypto/invite_test.go`:
```go
package crypto

import (
	"bytes"
	"encoding/base32"
	"strings"
	"testing"
)

var testBase32 = base32.HexEncoding.WithPadding(base32.NoPadding)

func TestGenerateAndParseInviteCode(t *testing.T) {
	pubkey := []byte("0123456789abcdef0123456789abcdef") // 32 bytes
	code, nonce, err := GenerateInviteCode(pubkey, "Alice")
	if err != nil {
		t.Fatalf("GenerateInviteCode: %v", err)
	}
	if !strings.HasPrefix(code, "v1:") {
		t.Errorf("expected v1: prefix, got %s", code[:3])
	}
	if len(nonce) != 8 {
		t.Errorf("expected nonce 8 bytes, got %d", len(nonce))
	}

	gotPubkey, gotNonce, gotNickname, err := ParseInviteCode(code)
	if err != nil {
		t.Fatalf("ParseInviteCode: %v", err)
	}
	if !bytes.Equal(gotPubkey, pubkey) {
		t.Errorf("pubkey mismatch")
	}
	if !bytes.Equal(gotNonce, nonce) {
		t.Errorf("nonce mismatch")
	}
	if gotNickname != "Alice" {
		t.Errorf("expected nickname Alice, got %s", gotNickname)
	}
}

func TestDeriveHelloKey(t *testing.T) {
	nonce := []byte{1, 2, 3, 4, 5, 6, 7, 8}
	key1 := DeriveHelloKey(nonce)
	key2 := DeriveHelloKey(nonce)
	if len(key1) != 32 {
		t.Errorf("expected key 32 bytes, got %d", len(key1))
	}
	if !bytes.Equal(key1, key2) {
		t.Errorf("keys should be deterministic")
	}
}

func TestHelloEncryptDecrypt(t *testing.T) {
	key := DeriveHelloKey([]byte("testnonce"))
	payload := []byte(`{"type":"hello","pubkey":"abc123","nickname":"Bob"}`)
	ciphertext, err := EncryptHello(key, payload)
	if err != nil {
		t.Fatalf("EncryptHello: %v", err)
	}
	plaintext, err := DecryptHello(key, ciphertext)
	if err != nil {
		t.Fatalf("DecryptHello: %v", err)
	}
	if !bytes.Equal(plaintext, payload) {
		t.Errorf("round-trip mismatch")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /c/Users/VaRgha/ZCodeProject/go && go test ./internal/crypto/ -run TestGenerateAndParseInviteCode -v
```
Expected: FAIL

- [ ] **Step 3: Implement invite.go**

`go/internal/crypto/invite.go`:
```go
package crypto

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base32"
	"fmt"
	"strings"

	"golang.org/x/crypto/chacha20poly1305"
	"golang.org/x/crypto/hkdf"
)

var base32hex = base32.HexEncoding.WithPadding(base32.NoPadding)

// GenerateInviteCode creates a one-way invite code from a pubkey and nickname.
// Format: v1:<base32(pubkey)>:<base32(nonce_8)>:<base32(nickname)>
// Returns the code and the generated nonce.
func GenerateInviteCode(pubkey []byte, nickname string) (string, []byte, error) {
	if len(pubkey) != 32 {
		return "", nil, fmt.Errorf("pubkey must be 32 bytes, got %d", len(pubkey))
	}
	nonce := make([]byte, 8)
	if _, err := rand.Read(nonce); err != nil {
		return "", nil, fmt.Errorf("generate nonce: %w", err)
	}
	code := fmt.Sprintf("v1:%s:%s:%s",
		base32hex.EncodeToString(pubkey),
		base32hex.EncodeToString(nonce),
		base32hex.EncodeToString([]byte(nickname)),
	)
	return code, nonce, nil
}

// ParseInviteCode decodes an invite code into pubkey, nonce, and nickname.
func ParseInviteCode(code string) (pubkey []byte, nonce []byte, nickname string, err error) {
	parts := strings.SplitN(code, ":", 4)
	if len(parts) != 4 || parts[0] != "v1" {
		return nil, nil, "", fmt.Errorf("invalid invite code format")
	}
	pubkey, err = base32hex.DecodeString(parts[1])
	if err != nil || len(pubkey) != 32 {
		return nil, nil, "", fmt.Errorf("invalid pubkey in invite code")
	}
	nonce, err = base32hex.DecodeString(parts[2])
	if err != nil || len(nonce) != 8 {
		return nil, nil, "", fmt.Errorf("invalid nonce in invite code")
	}
	nickBytes, err := base32hex.DecodeString(parts[3])
	if err != nil {
		return nil, nil, "", fmt.Errorf("invalid nickname in invite code")
	}
	return pubkey, nonce, string(nickBytes), nil
}

// DeriveHelloKey derives a 32-byte XChaCha20 key from the invite nonce.
// Uses HKDF-SHA256 with a fixed context string.
func DeriveHelloKey(nonce []byte) []byte {
	hkdf := hkdf.New(sha256.New, nonce, nil, []byte("vrgram-hello-v1"))
	key := make([]byte, 32)
	hkdf.Read(key)
	return key
}

// EncryptHello encrypts a plaintext payload with the hello key using XChaCha20-Poly1305.
// Format: nonce_24bytes + ciphertext
func EncryptHello(helloKey []byte, payload []byte) ([]byte, error) {
	aead, err := chacha20poly1305.NewX(helloKey)
	if err != nil {
		return nil, fmt.Errorf("new xchacha20: %w", err)
	}
	nonce := make([]byte, chacha20poly1305.NonceSizeX)
	if _, err := rand.Read(nonce); err != nil {
		return nil, fmt.Errorf("generate nonce: %w", err)
	}
	ciphertext := aead.Seal(nil, nonce, payload, nil)
	return append(nonce, ciphertext...), nil
}

// DecryptHello decrypts a ciphertext encrypted with EncryptHello.
func DecryptHello(helloKey []byte, data []byte) ([]byte, error) {
	aead, err := chacha20poly1305.NewX(helloKey)
	if err != nil {
		return nil, fmt.Errorf("new xchacha20: %w", err)
	}
	if len(data) < chacha20poly1305.NonceSizeX {
		return nil, fmt.Errorf("ciphertext too short")
	}
	nonce := data[:chacha20poly1305.NonceSizeX]
	ciphertext := data[chacha20poly1305.NonceSizeX:]
	return aead.Open(nil, nonce, ciphertext, nil)
}
```

- [ ] **Step 4: Run tests to verify pass**

```bash
cd /c/Users/VaRgha/ZCodeProject/go && go test ./internal/crypto/ -run "TestGenerateAndParseInviteCode|TestDeriveHelloKey|TestHelloEncryptDecrypt" -v
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
git add go/internal/crypto/invite.go go/internal/crypto/invite_test.go
git commit -m "feat: invite code encode/decode + HKDF hello key derivation"
```

---

### Task 3: Go daemon — peer map rekey, RemovePeer + invite logic

**Files:**
- Modify: `go/internal/client/daemon.go`

**Interfaces:**
- Consumes: `crypto.GenerateInviteCode`, `crypto.ParseInviteCode`, `crypto.DeriveHelloKey`, `crypto.EncryptHello`, `crypto.DecryptHello`
- Produces: Daemon methods `GenerateInviteCode`, `JoinViaCode`, `RemovePeer`; peer map keyed by pubkey

- [ ] **Step 1: Change daemon.peers map from nickname→pubkey to pubkey→PeerInfo**

In `Daemon` struct (daemon.go), change:
```go
peers     map[string]string // nickname -> pubkey
```
to:
```go
type PeerInfo struct {
    Nickname string `json:"nickname"`
    Pubkey   string `json:"pubkey"`
}
// ...
peers     map[string]*PeerInfo // pubkey -> {nickname}
```

Update `loadPeers`, `savePeers`, `AddPeer` accordingly. The daemon_peers.json format changes from `{"nickname":"pubkey"}` to `{"pubkey":{"nickname":"..","pubkey":".."}}`.

- [ ] **Step 2: Implement RemovePeer RPC**

```go
func (d *Daemon) RemovePeer(ctx context.Context, req *pb.PeerInfo) (*pb.Empty, error) {
    d.peersMu.Lock()
    delete(d.peers, req.Pubkey)
    d.peersMu.Unlock()
    d.savePeers()
    return &pb.Empty{}, nil
}
```

- [ ] **Step 3: Implement GenerateInviteCode RPC**

```go
func (d *Daemon) GenerateInviteCode(ctx context.Context, req *pb.GenerateInviteCodeRequest) (*pb.GenerateInviteCodeResponse, error) {
    code, nonce, err := crypto.GenerateInviteCode(d.identity.PublicKey, req.Nickname)
    if err != nil {
        return nil, status.Error(codes.Internal, err.Error())
    }
    // Store pending nonce with TTL (in-memory map)
    d.pendingHellosMu.Lock()
    if d.pendingHellos == nil {
        d.pendingHellos = make(map[string]helloEntry)
    }
    d.pendingHellos[hex.EncodeToString(nonce)] = helloEntry{
        nonce:    nonce,
        pubkey:   base64.StdEncoding.EncodeToString(d.identity.PublicKey),
        nickname: req.Nickname,
        createdAt: time.Now(),
    }
    d.pendingHellosMu.Unlock()
    return &pb.GenerateInviteCodeResponse{Code: code}, nil
}
```

Add `pendingHellos` map and `helloEntry` struct to `Daemon`:
```go
type helloEntry struct {
    nonce     []byte
    pubkey    string
    nickname  string
    createdAt time.Time
}
pendingHellos   map[string]helloEntry
pendingHellosMu sync.Mutex
```

- [ ] **Step 4: Implement JoinViaCode RPC**

```go
func (d *Daemon) JoinViaCode(ctx context.Context, req *pb.JoinViaCodeRequest) (*pb.Empty, error) {
    remotePubkey, nonce, nickname, err := crypto.ParseInviteCode(req.Code)
    if err != nil {
        return nil, status.Errorf(codes.InvalidArgument, "invalid invite code: %v", err)
    }
    remotePubkeyB64 := base64.StdEncoding.EncodeToString(remotePubkey)

    // Add remote as a peer
    d.peersMu.Lock()
    d.peers[remotePubkeyB64] = &PeerInfo{Nickname: nickname, Pubkey: remotePubkeyB64}
    d.peersMu.Unlock()
    d.savePeers()

    // Derive hello key from nonce and send hello message
    helloKey := crypto.DeriveHelloKey(nonce)
    myPubkeyB64 := base64.StdEncoding.EncodeToString(d.identity.PublicKey)
    helloPayload := fmt.Sprintf(`{"type":"hello","pubkey":"%s","nickname":"%s"}`, myPubkeyB64, d.myNickname)
    encryptedHello, err := crypto.EncryptHello(helloKey, []byte(helloPayload))
    if err != nil {
        return nil, status.Error(codes.Internal, "encrypt hello failed")
    }

    // Send encrypted hello via relay addressed to remote's recipient hash
    // (Plaintext = encrypted hello, no ECDH)
    msgID, chunkCount, err := d.engine.SendMessage(ctx, encryptedHello, remotePubkeyB64)
    if err != nil {
        // Queue for later retry
        d.queue.Enqueue(remotePubkeyB64, encryptedHello)
    }
    _ = msgID
    _ = chunkCount

    return &pb.Empty{}, nil
}
```

- [ ] **Step 5: Update PollMessages to try hello_key decryption for unknown senders**

In `PollMessages`, when decryption fails for all known peers, also try each pending hello nonce to decrypt:

```go
// If decryption failed for all known peers, try pending hello keys
if decrypted == nil {
    d.pendingHellosMu.Lock()
    for nonceHex, entry := range d.pendingHellos {
        if time.Since(entry.createdAt) > 24*time.Hour {
            delete(d.pendingHellos, nonceHex)
            continue
        }
        helloKey := crypto.DeriveHelloKey(entry.nonce)
        plaintext, err := crypto.DecryptHello(helloKey, raw)
        if err != nil {
            continue
        }
        // Parse hello payload
        var hello struct {
            Type     string `json:"type"`
            Pubkey   string `json:"pubkey"`
            Nickname string `json:"nickname"`
        }
        if json.Unmarshal(plaintext, &hello) == nil && hello.Type == "hello" && hello.Pubkey != "" {
            // Auto-add this peer
            nick := hello.Nickname
            if nick == "" { nick = "Unknown" }
            d.peersMu.Lock()
            d.peers[hello.Pubkey] = &PeerInfo{Nickname: nick, Pubkey: hello.Pubkey}
            d.peersMu.Unlock()
            d.savePeers()
            decrypted = plaintext
            fromPeer = hello.Pubkey
            delete(d.pendingHellos, nonceHex)
            d.debugWrite("PollMessages: auto-added peer via hello %s", hello.Pubkey[:16])
        } else {
            d.debugWrite("PollMessages: invalid hello payload from nonce=%s", nonceHex)
        }
    }
    d.pendingHellosMu.Unlock()
}
```

- [ ] **Step 6: Verify Go builds**

```bash
cd /c/Users/VaRgha/ZCodeProject/go && go build ./...
```

- [ ] **Step 7: Commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
git add go/internal/client/daemon.go
git commit -m "feat: daemon invite logic, peer rekey to pubkey, RemovePeer, hello auto-add"
```

---

### Task 4: Flutter — remove _syncPeers, wire up gRPC add/remove peer

**Files:**
- Modify: `flutter/lib/main.dart`
- Modify: `flutter/lib/features/peers/providers/peer_provider.dart`

- [ ] **Step 1: Remove _syncPeers from main.dart**

In `main.dart`, find the `_syncPeers` method and its callsite. Remove both. The daemon is now the peer authority. Keep only `_syncRelays` if it exists (or remove if daemon owns that too).

- [ ] **Step 2: Update peer_provider.dart for pubkey-keyed map**

Add a `removePeerByPubkey(String pubkey)` method that also calls gRPC `RemovePeer`:
```dart
  Future<void> removePeerByPubkey(String pubkey) async {
    try {
      final client = GrpcClient();
      await client.stub.removePeer(PeerInfo(pubkey: pubkey, nickname: ''));
    } catch (e) {
      debugPrint('removePeer gRPC failed: $e');
    }
    state = state.where((p) => p.pubkey != pubkey).toList();
    await _save();
  }
```

Wire up `addPeerProvider` to be used from the UI (currently unused). The `PeerList._sanitizePubkey` should remain static for reuse in dialogs.

- [ ] **Step 3: Verify Flutter analyzes**

```bash
cd /c/Users/VaRgha/ZCodeProject/flutter && flutter analyze lib/main.dart lib/features/peers/providers/peer_provider.dart
```

- [ ] **Step 4: Commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
git add flutter/lib/main.dart flutter/lib/features/peers/providers/peer_provider.dart
git commit -m "feat: remove _syncPeers, wire up gRPC add/remove peer"
```

---

### Task 5: Flutter — invite code screen + add_peer_dialog update

**Files:**
- Create: `flutter/lib/features/peers/screens/invite_code_screen.dart`
- Modify: `flutter/lib/features/peers/screens/add_peer_dialog.dart`

- [ ] **Step 1: Create invite_code_screen.dart**

A screen with two tabs/sections:
1. **Generate** — Shows a large invite code. Copy button. Share button.
2. **Enter** — Text field for pasting someone else's code. Join button.

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';

class InviteCodeScreen extends ConsumerStatefulWidget {
  const InviteCodeScreen({super.key});
  @override
  ConsumerState<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends ConsumerState<InviteCodeScreen> {
  String? _generatedCode;
  bool _generating = false;
  final _codeController = TextEditingController();
  bool _joining = false;
  bool _showCode = true; // toggle between generate/enter tabs

  Future<void> _generateCode() async {
    setState(() => _generating = true);
    try {
      final client = GrpcClient();
      final resp = await client.stub
          .generateInviteCode(GenerateInviteCodeRequest(nickname: ''))
          .timeout(const Duration(seconds: 10));
      setState(() => _generatedCode = resp.code);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generate failed: $e')),
        );
      }
    } finally {
      setState(() => _generating = false);
    }
  }

  Future<void> _joinViaCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _joining = true);
    try {
      final client = GrpcClient();
      await client.stub
          .joinViaCode(JoinViaCodeRequest(code: code))
          .timeout(const Duration(seconds: 10));
      if (mounted) {
        Navigator.of(context).pop(true); // return true = peer added
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Join failed: $e')),
        );
      }
    } finally {
      setState(() => _joining = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Invite'),
          bottom: const TabBar(
            tabs: [Tab(text: 'My Code'), Tab(text: 'Enter Code')],
          ),
        ),
        body: TabBarView(
          children: [
            // Generate tab
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Text('Share this code with someone to connect.'),
                const SizedBox(height: 16),
                if (_generatedCode != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(_generatedCode!,
                        style: const TextStyle(fontSize: 14, fontFamily: 'monospace')),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    ElevatedButton.icon(
                      onPressed: () => Clipboard.setData(
                          ClipboardData(text: _generatedCode!)),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _generateCode,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Regenerate'),
                    ),
                  ]),
                ] else ...[
                  ElevatedButton(
                    onPressed: _generateCode,
                    child: _generating
                        ? const CircularProgressIndicator()
                        : const Text('Generate Invite Code'),
                  ),
                ],
              ]),
            ),
            // Join tab
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Text('Paste someone\'s invite code to connect.'),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Invite Code',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _joining ? null : _joinViaCode,
                  child: _joining
                      ? const CircularProgressIndicator()
                      : const Text('Join'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Update add_peer_dialog.dart**

Add a "Join via Invite Code" button that navigates to the invite code screen:

```dart
ElevatedButton.icon(
  onPressed: () async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const InviteCodeScreen()));
    if (result == true && mounted) Navigator.of(context).pop();
  },
  icon: const Icon(Icons.qr_code),
  label: const Text('Join via Invite Code'),
),
```

- [ ] **Step 3: Verify Flutter analyzes**

```bash
cd /c/Users/VaRgha/ZCodeProject/flutter && flutter analyze lib/features/peers/screens/
```

- [ ] **Step 4: Commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
git add flutter/lib/features/peers/screens/invite_code_screen.dart flutter/lib/features/peers/screens/add_peer_dialog.dart
git commit -m "feat: invite code screen (generate + enter) and add_peer_dialog update"
```

---

### Task 6: Go crypto — group key encryption/rotation

**Files:**
- Create: `go/internal/crypto/group.go`
- Create: `go/internal/crypto/group_test.go`

**Interfaces:**
- Produces: `GenerateGroupKey() ([]byte, error)`
  `EncryptGroupMessage(groupKey []byte, plaintext []byte) ([]byte, error)`
  `DecryptGroupMessage(groupKey []byte, ciphertext []byte) ([]byte, error)`
  `RotateGroupKey(oldKey []byte) ([]byte, error)`

- [ ] **Step 1: Write the failing test**

```go
package crypto

import (
	"bytes"
	"testing"
)

func TestGroupKeyGeneration(t *testing.T) {
	key, err := GenerateGroupKey()
	if err != nil {
		t.Fatalf("GenerateGroupKey: %v", err)
	}
	if len(key) != 32 {
		t.Errorf("expected 32 bytes, got %d", len(key))
	}
}

func TestGroupEncryptDecrypt(t *testing.T) {
	key, _ := GenerateGroupKey()
	plaintext := []byte("hello group")
	ciphertext, err := EncryptGroupMessage(key, plaintext)
	if err != nil {
		t.Fatalf("EncryptGroupMessage: %v", err)
	}
	got, err := DecryptGroupMessage(key, ciphertext)
	if err != nil {
		t.Fatalf("DecryptGroupMessage: %v", err)
	}
	if !bytes.Equal(got, plaintext) {
		t.Errorf("round-trip mismatch")
	}
}

func TestGroupKeyRotation(t *testing.T) {
	key1, _ := GenerateGroupKey()
	key2, err := RotateGroupKey(key1)
	if err != nil {
		t.Fatalf("RotateGroupKey: %v", err)
	}
	if bytes.Equal(key1, key2) {
		t.Errorf("rotated key should differ from original")
	}
	if len(key2) != 32 {
		t.Errorf("expected 32 bytes, got %d", len(key2))
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /c/Users/VaRgha/ZCodeProject/go && go test ./internal/crypto/ -run TestGroupKey -v
```
Expected: FAIL

- [ ] **Step 3: Implement group.go**

```go
package crypto

import (
	"crypto/rand"
	"crypto/sha256"
	"fmt"

	"golang.org/x/crypto/chacha20poly1305"
)

// GenerateGroupKey generates a random 32-byte group key.
func GenerateGroupKey() ([]byte, error) {
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		return nil, fmt.Errorf("generate group key: %w", err)
	}
	return key, nil
}

// EncryptGroupMessage encrypts plaintext with the group key using XChaCha20-Poly1305.
// Format: nonce_24bytes + ciphertext
func EncryptGroupMessage(groupKey []byte, plaintext []byte) ([]byte, error) {
	aead, err := chacha20poly1305.NewX(groupKey)
	if err != nil {
		return nil, fmt.Errorf("new xchacha20: %w", err)
	}
	nonce := make([]byte, chacha20poly1305.NonceSizeX)
	if _, err := rand.Read(nonce); err != nil {
		return nil, fmt.Errorf("generate nonce: %w", err)
	}
	return aead.Seal(nil, nonce, plaintext, nil), nil
}

// DecryptGroupMessage decrypts a ciphertext with the group key.
func DecryptGroupMessage(groupKey []byte, data []byte) ([]byte, error) {
	aead, err := chacha20poly1305.NewX(groupKey)
	if err != nil {
		return nil, fmt.Errorf("new xchacha20: %w", err)
	}
	if len(data) < chacha20poly1305.NonceSizeX {
		return nil, fmt.Errorf("ciphertext too short")
	}
	return aead.Open(nil, data[:chacha20poly1305.NonceSizeX], data[chacha20poly1305.NonceSizeX:], nil)
}

// RotateGroupKey derives a new group key from the old one using SHA256.
// Used for epoch-based key rotation when membership changes.
func RotateGroupKey(oldKey []byte) ([]byte, error) {
	h := sha256.Sum256(append(oldKey, []byte("group-rotation-v1")...))
	return h[:], nil
}
```

- [ ] **Step 4: Run tests to verify pass**

```bash
cd /c/Users/VaRgha/ZCodeProject/go && go test ./internal/crypto/ -run TestGroupKey -v
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
git add go/internal/crypto/group.go go/internal/crypto/group_test.go
git commit -m "feat: group key encryption, rotation, epoch validation"
```

---

### Task 7: Go daemon — group CRUD, fan-out send, key distribution

**Files:**
- Modify: `go/internal/client/daemon.go`

**Interfaces:**
- Consumes: `crypto.GenerateGroupKey`, `crypto.EncryptGroupMessage`, `crypto.DecryptGroupMessage`, `crypto.RotateGroupKey`
- Produces: Daemon methods `CreateGroup`, `ListGroups`, `LeaveGroup`, `RemoveGroupMember`; `group_id` field in `SendMessage`

- [ ] **Step 1: Add group data structures to daemon.go**

```go
type Group struct {
    GroupID    string                `json:"group_id"`
    Name       string                `json:"name"`
    AdminPubkey string               `json:"admin_pubkey"`
    Members    map[string]*GroupMember `json:"members"` // pubkey -> member
    GroupKey   []byte                `json:"group_key"`
    KeyEpoch   uint64                `json:"key_epoch"`
}

type GroupMember struct {
    Pubkey   string `json:"pubkey"`
    Nickname string `json:"nickname"`
    Role     string `json:"role"` // "admin" | "member"
}
```

Add to Daemon struct:
```go
groups    map[string]*Group // groupID -> Group
groupsMu  sync.RWMutex
groupsPath string
```

- [ ] **Step 2: Implement CreateGroup RPC**

```go
func (d *Daemon) CreateGroup(ctx context.Context, req *pb.CreateGroupRequest) (*pb.CreateGroupResponse, error) {
    groupID := fmt.Sprintf("%x", time.Now().UnixNano()) // or use UUID
    groupKey, err := crypto.GenerateGroupKey()
    if err != nil {
        return nil, status.Error(codes.Internal, "generate group key failed")
    }

    members := make(map[string]*GroupMember)
    myPubkey := base64.StdEncoding.EncodeToString(d.identity.PublicKey)
    members[myPubkey] = &GroupMember{Pubkey: myPubkey, Nickname: req.Name + "_admin", Role: "admin"}

    for _, mpk := range req.MemberPubkeys {
        members[mpk] = &GroupMember{Pubkey: mpk, Nickname: "", Role: "member"}
    }

    group := &Group{
        GroupID:     groupID,
        Name:        req.Name,
        AdminPubkey: myPubkey,
        Members:     members,
        GroupKey:    groupKey,
        KeyEpoch:    1,
    }
    d.groupsMu.Lock()
    d.groups[groupID] = group
    d.groupsMu.Unlock()
    d.saveGroups()

    // Distribute group key to each member via pairwise ECDH
    for pubkeyB64, member := range members {
        if pubkeyB64 == myPubkey { continue }
        pubkey, _ := base64.StdEncoding.DecodeString(pubkeyB64)
        ss, _ := crypto.SharedSecret(d.identity.PrivateKey, pubkey)
        distribution := fmt.Sprintf(`{"type":"group_key","group_id":"%s","group_key_b64":"%s","key_epoch":%d,"name":"%s"}`,
            groupID, base64.StdEncoding.EncodeToString(groupKey), 1, req.Name)
        ciphertext, _, _ := crypto.EncryptMessage(ss, []byte(distribution))
        d.engine.SendMessage(ctx, ciphertext, pubkeyB64)
        _ = member
    }

    return &pb.CreateGroupResponse{GroupId: groupID}, nil
}
```

- [ ] **Step 3: Modify SendMessage to set group_id if sending to a group**

Update `SendMessage` to accept a group_id parameter. The Flutter `SendRequest` proto already has `group_id` (field 4). If set, the daemon encrypts with the group key instead of pairwise ECDH.

```go
// In SendMessage, if req.GroupId is set:
if req.GroupId != "" {
    d.groupsMu.RLock()
    group, ok := d.groups[req.GroupId]
    d.groupsMu.RUnlock()
    if !ok {
        return nil, status.Errorf(codes.NotFound, "group not found: %s", req.GroupId)
    }
    // Encrypt with group key
    groupPayload := fmt.Sprintf(`{"g":"%s","e":%d,"m":"%s"}`,
        req.GroupId, group.KeyEpoch, base64.StdEncoding.EncodeToString(req.Plaintext))
    ciphertext, err := crypto.EncryptGroupMessage(group.GroupKey, []byte(groupPayload))
    if err != nil {
        return nil, status.Error(codes.Internal, "encrypt group message failed")
    }
    // Send to each member individually
    for pubkey := range group.Members {
        if pubkey == base64.StdEncoding.EncodeToString(d.identity.PublicKey) { continue }
        d.engine.SendMessage(ctx, ciphertext, pubkey)
    }
    return &pb.SendResponse{MessageId: "group:" + req.GroupId}, nil
}
```

- [ ] **Step 4: Update PollMessages to detect group messages**

In `PollMessages`, after decryption, check if the plaintext is a group message:
```go
// Check for group message format: {"g":"group_id","e":epoch,"m":"base64_ciphertext"}
if len(decrypted) > 10 && decrypted[0] == '{' {
    var groupMeta struct {
        G  string `json:"g"`
        E  uint64 `json:"e"`
        MB64 string `json:"m"`
    }
    if json.Unmarshal(decrypted, &groupMeta) == nil && groupMeta.G != "" && groupMeta.MB64 != "" {
        // Look up group key for this group
        d.groupsMu.RLock()
        group, hasGroup := d.groups[groupMeta.G]
        d.groupsMu.RUnlock()
        if hasGroup {
            if groupMeta.E < group.KeyEpoch {
                d.debugWrite("ignoring stale group message (epoch %d < %d)", groupMeta.E, group.KeyEpoch)
                continue
            }
            msgBytes, _ := base64.StdEncoding.DecodeString(groupMeta.MB64)
            msgPlaintext, err := crypto.DecryptGroupMessage(group.GroupKey, msgBytes)
            if err == nil {
                decrypted = msgPlaintext
                groupID := groupMeta.G
                received.GroupId = &groupID // set group_id on ReceivedMessage
            }
        }
    }
}
```

- [ ] **Step 5: Verify Go builds**

```bash
cd /c/Users/VaRgha/ZCodeProject/go && go build ./...
```

- [ ] **Step 6: Commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
git add go/internal/client/daemon.go
git commit -m "feat: group CRUD, fan-out send, group key distribution in daemon"
```

---

### Task 8: Go store — multi-recipient indexing for group messages

**Files:**
- Modify: `go/internal/store/store.go`

- [ ] **Step 1: Modify ListPeerMessages to support multiple owners**

When a group message is sent, it needs to be indexed under ALL members' recipient hashes. The relay needs to be able to associate one msgID with multiple peerIDs. Currently `messageOwner` is `map[[8]byte]string` (one-to-one). Change to `map[[8]byte][]string` if needed, or use a separate index for group messages.

Simpler approach: for group messages, the daemon already sends the message to each member individually (each call to `engine.SendMessage` creates a separate `ChunkMessage` with a different recipient hash). So the relay naturally stores them under each member's hash. No relay-side change needed for group fan-out.

The `group_id` field in `SendRequest` is informational — the daemon handles the fan-out before the relay sees it. Skip this task (relay stays as-is).

- [ ] **Step 2: No changes needed — relay already handles per-recipient indexing naturally**

The daemon's `SendMessage` with group_id already sends to each member individually via separate `engine.SendMessage` calls. The relay stores each under the respective recipient hash. No store changes needed.

---

### Task 9: Flutter — group provider + persistence

**Files:**
- Create: `flutter/lib/features/group/providers/group_provider.dart`

- [ ] **Step 1: Create Group model and GroupList notifier**

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';
import '../../../core/platform/app_data_dir.dart';

class GroupMember {
  final String pubkey;
  final String nickname;
  final String role; // "admin" | "member"
  GroupMember({required this.pubkey, this.nickname = '', this.role = 'member'});

  Map<String, dynamic> toJson() => {'pubkey': pubkey, 'nickname': nickname, 'role': role};
  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
    pubkey: j['pubkey'] as String,
    nickname: j['nickname'] as String? ?? '',
    role: j['role'] as String? ?? 'member',
  );
}

class Group {
  final String id;
  final String name;
  final String adminPubkey;
  final List<GroupMember> members;
  Group({required this.id, required this.name, required this.adminPubkey, required this.members});

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'admin_pubkey': adminPubkey,
    'members': members.map((m) => m.toJson()).toList(),
  };
  factory Group.fromJson(Map<String, dynamic> j) => Group(
    id: j['id'] as String,
    name: j['name'] as String,
    adminPubkey: j['admin_pubkey'] as String,
    members: (j['members'] as List).map((e) => GroupMember.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

class GroupList extends Notifier<List<Group>> {
  static const _fileName = 'groups.json';

  @override
  List<Group> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    try {
      final file = AppDataDir.file(_fileName);
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as List;
        state = json.map((e) => Group.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Failed to load groups: $e');
    }
  }

  Future<void> _save() async {
    try {
      final file = AppDataDir.file(_fileName);
      await file.writeAsString(jsonEncode(state.map((g) => g.toJson()).toList()));
    } catch (e) {
      debugPrint('Failed to save groups: $e');
    }
  }

  Future<void> createGroup(String name, List<String> memberPubkeys) async {
    try {
      final client = GrpcClient();
      final resp = await client.stub.createGroup(CreateGroupRequest(
        name: name,
        memberPubkeys: memberPubkeys,
      ));
      // Add locally; daemon distributes key
      state = [...state, Group(id: resp.groupId, name: name, adminPubkey: '', members: [])];
      await _save();
    } catch (e) {
      debugPrint('createGroup failed: $e');
      rethrow;
    }
  }

  void addGroup(Group group) {
    if (state.any((g) => g.id == group.id)) return;
    state = [...state, group];
    _save();
  }

  Future<void> leaveGroup(String groupId) async {
    try {
      final client = GrpcClient();
      await client.stub.leaveGroup(LeaveGroupRequest(groupId: groupId));
    } catch (_) {}
    state = state.where((g) => g.id != groupId).toList();
    _save();
  }
}

final groupProvider = NotifierProvider<GroupList, List<Group>>(GroupList.new);
```

- [ ] **Step 2: Verify Flutter analyzes**

```bash
cd /c/Users/VaRgha/ZCodeProject/flutter && flutter analyze lib/features/group/
```

- [ ] **Step 3: Commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
mkdir -p flutter/lib/features/group/providers
git add flutter/lib/features/group/providers/group_provider.dart
git commit -m "feat: group provider with persistence and gRPC CRUD"
```

---

### Task 10: Flutter — group list screen

**Files:**
- Create: `flutter/lib/features/group/screens/group_list_screen.dart`

- [ ] **Step 1: Create group_list_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/group_provider.dart';
import 'create_group_dialog.dart';
import 'group_chat_screen.dart';

class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const CreateGroupDialog(),
        ),
        child: const Icon(Icons.add),
      ),
      body: groups.isEmpty
          ? const Center(child: Text('No groups yet'))
          : ListView.builder(
              itemCount: groups.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(groups[i].name),
                subtitle: Text('${groups[i].members.length} members'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupChatScreen(group: groups[i]),
                  ),
                ),
              ),
            ),
    );
  }
}
```

- [ ] **Step 2: Verify Flutter analyzes**

```bash
cd /c/Users/VaRgha/ZCodeProject/flutter && flutter analyze lib/features/group/screens/group_list_screen.dart
```

- [ ] **Step 3: Commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
git add flutter/lib/features/group/screens/group_list_screen.dart
git commit -m "feat: group list screen"
```

---

### Task 11: Flutter — create group dialog

**Files:**
- Create: `flutter/lib/features/group/screens/create_group_dialog.dart`

- [ ] **Step 1: Create dialog with name field + member picker**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/group_provider.dart';
import '../../peers/providers/peer_provider.dart';

class CreateGroupDialog extends ConsumerStatefulWidget {
  const CreateGroupDialog({super.key});
  @override
  ConsumerState<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends ConsumerState<CreateGroupDialog> {
  final _nameController = TextEditingController();
  final _selected = <String>{}; // pubkeys
  bool _creating = false;

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selected.isEmpty) return;
    setState(() => _creating = true);
    try {
      await ref.read(groupProvider.notifier).createGroup(name, _selected.toList());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      setState(() => _creating = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peers = ref.watch(peerProvider);
    return AlertDialog(
      title: const Text('New Group'),
      content: SingleChildScrollView(
        child: Column(children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Group Name'),
          ),
          const SizedBox(height: 12),
          const Text('Select Members:'),
          ...peers.map((peer) => CheckboxListTile(
                title: Text(peer.nickname),
                subtitle: Text(peer.pubkey.substring(0, 16)),
                value: _selected.contains(peer.pubkey),
                onChanged: (v) {
                  setState(() {
                    if (v == true) { _selected.add(peer.pubkey); }
                    else { _selected.remove(peer.pubkey); }
                  });
                },
              )),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _creating ? null : _create,
          child: _creating ? const CircularProgressIndicator() : const Text('Create'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify Flutter analyzes**

```bash
cd /c/Users/VaRgha/ZCodeProject/flutter && flutter analyze lib/features/group/screens/create_group_dialog.dart
```

- [ ] **Step 3: Commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
git add flutter/lib/features/group/screens/create_group_dialog.dart
git commit -m "feat: create group dialog with member picker"
```

---

### Task 12: Flutter — group chat screen (basic)

**Files:**
- Create: `flutter/lib/features/group/screens/group_chat_screen.dart`

- [ ] **Step 1: Create group chat screen**

A simplified version of `chat_screen.dart` that shows messages for a group. Uses existing `ChatMessage` model with `toPeer` set to the group member's pubkey and `groupID` tracked.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/group_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/widgets/message_bubble.dart';
import '../../chat/widgets/chat_input.dart';

class GroupChatScreen extends ConsumerWidget {
  final Group group;
  const GroupChatScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatProvider);
    // Filter messages for this group (by group member pubkeys)
    final memberPubkeys = group.members.map((m) => m.pubkey).toSet();
    final groupMsgs = messages.where((m) =>
        (m.fromPeer != null && memberPubkeys.contains(m.fromPeer)) ||
        (m.toPeer != null && memberPubkeys.contains(m.toPeer))).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          PopupMenuButton(itemBuilder: (_) => [
            const PopupMenuItem(value: 'members', child: Text('Members')),
            const PopupMenuItem(value: 'leave', child: Text('Leave Group')),
          ], onSelected: (v) async {
            if (v == 'leave') {
              await ref.read(groupProvider.notifier).leaveGroup(group.id);
              if (context.mounted) Navigator.pop(context);
            }
          }),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: groupMsgs.length,
              itemBuilder: (_, i) =>
                  MessageBubble(message: groupMsgs[groupMsgs.length - 1 - i]),
            ),
          ),
          ChatInput(
            onSend: (text) async {
              // Send to all group members
              for (final member in group.members) {
                ref.read(chatProvider.notifier).sendMessage(member.pubkey, text);
              }
            },
            peerPubkey: '', // group messages are tracked differently
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Update chat_list_screen.dart to add groups section**

In `chat_list_screen.dart`, add a Groups section at the top that navigates to `GroupListScreen`:

```dart
// Before the peer list, add:
ListTile(
  leading: const Icon(Icons.groups),
  title: const Text('Groups'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const GroupListScreen())),
),
```

- [ ] **Step 3: Verify Flutter analyzes**

```bash
cd /c/Users/VaRgha/ZCodeProject/flutter && flutter analyze lib/features/group/screens/group_chat_screen.dart
```

- [ ] **Step 4: Commit**

```bash
cd /c/Users/VaRgha/ZCodeProject
git add flutter/lib/features/group/screens/group_chat_screen.dart flutter/lib/features/chat/screens/chat_list_screen.dart
git commit -m "feat: group chat screen + groups section in chat list"
```

---

## Verification Checklist

- [ ] Go builds: `cd go && go build ./...`
- [ ] Go tests pass: `cd go && go test ./internal/...`
- [ ] Flutter analyzes: `cd flutter && flutter analyze`
- [ ] Invite code round-trips: generate → parse → match
- [ ] HKDF hello key: deterministic, 32 bytes
- [ ] Hello encrypt/decrypt: round-trip preserves payload
- [ ] Peer daemon authority: adding peer via gRPC persists, survives restart
- [ ] RemovePeer RPC: removes from daemon map + disk
- [ ] Hello auto-add: Bob enters Alice's code → Alice receives hello → Alice auto-adds Bob
- [ ] Group key encryption: round-trip preserves plaintext
- [ ] Group key rotation: rotated key differs from original, same length
- [ ] CreateGroup: creates group, distributes key to members
- [ ] Group send: message encrypted with group key, sent to all members
- [ ] Group list screen: shows groups, navigate to group chat
- [ ] Create group dialog: name + member picker, calls gRPC
- [ ] Stale hello cleanup: nonces older than 24h auto-removed
