# Relay UI, Federation, TCP Media & DNS Resolver Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add custom relay UI with domain support, client-side relay federation for polling, TCP media proxy on relay server, and custom DNS resolver for domain relay addresses.

**Architecture:** 
- Flutter UI: validate domain:port input, persist relays + DNS resolver to JSON
- Go daemon: domain resolution via custom DNS resolver, poll ALL relays for messages
- Relay server: TCP :9877 for file upload/download, auto-cleanup
- Daemon: upload large files via TCP, small via DNS; download same way

**Tech Stack:** Go 1.26, Flutter/Riverpod, gRPC, protobuf, net/http

## Global Constraints

- DNS resolver default: `8.8.8.8:53`
- Media DNS threshold: 200KB (files larger use TCP)
- File TTL on relay: 7 days
- Relay list persisted to `<dataDir>/relays.json`
- TCP media port on relay: `9877`
- Domain resolution cached per daemon session

---

### Task 1: Flutter AddRelayDialog — domain support + DNS resolver field

**Files:**
- Modify: `flutter/lib/features/relay_config/screens/add_relay_dialog.dart`

**Interfaces:**
- Produces: Validated relay address string (IP:port or domain:port) + optional DNS resolver string (IP:port)

- [ ] **Step 1: Update AddRelayDialog with validation and DNS resolver field**

```dart
import 'package:flutter/material.dart';

class AddRelayDialog extends StatefulWidget {
  const AddRelayDialog({super.key});

  @override
  State<AddRelayDialog> createState() => _AddRelayDialogState();
}

class _AddRelayDialogState extends State<AddRelayDialog> {
  final _relayCtrl = TextEditingController();
  final _dnsCtrl = TextEditingController(text: '8.8.8.8:53');

  @override
  void dispose() {
    _relayCtrl.dispose();
    _dnsCtrl.dispose();
    super.dispose();
  }

  bool _isValidRelayAddress(String addr) {
    // Accept IP:port or domain:port
    final parts = addr.split(':');
    if (parts.length != 2) return false;
    final port = int.tryParse(parts[1]);
    if (port == null || port < 1 || port > 65535) return false;
    return parts[0].isNotEmpty;
  }

  bool _isValidDNSResolver(String addr) {
    if (addr.isEmpty) return true;
    final parts = addr.split(':');
    if (parts.length != 2) return false;
    final port = int.tryParse(parts[1]);
    if (port == null || port < 1 || port > 65535) return false;
    // IP only for DNS resolver
    final ip = parts[0];
    final octets = ip.split('.');
    if (octets.length != 4) return false;
    for (final o in octets) {
      final v = int.tryParse(o);
      if (v == null || v < 0 || v > 255) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Relay'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _relayCtrl,
            decoration: const InputDecoration(
              labelText: 'Relay address (IP:port or domain:port)',
              hintText: '203.0.113.1:53 or relay.example.com:53',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _dnsCtrl,
            decoration: const InputDecoration(
              labelText: 'DNS resolver (IP:port, optional)',
              hintText: '8.8.8.8:53',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_isValidRelayAddress(_relayCtrl.text.trim())) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invalid relay address format')),
              );
              return;
            }
            if (!_isValidDNSResolver(_dnsCtrl.text.trim())) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invalid DNS resolver format')),
              );
              return;
            }
            Navigator.pop(context, {
              'address': _relayCtrl.text.trim(),
              'dnsResolver': _dnsCtrl.text.trim(),
            });
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Test the dialog** (run app, verify validation works)

```bash
flutter run -d 1b9e059eb1d5
```

- [ ] **Step 3: Commit**

```bash
git add flutter/lib/features/relay_config/screens/add_relay_dialog.dart
git commit -m "feat: add domain relay + DNS resolver fields with validation"
```

---

### Task 2: Flutter RelayProvider — persist relays + DNS resolver to JSON

**Files:**
- Modify: `flutter/lib/features/relay_config/providers/relay_provider.dart`

**Interfaces:**
- Consumes: `relays.json` file format: `{"relays": [{"address":"...", "dnsResolver":"..."}], "dnsResolver": "8.8.8.8:53"}`
- Produces: Relay list loaded on startup, saved on add/remove

- [ ] **Step 1: Add relay persistence to relay_provider.dart**

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';
import '../../../shared/constants.dart';

class RelayConfig {
  final String address;
  final String dnsResolver;
  RelayConfig({required this.address, required this.dnsResolver});

  Map<String, dynamic> toJson() => {'address': address, 'dnsResolver': dnsResolver};

  factory RelayConfig.fromJson(Map<String, dynamic> json) => RelayConfig(
    address: json['address'] as String,
    dnsResolver: json['dnsResolver'] as String? ?? '8.8.8.8:53',
  );
}

class RelayList extends Notifier<List<RelayConfig>> {
  static const _fileName = 'relays.json';

  String get _filePath {
    // Use current directory; on Android the working dir is app-specific
    return '${Directory.current.path}/$_fileName';
  }

  @override
  List<RelayConfig> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    try {
      final file = File(_filePath);
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final relays = (json['relays'] as List? ?? [])
            .map((e) => RelayConfig.fromJson(e as Map<String, dynamic>))
            .toList();
        final dnsResolver = json['dnsResolver'] as String? ?? '8.8.8.8:53';
        state = relays;
        _defaultDnsResolver = dnsResolver;
      }
    } catch (e) {
      debugPrint('Failed to load relays: $e');
    }
  }

  Future<void> _save() async {
    try {
      final file = File(_filePath);
      await file.writeAsString(jsonEncode({
        'relays': state.map((r) => r.toJson()).toList(),
        'dnsResolver': _defaultDnsResolver,
      }));
    } catch (e) {
      debugPrint('Failed to save relays: $e');
    }
  }

  String _defaultDnsResolver = '8.8.8.8:53';

  Future<void> addRelay(String address, String dnsResolver) async {
    state = [...state, RelayConfig(address: address, dnsResolver: dnsResolver)];
    await _save();
  }

  Future<void> removeRelay(int index) async {
    state = [...state]..removeAt(index);
    await _save();
  }

  Future<void> setDnsResolver(String dnsResolver) async {
    _defaultDnsResolver = dnsResolver;
    await _save();
  }

  String get defaultDnsResolver => _defaultDnsResolver;
}

final relayProvider = NotifierProvider<RelayList, List<RelayConfig>>(RelayList.new);
```

- [ ] **Step 2: Update RelayConfigScreen to use RelayList**

```dart
// In relay_config_screen.dart, replace statusAsync with:
// final relays = ref.watch(relayProvider);
// final dnsResolver = ref.watch(relayProvider.notifier).defaultDnsResolver;

// Pass to gRPC addRelay/removeRelay and include dnsResolver in method channel
```

- [ ] **Step 3: Commit**

```bash
git add flutter/lib/features/relay_config/providers/relay_provider.dart
git commit -m "feat: persist relay list and DNS resolver to JSON"
```

---

### Task 3: Flutter RelayTile — show reachability indicator

**Files:**
- Modify: `flutter/lib/features/relay_config/widgets/relay_tile.dart`

**Interfaces:**
- Consumes: `RelayStatus` with `reachable` boolean
- Produces: ListTile with green/red dot indicator

- [ ] **Step 1: Update relay_tile.dart**

```dart
import 'package:flutter/material.dart';
import '../../../core/grpc/relay.pb.dart';

class RelayTile extends StatelessWidget {
  final RelayStatus status;
  final VoidCallback onDelete;
  const RelayTile({super.key, required this.status, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: status.reachable ? Colors.green : Colors.red,
        radius: 6,
      ),
      title: Text(status.address),
      subtitle: Text('Latency: ${status.latencyMs}ms • ${status.blackoutMode ? 'Blackout' : 'Normal'}'),
      trailing: IconButton(
        icon: const Icon(Icons.delete),
        onPressed: onDelete,
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add flutter/lib/features/relay_config/widgets/relay_tile.dart
git commit -m "feat: add reachability indicator to relay tile"
```

---

### Task 4: Go DNS Engine — poll ALL relays for messages

**Files:**
- Modify: `go/internal/client/dns_engine.go`

**Interfaces:**
- Consumes: `PollRelays(recipientPubkey string) ([][8]byte, error)`
- Produces: All unique msgIDs from all relays

- [ ] **Step 1: Update PollRelays to iterate all relays**

```go
// PollRelays queries all relays for pending msgIDs for the given recipient pubkey.
func (e *DNSClientEngine) PollRelays(recipientPubkey string) ([][8]byte, error) {
	if recipientPubkey == "" {
		return nil, nil
	}
	relays := e.discoverActiveRelays(nil)
	if len(relays) == 0 {
		return nil, nil
	}

	hash := sha256.Sum256([]byte(recipientPubkey))
	peerID := base32hex.EncodeToString(hash[:])

	var allMsgIDs [][8]byte
	seen := make(map[[8]byte]bool)

	for _, relay := range relays {
		msgIDs, err := pollRelay(relay, peerID, e.zone)
		if err != nil {
			slog.Warn("poll relay failed", "relay", relay, "error", err)
			continue
		}
		for _, id := range msgIDs {
			if !seen[id] {
				seen[id] = true
				allMsgIDs = append(allMsgIDs, id)
			}
		}
	}
	return allMsgIDs, nil
}
```

- [ ] **Step 2: Commit**

```bash
git add go/internal/client/dns_engine.go
git commit -m "fix: poll all relays for messages (client-side federation)"
```

---

### Task 5: Go DNS Engine — add domain resolution via custom DNS resolver

**Files:**
- Modify: `go/internal/client/dns_engine.go`

**Interfaces:**
- Consumes: `dnsResolver string` field, resolves domain:port to IP:port
- Produces: All SendChunk/QueryChunk/PollRelay calls use resolved IP

- [ ] **Step 1: Add dnsResolver field and resolveAddr method**

```go
type DNSClientEngine struct {
	mu             sync.RWMutex
	relays         []string
	fallbackRelays []string
	zone           string
	dnsResolver    string // e.g., "8.8.8.8:53"
}

func NewDNSClientEngine(fallbackRelays []string, zone string) *DNSClientEngine {
	relays := make([]string, len(fallbackRelays))
	copy(relays, fallbackRelays)
	return &DNSClientEngine{
		fallbackRelays: fallbackRelays,
		relays:         relays,
		zone:           zone,
		dnsResolver:    "8.8.8.8:53",
	}
}

func (e *DNSClientEngine) SetDNSResolver(resolver string) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.dnsResolver = resolver
}

// resolveAddr resolves domain:port to IP:port using custom DNS resolver.
// If addr is already IP:port, returns as-is.
func (e *DNSClientEngine) resolveAddr(addr string) (string, error) {
	host, port, err := net.SplitHostPort(addr)
	if err != nil {
		return addr, err
	}
	ip := net.ParseIP(host)
	if ip != nil {
		return addr, nil // already IP
	}
	// Resolve domain via custom DNS resolver
	return e.resolveDomain(host, port)
}

func (e *DNSClientEngine) resolveDomain(domain, port string) (string, error) {
	e.mu.RLock()
	resolver := e.dnsResolver
	e.mu.RUnlock()

	if resolver == "" {
		resolver = "8.8.8.8:53"
	}

	// Simple DNS A record query
	client := &dns.Client{Timeout: 5 * time.Second}
	msg := new(dns.Msg)
	msg.SetQuestion(dns.Fqdn(domain), dns.TypeA)
	msg.RecursionDesired = true

	resp, _, err := client.Exchange(msg, resolver)
	if err != nil {
		return "", fmt.Errorf("dns resolve failed: %w", err)
	}
	if resp.Rcode != dns.RcodeSuccess || len(resp.Answer) == 0 {
		return "", fmt.Errorf("no A record for %s", domain)
	}
	for _, ans := range resp.Answer {
		if a, ok := ans.(*dns.A); ok {
			return net.JoinHostPort(a.A.String(), port), nil
		}
	}
	return "", fmt.Errorf("no A record for %s", domain)
}

// Update sendParallel, sendWithRetry, pollRelay, fetchAndReassemble to call resolveAddr(addr)
```

- [ ] **Step 2: Update all relay call sites to use resolveAddr**

```go
// In sendParallel, sendWithRetry, pollRelay, fetchAndReassemble:
resolved, err := e.resolveAddr(relay)
if err != nil { ... }
```

- [ ] **Step 3: Commit**

```bash
git add go/internal/client/dns_engine.go
git commit -m "feat: add custom DNS resolver for domain relay addresses"
```

---

### Task 6: Go relayd — add TCP :9877 for file upload/download

**Files:**
- Modify: `go/internal/relay/server.go`
- Modify: `go/cmd/relayd/main.go`

**Interfaces:**
- Consumes: `--media-port` flag (default 9877)
- Produces: HTTP server on TCP :9877 with /upload and /download/:fileID

- [ ] **Step 1: Add HTTP file handler to relay server**

```go
import (
	"crypto/sha256"
	"encoding/hex"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func RunServer(addr, zone string, s *store.ChunkStore, rl *ratelimit.IPRateLimiter, mediaPort string) error {
	// ... existing DNS server ...

	// HTTP media server
	if mediaPort != "" {
		mediaDir := filepath.Join(os.Getenv("HOME"), ".config", "relayd", "media")
		os.MkdirAll(mediaDir, 0700)

		http.HandleFunc("/upload", func(w http.ResponseWriter, r *http.Request) {
			if r.Method != http.MethodPost {
				http.Error(w, "POST only", 405)
				return
			}
			data, err := io.ReadAll(r.Body)
			if err != nil {
				http.Error(w, "read failed", 500)
				return
			}
			hash := sha256.Sum256(data)
			fileID := hex.EncodeToString(hash[:])
			os.WriteFile(filepath.Join(mediaDir, fileID), data, 0600)
			w.Header().Set("Content-Type", "application/json")
			w.Write([]byte(`{"file_id":"` + fileID + `"}`))
		})

		http.HandleFunc("/download/", func(w http.ResponseWriter, r *http.Request) {
			fileID := strings.TrimPrefix(r.URL.Path, "/download/")
			mediaDir := filepath.Join(os.Getenv("HOME"), ".config", "relayd", "media")
			path := filepath.Join(mediaDir, fileID)
			if _, err := os.Stat(path); err != nil {
				http.NotFound(w, r)
				return
			}
			http.ServeFile(w, r, path)
		})

		go http.ListenAndServe(":"+mediaPort, nil)
	}

	// ... rest of DNS server
}
```

- [ ] **Step 2: Update main.go to pass --media-port**

```go
// In main.go server command:
mediaPort := flag.String("media-port", "9877", "TCP port for media HTTP server")
flag.Parse()
// ...
RunServer(..., *mediaPort)
```

- [ ] **Step 3: Commit**

```bash
git add go/internal/relay/server.go go/cmd/relayd/main.go
git commit -m "feat: add TCP media proxy on relay server (port 9877)"
```

---

### Task 6: Go daemon — TCP upload/download for large media

**Files:**
- Modify: `go/internal/client/daemon.go`

**Interfaces:**
- Consumes: `mediaPort` from relays, `SendMediaRequest` with transport choice
- Produces: Files > 200KB uploaded via HTTP POST, metadata sent via DNS

- [ ] **Step 1: Update SendMedia to use TCP for large files**

```go
func (d *Daemon) SendMedia(ctx context.Context, req *pb.SendMediaRequest) (*pb.SendMediaResponse, error) {
	// ... existing code ...

	// Choose transport
	useTCP := req.PreferredTransport == pb.SendMediaRequest_TCP ||
		(req.PreferredTransport == pb.SendMediaRequest_AUTO && len(req.MediaData) > media.MediaDNSSizeThreshold)

	if useTCP {
		return d.sendMediaTCP(ctx, req, msgID)
	}
	// ... existing DNS path
}
```

- [ ] **Step 2: Add sendMediaTCP and fetchMediaTCP**

```go
func (d *Daemon) sendMediaTCP(ctx context.Context, req *pb.SendMediaRequest, msgID string) (*pb.SendMediaResponse, error) {
	relays := d.engine.GetRelays()
	if len(relays) == 0 {
		return nil, fmt.Errorf("no relays")
	}
	// Try each relay
	for _, relay := range relays {
		relayAddr := strings.Split(relay, ":")[0] // strip port
		url := fmt.Sprintf("http://%s:9877/upload", relayAddr)
		resp, err := http.Post(url, "application/octet-stream", bytes.NewReader(req.MediaData))
		if err != nil {
			slog.Warn("TCP upload failed", "relay", relay, "err", err)
			continue
		}
		var result struct{ FileID string }
		json.NewDecoder(resp.Body).Decode(&result)
		return &pb.SendMediaResponse{
			MessageId:       msgID,
			EstimatedSeconds: 10,
			Transport:       "tcp",
		}, nil
	}
	return nil, fmt.Errorf("all relays failed")
}

func (d *Daemon) fetchMediaTCP(ctx context.Context, msgID, fileID, peerPubkey string) ([]byte, error) {
	relays := d.engine.GetRelays()
	for _, relay := range relays {
		relayAddr := strings.Split(relay, ":")[0]
		url := fmt.Sprintf("http://%s:9877/download/%s", relayAddr, fileID)
		resp, err := http.Get(url)
		if err != nil {
			continue
		}
		data, _ := io.ReadAll(resp.Body)
		return data, nil
	}
	return nil, fmt.Errorf("download failed")
}
```

- [ ] **Step 3: Commit**

```bash
git add go/internal/client/daemon.go
git commit -m "feat: TCP media upload/download for large files"
```

---

### Task 7: Flutter go_bridge — pass DNS resolver to daemon

**Files:**
- Modify: `flutter/lib/core/platform/go_bridge.dart`

**Interfaces:**
- Consumes: `dnsResolver` string from RelayProvider
- Produces: Method channel call includes `dnsResolver`

- [ ] **Step 1: Update _startMobileDaemon to pass dnsResolver**

```dart
static Future<void> _startMobileDaemon({
  required int grpcPort,
  required String dataDir,
  required int p2pPort,
  required String bootstrap,
  required String relays,
  required String zone,
}) async {
  final relaysList = ref.read(relayProvider);
  final dnsResolver = ref.read(relayProvider.notifier).defaultDnsResolver;
  // ... method channel call includes 'dnsResolver': dnsResolver
}
```

- [ ] **Step 2: Commit**

```bash
git add flutter/lib/core/platform/go_bridge.dart
git commit -m "feat: pass DNS resolver to native daemon"
```

---

### Task 8: Build, test, commit

- [ ] **Step 1: Build .so for Android**

```bash
cd go/
GOWORK=off GOOS=android GOARCH=arm64 CGO_ENABLED=1 \
  CC=$ANDROID_NDK/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android21-clang \
  go build -buildmode=c-shared -ldflags=-checklinkname=0 \
  -o ../flutter/android/app/src/main/jniLibs/arm64-v8a/libvrgram.so ./mobileso/
```

- [ ] **Step 2: Run flutter app**

```bash
cd ../flutter
flutter run -d 1b9e059eb1d5
```

- [ ] **Step 3: Test features**

```bash
# 1. Add relay with domain: relay.example.com:53
# 2. Set DNS resolver: 8.8.8.8:53
# 3. Verify relay appears with reachability status
# 4. Send small message (<200KB) → goes via DNS
# 5. Send large file (>200KB) → goes via TCP :9877
# 6. Check relays discovered > 0 (federation)
```

- [ ] **Step 4: Commit all**

```bash
git add -A
git commit -m "feat: relay UI, federation, TCP media, DNS resolver complete"
```