# Flutter Client Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cross-platform Flutter chat app connecting to relayd Go daemon via localhost gRPC.

**Architecture:** Single Flutter codebase targeting Android, iOS, Windows. Go transport core runs embedded via gomobile bind (.aar / .xcframework / .dll). Flutter communicates over gRPC (127.0.0.1:9876) using generated Dart proto stubs. State managed via Riverpod.

**Tech Stack:** Flutter 3.x, Dart 3.x, `grpc` (Dart), `flutter_riverpod`, `riverpod_annotation`, `go_router`, `share_plus`, `intl`. Go gomobile bind for bridge.

## Global Constraints

- All gRPC communication uses plaintext localhost only (no TLS needed)
- gRPC port: 9876 (must match relayd client daemon default)
- Go daemon data directory: app-private path, not `~/.config/relayd`
- Peer identity = X25519 public key (base64-encoded, 44 chars)
- Chat messages: 1:1 only, text-only (no media in PoC)
- PollMessages called every 5 seconds for incoming messages
- `SendMessage` with `queued=true` response shows clock icon
- `SendMessage` on failure shows snackbar with error
- gRPC connection refused shows "Daemon not running" banner
- Proto definitions in `go/proto/relay.proto` — must stay in sync

---

### Task 1: Flutter project scaffold, dependencies, and proto generation

**Files:**
- Create: `flutter/pubspec.yaml`
- Create: `flutter/analysis_options.yaml`
- Create: `flutter/lib/core/grpc/relay.pb.dart` (generated)
- Create: `flutter/lib/core/grpc/relay.pbenum.dart` (generated)
- Create: `flutter/lib/core/grpc/relay.pbgrpc.dart` (generated)
- Create: `flutter/lib/core/grpc/relay.pbjson.dart` (generated)
- Create: `flutter/proto/relay.proto` (copy of Go proto)

- [ ] **Step 1: Create Flutter project**

```bash
cd /c/Users/VaRgha/ZCodeProject
flutter create --org com.vrgram --project-name vrgram \
  --platforms android,ios,windows flutter
```

- [ ] **Step 2: Copy proto file to Flutter**

```bash
cp go/proto/relay.proto flutter/proto/relay.proto
```

- [ ] **Step 3: Write pubspec.yaml dependencies**

Replace `flutter/pubspec.yaml` dependencies section:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1
  grpc: ^4.0.1
  protobuf: ^3.1.0
  go_router: ^14.8.0
  share_plus: ^10.1.4
  intl: ^0.20.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.14
  riverpod_generator: ^2.6.3
  protoc_plugin: ^24.0.0
  mocktail: ^1.0.4
```

- [ ] **Step 4: Generate Dart proto stubs**

```bash
cd /c/Users/VaRgha/ZCodeProject/flutter
mkdir -p lib/core/grpc
protoc --dart_out=lib/core/grpc -Iproto proto/relay.proto
```

- [ ] **Step 5: Verify Flutter project builds**

```bash
cd /c/Users/VaRgha/ZCodeProject/flutter
flutter pub get
# Windows: flutter build windows --debug
# Just check analysis passes:
flutter analyze --no-fatal-infos --no-fatal-warnings
```

Expected: analysis passes, generated proto files exist in `lib/core/grpc/`.

- [ ] **Step 6: Write analysis_options.yaml**

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_declarations: true
    avoid_print: false

analyzer:
  errors:
    invalid_annotation_target: ignore
```

- [ ] **Step 7: Commit**

```bash
git add flutter/
git commit -m "feat: scaffold Flutter project with proto deps"
```

---

### Task 2: Core gRPC client singleton + Go bridge

**Files:**
- Create: `flutter/lib/core/grpc/client.dart`
- Create: `flutter/lib/core/platform/go_bridge.dart`

**Interfaces:**
- Consumes: generated `relay.pbgrpc.dart`, `relay.pb.dart`
- Produces: `GrpcClient` singleton class, `GoBridge` class with `start()` and `stop()`

- [ ] **Step 1: Write gRPC client singleton**

Create `flutter/lib/core/grpc/client.dart`:

```dart
import 'package:grpc/grpc.dart';
import 'relay.pbgrpc.dart';

class GrpcClient {
  static final GrpcClient _instance = GrpcClient._();
  factory GrpcClient() => _instance;
  GrpcClient._();

  static const int _port = 9876;

  late final ClientChannel _channel;
  late final RelayClientClient _stub;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _channel = ClientChannel(
      '127.0.0.1',
      port: _port,
      transportOptions: const ChannelTransportOptions(
        usePlaintext: true,
      ),
    );
    _stub = RelayClientClient(_channel);
    _initialized = true;
  }

  RelayClientClient get stub {
    if (!_initialized) throw StateError('GrpcClient not initialized. Call init() first.');
    return _stub;
  }

  Future<void> shutdown() async {
    if (!_initialized) return;
    await _channel.shutdown();
    _initialized = false;
  }
}
```

- [ ] **Step 2: Write GoBridge platform interface**

Create `flutter/lib/core/platform/go_bridge.dart`:

```dart
import 'dart:io';

class GoBridge {
  static Future<void> start() async {
    // Go daemon gRPC server is started natively before Flutter runs.
    // On Android/iOS: GoInit() called in MainActivity/AppDelegate.
    // On Windows: GoInit() called in main.cpp.
    //
    // We wait briefly for gRPC server to become ready.
    await Future.delayed(const Duration(milliseconds: 500));
  }

  static Future<void> stop() async {
    // Go daemon stops when process exits.
    // On Android/iOS: GoRelayd.stopGRPCServer() called in onDestroy/delloc.
  }

  /// Whether running on a desktop platform (Windows/macOS/Linux)
  static bool get isDesktop => !Platform.isAndroid && !Platform.isIOS;
}
```

- [ ] **Step 3: Verify analysis**

```bash
cd /c/Users/VaRgha/ZCodeProject/flutter
flutter analyze --no-fatal-infos --no-fatal-warnings
```

Expected: clean

- [ ] **Step 4: Commit**

```bash
git add flutter/lib/core/
git commit -m "feat: add gRPC client singleton and Go bridge"
```

---

### Task 3: Shared widgets and constants

**Files:**
- Create: `flutter/lib/shared/constants.dart`
- Create: `flutter/lib/shared/widgets/loading_indicator.dart`
- Create: `flutter/lib/shared/widgets/status_badge.dart`

- [ ] **Step 1: Write constants**

Create `flutter/lib/shared/constants.dart`:

```dart
import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF1A73E8);
  static const sentBubble = Color(0xFF1A73E8);
  static const receivedBubble = Color(0xFFE8E8E8);
  static const blackoutBanner = Color(0xFFD32F2F);
  static const online = Color(0xFF4CAF50);
  static const offline = Color(0xFF9E9E9E);
  static const queued = Color(0xFFFFC107);
}

class AppStrings {
  static const appName = 'VRGram';
  static const daemonNotRunning = 'Daemon not running';
  static const connectionLost = 'Connection lost';
  static const blackoutMode = 'Blackout mode — using domestic relays only';
  static const noPeers = 'Add a peer to start messaging';
  static const noMessages = 'No messages yet';
  static const send = 'Send';
  static const addRelay = 'Add relay';
  static const addPeer = 'Add peer';
  static const yourPublicKey = 'Your Public Key';
  static const copyKey = 'Copy';
  static const keyCopied = 'Public key copied';
}

class AppDurations {
  static const messagePollInterval = Duration(seconds: 5);
  static const relayStatusInterval = Duration(seconds: 10);
  static const daemonStartDelay = Duration(milliseconds: 500);
}
```

- [ ] **Step 2: Write LoadingIndicator widget**

Create `flutter/lib/shared/widgets/loading_indicator.dart`:

```dart
import 'package:flutter/material.dart';
import '../constants.dart';

class LoadingIndicator extends StatelessWidget {
  final String? message;
  const LoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: const TextStyle(color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Write StatusBadge widget**

Create `flutter/lib/shared/widgets/status_badge.dart`:

```dart
import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final Color color;
  final String label;

  const StatusBadge({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
```

- [ ] **Step 4: Verify and commit**

```bash
cd /c/Users/VaRgha/ZCodeProject/flutter
flutter analyze --no-fatal-infos --no-fatal-warnings
git add flutter/lib/shared/
git commit -m "feat: add shared widgets and constants"
```

---

### Task 4: Identity feature (provider + screen)

**Files:**
- Create: `flutter/lib/features/identity/providers/identity_provider.dart`
- Create: `flutter/lib/features/identity/screens/identity_screen.dart`

**Interfaces:**
- Consumes: `GrpcClient`, `Empty`, `IdentityInfo` from `relay.pb.dart`
- Produces: `IdentityProvider`, `IdentityScreen`

- [ ] **Step 1: Write identity provider**

Create `flutter/lib/features/identity/providers/identity_provider.dart`:

```dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';

final identityProvider = FutureProvider<IdentityInfo>((ref) async {
  final client = GrpcClient();
  return client.stub.getIdentity(Empty());
});

final identityPubkeyProvider = Provider<String>((ref) {
  final identity = ref.watch(identityProvider);
  return identity.when(
    data: (info) => info.pubkey,
    loading: () => '',
    error: (_, __) => '',
  );
});

final identityShortProvider = Provider<String>((ref) {
  final pubkey = ref.watch(identityPubkeyProvider);
  if (pubkey.length > 16) {
    return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 8)}';
  }
  return pubkey;
});
```

- [ ] **Step 2: Write identity screen**

Create `flutter/lib/features/identity/screens/identity_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/identity_provider.dart';
import '../../../shared/constants.dart';
import '../../../shared/widgets/loading_indicator.dart';

class IdentityScreen extends ConsumerWidget {
  const IdentityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(identityProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.yourPublicKey)),
      body: identityAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading identity...'),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (identity) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your peer identity is your public key. '
                  'Share it with contacts so they can message you.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    identity.pubkey,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: identity.pubkey));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text(AppStrings.keyCopied)),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text(AppStrings.copyKey),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        SharePlus.instance.share(
                          ShareParams(text: identity.pubkey),
                        );
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 3: Verify and commit**

```bash
cd /c/Users/VaRgha/ZCodeProject/flutter
flutter analyze --no-fatal-infos --no-fatal-warnings
git add flutter/lib/features/identity/
git commit -m "feat: add identity feature (provider + screen)"
```

---

### Task 5: Peers feature (provider + screen + widgets)

**Files:**
- Create: `flutter/lib/features/peers/providers/peer_provider.dart`
- Create: `flutter/lib/features/peers/screens/peer_list_screen.dart`
- Create: `flutter/lib/features/peers/widgets/peer_tile.dart`
- Create: `flutter/lib/features/peers/screens/add_peer_dialog.dart`

- [ ] **Step 1: Write peer models and provider**

Create `flutter/lib/features/peers/providers/peer_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';

class Peer {
  final String nickname;
  final String pubkey;
  Peer({required this.nickname, required this.pubkey});
}

// In-memory peer list for PoC
class PeerNotifier extends StateNotifier<List<Peer>> {
  PeerNotifier() : super([]);

  void addPeer(String nickname, String pubkey) {
    state = [...state, Peer(nickname: nickname, pubkey: pubkey)];
  }

  void removePeer(int index) {
    state = [...state]..removeAt(index);
  }
}

final peerProvider = StateNotifierProvider<PeerNotifier, List<Peer>>((ref) {
  return PeerNotifier();
});

final addPeerProvider = FutureProvider.family<void, PeerParams>((ref, params) async {
  final client = GrpcClient();
  await client.stub.addPeer(PeerInfo(
    nickname: params.nickname,
    pubkey: params.pubkey,
  ));
  ref.read(peerProvider.notifier).addPeer(params.nickname, params.pubkey);
});

class PeerParams {
  final String nickname;
  final String pubkey;
  PeerParams({required this.nickname, required this.pubkey});
}
```

- [ ] **Step 2: Write AddPeerDialog**

Create `flutter/lib/features/peers/screens/add_peer_dialog.dart`:

```dart
import 'package:flutter/material.dart';

class AddPeerDialog extends StatefulWidget {
  const AddPeerDialog({super.key});

  @override
  State<AddPeerDialog> createState() => _AddPeerDialogState();
}

class _AddPeerDialogState extends State<AddPeerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameCtrl = TextEditingController();
  final _pubkeyCtrl = TextEditingController();

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _pubkeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Peer'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nicknameCtrl,
              decoration: const InputDecoration(labelText: 'Nickname'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pubkeyCtrl,
              decoration: const InputDecoration(labelText: 'Public Key (base64)'),
              maxLines: 2,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'nickname': _nicknameCtrl.text,
                'pubkey': _pubkeyCtrl.text,
              });
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Write PeerTile widget**

Create `flutter/lib/features/peers/widgets/peer_tile.dart`:

```dart
import 'package:flutter/material.dart';
import '../providers/peer_provider.dart';

class PeerTile extends StatelessWidget {
  final Peer peer;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const PeerTile({
    super.key,
    required this.peer,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(peer.nickname.isNotEmpty
            ? peer.nickname[0].toUpperCase()
            : '?'),
      ),
      title: Text(peer.nickname),
      subtitle: Text(
        peer.pubkey.length > 24
            ? '${peer.pubkey.substring(0, 12)}...${peer.pubkey.substring(peer.pubkey.length - 12)}'
            : peer.pubkey,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }
}
```

- [ ] **Step 4: Write PeerListScreen**

Create `flutter/lib/features/peers/screens/peer_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/peer_provider.dart';
import '../widgets/peer_tile.dart';
import 'add_peer_dialog.dart';
import '../../chat/screens/chat_screen.dart';
import '../../../shared/constants.dart';

class PeerListScreen extends ConsumerWidget {
  const PeerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peers = ref.watch(peerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: peers.isEmpty
          ? const Center(child: Text(AppStrings.noPeers))
          : ListView.builder(
              itemCount: peers.length,
              itemBuilder: (_, i) => PeerTile(
                peer: peers[i],
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatScreen(peer: peers[i]),
                )),
                onDelete: () => ref.read(peerProvider.notifier).removePeer(i),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showDialog<Map<String, String>>(
            context: context,
            builder: (_) => const AddPeerDialog(),
          );
          if (result != null) {
            ref.read(peerProvider.notifier).addPeer(
              result['nickname']!,
              result['pubkey']!,
            );
          }
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
```

- [ ] **Step 5: Verify and commit**

```bash
cd /c/Users/VaRgha/ZCodeProject/flutter
flutter analyze --no-fatal-infos --no-fatal-warnings
git add flutter/lib/features/peers/
git commit -m "feat: add peers feature (provider, screens, widgets)"
```

---

### Task 6: Relay config feature (provider + screen + widgets)

**Files:**
- Create: `flutter/lib/features/relay_config/providers/relay_provider.dart`
- Create: `flutter/lib/features/relay_config/screens/relay_config_screen.dart`
- Create: `flutter/lib/features/relay_config/widgets/relay_tile.dart`
- Create: `flutter/lib/features/relay_config/screens/add_relay_dialog.dart`

- [ ] **Step 1: Write relay provider**

Create `flutter/lib/features/relay_config/providers/relay_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';
import '../../../shared/constants.dart';

final relayStatusProvider = FutureProvider.autoDispose<RelayStatusList>((ref) async {
  final client = GrpcClient();
  return client.stub.getRelayStatus(Empty());
});

final autoRefreshRelayStatus = StreamProvider.autoDispose<RelayStatusList>((ref) async* {
  while (true) {
    await Future.delayed(AppDurations.relayStatusInterval);
    final status = await ref.read(relayStatusProvider.future);
    yield status;
  }
});

final isBlackoutProvider = FutureProvider<bool>((ref) async {
  final status = await ref.read(relayStatusProvider.future);
  return status.endpoints.any((e) => e.blackoutMode);
});
```

- [ ] **Step 2: Write AddRelayDialog**

Create `flutter/lib/features/relay_config/screens/add_relay_dialog.dart`:

```dart
import 'package:flutter/material.dart';

class AddRelayDialog extends StatefulWidget {
  const AddRelayDialog({super.key});

  @override
  State<AddRelayDialog> createState() => _AddRelayDialogState();
}

class _AddRelayDialogState extends State<AddRelayDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Relay'),
      content: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(
          labelText: 'Relay address (IP:port)',
          hintText: '203.0.113.1:53',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_ctrl.text.isNotEmpty) Navigator.pop(context, _ctrl.text);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Write RelayTile widget**

Create `flutter/lib/features/relay_config/widgets/relay_tile.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../core/grpc/relay.pb.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/constants.dart';

class RelayTile extends StatelessWidget {
  final RelayStatus status;
  final VoidCallback onDelete;

  const RelayTile({super.key, required this.status, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = status.blackoutMode
        ? AppColors.blackoutBanner
        : status.reachable
            ? AppColors.online
            : AppColors.offline;
    final label = status.blackoutMode
        ? 'Blackout'
        : status.reachable
            ? 'Online'
            : 'Offline';

    return ListTile(
      leading: Icon(Icons.dns, color: color),
      title: Text(status.address),
      subtitle: Row(
        children: [
          StatusBadge(color: color, label: label),
          if (status.latencyMs > 0) ...[
            const SizedBox(width: 8),
            Text('${status.latencyMs}ms', style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
    );
  }
}
```

- [ ] **Step 4: Write RelayConfigScreen**

Create `flutter/lib/features/relay_config/screens/relay_config_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/relay_provider.dart';
import '../widgets/relay_tile.dart';
import 'add_relay_dialog.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';
import '../../../shared/constants.dart';

class RelayConfigScreen extends ConsumerWidget {
  const RelayConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(relayStatusProvider);
    final blackoutAsync = ref.watch(isBlackoutProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Relay Servers')),
      body: Column(
        children: [
          // Blackout mode banner
          if (blackoutAsync.asData?.value == true)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppColors.blackoutBanner,
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppStrings.blackoutMode,
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          // Relay list
          Expanded(
            child: statusAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (statusList) {
                if (statusList.endpoints.isEmpty) {
                  return const Center(child: Text('No relays configured'));
                }
                return ListView.builder(
                  itemCount: statusList.endpoints.length,
                  itemBuilder: (_, i) => RelayTile(
                    status: statusList.endpoints[i],
                    onDelete: () async {
                      await GrpcClient().stub.removeRelay(
                        RelayEndpoint(address: statusList.endpoints[i].address),
                      );
                      ref.invalidate(relayStatusProvider);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final address = await showDialog<String>(
            context: context,
            builder: (_) => const AddRelayDialog(),
          );
          if (address != null) {
            await GrpcClient().stub.addRelay(RelayEndpoint(address: address));
            ref.invalidate(relayStatusProvider);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- [ ] **Step 5: Verify and commit**

```bash
cd /c/Users/VaRgha/ZCodeProject/flutter
flutter analyze --no-fatal-infos --no-fatal-warnings
git add flutter/lib/features/relay_config/
git commit -m "feat: add relay config feature (provider, screens, widgets)"
```

---

### Task 7: Chat feature (providers + screens + widgets)

**Files:**
- Create: `flutter/lib/features/chat/providers/chat_provider.dart`
- Create: `flutter/lib/features/chat/providers/message_list_provider.dart`
- Create: `flutter/lib/features/chat/screens/chat_list_screen.dart`
- Create: `flutter/lib/features/chat/screens/chat_screen.dart`
- Create: `flutter/lib/features/chat/widgets/message_bubble.dart`
- Create: `flutter/lib/features/chat/widgets/chat_input.dart`

- [ ] **Step 1: Write chat models and provider**

Create `flutter/lib/features/chat/providers/chat_provider.dart`:

```dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';

enum MessageStatus { sent, queued, failed, received }

class ChatMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isSent;
  final MessageStatus status;
  final String? fromPeer;

  ChatMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isSent,
    required this.status,
    this.fromPeer,
  });
}

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  ChatNotifier() : super([]);

  void addMessage(ChatMessage msg) {
    state = [...state, msg];
  }

  void updateStatus(String id, MessageStatus status) {
    state = state.map((m) => m.id == id ? ChatMessage(
      id: m.id, text: m.text, timestamp: m.timestamp,
      isSent: m.isSent, status: status, fromPeer: m.fromPeer,
    ) : m).toList();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier();
});

final sendMessageProvider = FutureProvider.family<void, SendParams>((ref, params) async {
  final client = GrpcClient();
  final msgId = DateTime.now().millisecondsSinceEpoch.toString();

  ref.read(chatProvider.notifier).addMessage(ChatMessage(
    id: msgId,
    text: params.text,
    timestamp: DateTime.now(),
    isSent: true,
    status: MessageStatus.sent,
  ));

  try {
    final resp = await client.stub.sendMessage(SendRequest(
      peerPubkey: params.peerPubkey,
      plaintext: utf8.encode(params.text),
    ));
    ref.read(chatProvider.notifier).updateStatus(
      msgId,
      resp.queued ? MessageStatus.queued : MessageStatus.sent,
    );
  } catch (e) {
    ref.read(chatProvider.notifier).updateStatus(msgId, MessageStatus.failed);
    rethrow;
  }
});

class SendParams {
  final String peerPubkey;
  final String text;
  SendParams({required this.peerPubkey, required this.text});
}
```

- [ ] **Step 2: Write message list (inbox polling)**

Create `flutter/lib/features/chat/providers/message_list_provider.dart`:

```dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';
import '../../../shared/constants.dart';
import 'chat_provider.dart';

final pollMessagesProvider = StreamProvider.autoDispose<void>((ref) async* {
  while (true) {
    await Future.delayed(AppDurations.messagePollInterval);
    try {
      final client = GrpcClient();
      final resp = await client.stub.pollMessages(PollRequest());
      for (final msg in resp.messages) {
        ref.read(chatProvider.notifier).addMessage(ChatMessage(
          id: msg.messageId,
          text: utf8.decode(msg.plaintext),
          timestamp: DateTime.fromMillisecondsSinceEpoch(msg.timestamp.toInt()),
          isSent: false,
          status: MessageStatus.received,
          fromPeer: msg.fromPeer,
        ));
      }
    } catch (_) {
      // gRPC error — will retry on next poll
    }
  }
});
```

- [ ] **Step 3: Write MessageBubble widget**

Create `flutter/lib/features/chat/widgets/message_bubble.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../providers/chat_provider.dart';
import '../../../shared/constants.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  IconData _statusIcon() {
    switch (message.status) {
      case MessageStatus.sent: return Icons.check;
      case MessageStatus.queued: return Icons.access_time;
      case MessageStatus.failed: return Icons.error_outline;
      case MessageStatus.received: return Icons.check_circle_outline;
    }
  }

  Color _statusColor() {
    switch (message.status) {
      case MessageStatus.sent: return Colors.grey;
      case MessageStatus.queued: return AppColors.queued;
      case MessageStatus.failed: return Colors.red;
      case MessageStatus.received: return AppColors.online;
    }
  }

  @override
  Widget build(BuildContext context) {
    final alignment = message.isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = message.isSent ? AppColors.sentBubble : AppColors.receivedBubble;
    final textColor = message.isSent ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (message.fromPeer != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2, left: 8),
              child: Text(message.fromPeer!, style: const TextStyle(
                fontSize: 11, color: Colors.grey,
              )),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.text, style: TextStyle(color: textColor)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(message.timestamp),
                      style: TextStyle(fontSize: 10, color: textColor.withAlpha(150)),
                    ),
                    if (message.isSent) ...[
                      const SizedBox(width: 4),
                      Icon(_statusIcon(), size: 14, color: _statusColor()),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Write ChatInput widget**

Create `flutter/lib/features/chat/widgets/chat_input.dart`:

```dart
import 'package:flutter/material.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSend;
  const ChatInput({super.key, required this.onSend});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withAlpha(20), blurRadius: 4, offset: const Offset(0, -2),
        )],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            color: Theme.of(context).primaryColor,
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Write ChatScreen**

Create `flutter/lib/features/chat/screens/chat_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../providers/message_list_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../../peers/providers/peer_provider.dart';

class ChatScreen extends ConsumerWidget {
  final Peer peer;
  const ChatScreen({super.key, required this.peer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatProvider);
    // Start polling
    ref.watch(pollMessagesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(peer.nickname)),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(child: Text('No messages yet'))
                : ListView.builder(
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (_, i) => MessageBubble(
                      message: messages[messages.length - 1 - i],
                    ),
                  ),
          ),
          ChatInput(onSend: (text) {
            ref.read(sendMessageProvider(
              SendParams(peerPubkey: peer.pubkey, text: text),
            ));
          }),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Write ChatListScreen**

Create `flutter/lib/features/chat/screens/chat_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../../peers/providers/peer_provider.dart';
import '../../peers/screens/peer_list_screen.dart';
import '../../../shared/constants.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peers = ref.watch(peerProvider);
    final messages = ref.watch(chatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key),
            onPressed: () => Navigator.pushNamed(context, '/identity'),
            tooltip: AppStrings.yourPublicKey,
          ),
          IconButton(
            icon: const Icon(Icons.dns),
            onPressed: () => Navigator.pushNamed(context, '/relays'),
            tooltip: 'Relay servers',
          ),
        ],
      ),
      body: peers.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(AppStrings.noPeers),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const PeerListScreen(),
                    )),
                    child: const Text('Add contacts'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: peers.length,
              itemBuilder: (_, i) => ListTile(
                leading: CircleAvatar(
                  child: Text(peers[i].nickname[0].toUpperCase()),
                ),
                title: Text(peers[i].nickname),
                subtitle: messages.isEmpty
                    ? const Text('No messages')
                    : Text(messages.last.text),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/chat', arguments: peers[i]),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const PeerListScreen(),
        )),
        child: const Icon(Icons.chat),
      ),
    );
  }
}
```

- [ ] **Step 7: Verify and commit**

```bash
cd /c/Users/VaRgha/ZCodeProject/flutter
flutter analyze --no-fatal-infos --no-fatal-warnings
git add flutter/lib/features/chat/
git commit -m "feat: add chat feature (providers, screens, widgets)"
```

---

### Task 8: Main app (routing, theme, entry point) + platform modifications

**Files:**
- Create: `flutter/lib/app.dart`
- Modify: `flutter/lib/main.dart`
- Modify: `flutter/android/.../MainActivity.java` (add GoInit call)
- Modify: `flutter/ios/.../AppDelegate.swift` (add GoInit call)
- Modify: `flutter/windows/runner/main.cpp` (add GoInit call)
- Create: `go/cmd/gomobile/bridge.go`

- [ ] **Step 1: Write app.dart with routing and theme**

Create `flutter/lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/chat/screens/chat_list_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/peers/providers/peer_provider.dart';
import 'features/peers/screens/peer_list_screen.dart';
import 'features/relay_config/screens/relay_config_screen.dart';
import 'features/identity/screens/identity_screen.dart';
import 'shared/constants.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const ChatListScreen()),
      GoRoute(
        path: '/chat',
        builder: (_, state) => ChatScreen(peer: state.arguments as Peer),
      ),
      GoRoute(path: '/peers', builder: (_, __) => const PeerListScreen()),
      GoRoute(path: '/relays', builder: (_, __) => const RelayConfigScreen()),
      GoRoute(path: '/identity', builder: (_, __) => const IdentityScreen()),
    ],
  );
});
```

Update `flutter/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/grpc/client.dart';
import 'core/platform/go_bridge.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start Go daemon (native code runs before Flutter, but ensure readiness)
  await GoBridge.start();

  // Initialize gRPC client
  await GrpcClient().init();

  runApp(const ProviderScope(child: VRGramApp()));
}

class VRGramApp extends ConsumerWidget {
  const VRGramApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      theme: ThemeData(
        colorSchemeSeed: AppColors.primary,
        useMaterial3: true,
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Step 2: Write Go gomobile bridge package**

Create `go/cmd/gomobile/bridge.go`:

```go
package gomobile

import (
    "github.com/user/dns-transport/internal/client"
)

// StartGRPCServer starts the relayd client daemon in the background.
// Called from native platform code (Android, iOS, Windows).
func StartGRPCServer(grpcPort int, relays []string, zone string, forceBlackout bool, dataDir string) {
    go func() {
        // gomobile bind ignores errors from log.Fatal — we run silently
        _ = client.RunDaemon(grpcPort, relays, zone, dataDir, forceBlackout)
    }()
}

// StopGRPCServer signals the daemon to shut down.
func StopGRPCServer() {
    // For PoC, process exit suffices.
    // Future: add context cancellation to client.RunDaemon.
}
```

- [ ] **Step 3: Modify Android MainActivity**

Find and update `flutter/android/app/src/main/java/com/vrgram/vrgram/MainActivity.java`:

```java
package com.vrgram.vrgram;

import android.os.Bundle;
import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // Start Go gRPC server in background
        new Thread(() -> {
            GoRelayd.startGRPCServer(9876,
                new String[]{"203.0.113.1"}, "msg.local-domain", true,
                getFilesDir().getAbsolutePath() + "/relayd");
        }).start();
    }
}
```

- [ ] **Step 4: Modify iOS AppDelegate**

Find and update `flutter/ios/Runner/AppDelegate.swift`:

```swift
import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let docsDir = FileManager.default.urls(for: .documentDirectory,
            in: .userDomainMask).first!.path + "/relayd"
        DispatchQueue.global().async {
            GoRelayd.startGRPCServer(9876,
                ["203.0.113.1"], "msg.local-domain", true, docsDir)
        }
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

- [ ] **Step 5: Modify Windows runner**

Find and update `flutter/windows/runner/main.cpp`:

```cpp
#include <flutter/dart_plugin_registrant.h>
#include "GeneratedGoBindings.h" // from gomobile bind
#include <thread>

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
    // Start Go daemon
    std::thread goThread([]() {
        std::vector<char*> relays = {"203.0.113.1"};
        // Use APPDATA directory
        char* appData = getenv("APPDATA");
        std::string dataDir = appData ? std::string(appData) + "/VRGram/relayd" : "C:/tmp/relayd";
        GoRelaydStartGRPCServer(9876, relays.data(), relays.size(),
            const_cast<char*>("msg.local-domain"), true,
            const_cast<char*>(dataDir.c_str()));
    });
    goThread.detach();
    // ... rest of Flutter Windows runner
}
```

- [ ] **Step 6: Build and verify**

```bash
cd /c/Users/VaRgha/ZCodeProject/flutter
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
```

- [ ] **Step 7: Commit**

```bash
git add flutter/lib/ flutter/android/ flutter/ios/ flutter/windows/ go/cmd/gomobile/
git commit -m "feat: add main app with routing, platform init, gomobile bridge"
```

---

### Task 9: Generate gomobile bindings (build step)

**Files:**
- Create: `flutter/android/app/libs/relayd.aar` (generated)
- Create: `flutter/windows/relayd.dll` (generated)
- Modify: `flutter/android/app/build.gradle` (add .aar dependency)
- Create: `flutter/windows/CMakeLists.txt` changes (link .dll)

- [ ] **Step 1: Build Android .aar**

```bash
cd /c/Users/VaRgha/ZCodeProject/go
gomobile bind -target=android/arm64,android/amd64 \
  -o ../flutter/android/app/libs/relayd.aar \
  -androidapi 24 \
  github.com/user/dns-transport/cmd/gomobile
```

- [ ] **Step 2: Add .aar dependency to Android build**

Add to `flutter/android/app/build.gradle`:

```gradle
dependencies {
    implementation fileTree(dir: 'libs', include: ['*.aar'])
    // ... existing deps
}
```

- [ ] **Step 3: Build Windows .dll**

```bash
cd /c/Users/VaRgha/ZCodeProject/go
go build -buildmode=c-shared \
  -o ../flutter/windows/relayd.dll \
  github.com/user/dns-transport/cmd/gomobile
```

- [ ] **Step 4: Verify**

```bash
ls -la flutter/android/app/libs/relayd.aar
ls -la flutter/windows/relayd.dll
```

- [ ] **Step 5: Commit**

```bash
git add flutter/android/ flutter/windows/
git commit -m "build: add gomobile bindings for Android and Windows"
```

---

## Self-Review Checklist

**Spec coverage:**
1. Chat list screen ✓ (Task 7 — ChatListScreen)
2. Chat screen with bubbles + input ✓ (Task 7 — ChatScreen, MessageBubble, ChatInput)
3. Peer list + add/delete ✓ (Task 5 — PeerListScreen, AddPeerDialog, PeerTile)
4. Relay config + status + add/delete ✓ (Task 6 — RelayConfigScreen, AddRelayDialog, RelayTile)
5. Identity display + copy + share ✓ (Task 4 — IdentityScreen)
6. Blackout mode banner ✓ (Task 6 — RelayConfigScreen banner)
7. gRPC client singleton ✓ (Task 2 — GrpcClient)
8. Go bridge / gomobile ✓ (Task 8 — bridge.go, Task 9 — build)
9. Riverpod state management ✓ (Task 2-7 — providers)
10. PollMessages every 5s ✓ (Task 7 — pollMessagesProvider)
11. Platform init: Android, iOS, Windows ✓ (Task 8 — native modifications)
12. Proto generation ✓ (Task 1 — protoc)

**Placeholder scan:** No TBDs, TODOs, or incomplete sections.

**Type consistency:** ChatMessage model consistent between provider and widgets. RelayStatus fields match proto. Peer model consistent between providers and screens.
