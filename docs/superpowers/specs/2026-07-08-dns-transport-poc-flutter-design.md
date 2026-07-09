# DNS Transport Social Platform — PoC: Flutter Client

## Overview

Cross-platform Flutter client for the relayd DNS transport messaging system.
Connects to the Go transport core via localhost gRPC, using the same protobuf
contract defined in `go/proto/relay.proto`. Go core runs embedded via gomobile
bind on all platforms (Android .aar, iOS .xcframework, Windows shared lib).

## Target Platforms

Android, iOS, Windows — single Flutter codebase. Platform-specific Go
initialization only.

## Architecture

```
Flutter App
├── lib/
│   ├── main.dart                  # App entry, ProviderScope, routing
│   ├── app.dart                   # MaterialApp, theme, navigation
│   ├── core/
│   │   ├── grpc/
│   │   │   ├── client.dart        # gRPC channel + client singleton
│   │   │   └── relay.pb.dart      # Generated proto Dart code
│   │   ├── models/
│   │   │   ├── message.dart       # ChatMessage model
│   │   │   ├── peer.dart          # Peer model (nickname + pubkey)
│   │   │   └── relay_info.dart    # Relay status model
│   │   └── platform/
│   │       └── go_bridge.dart     # Starts Go gRPC server on each platform
│   ├── features/
│   │   ├── chat/
│   │   │   ├── providers/
│   │   │   │   ├── chat_provider.dart
│   │   │   │   └── message_list_provider.dart
│   │   │   ├── screens/
│   │   │   │   ├── chat_list_screen.dart
│   │   │   │   └── chat_screen.dart
│   │   │   └── widgets/
│   │   │       ├── message_bubble.dart
│   │   │       └── chat_input.dart
│   │   ├── peers/
│   │   │   ├── providers/peer_provider.dart
│   │   │   ├── screens/peer_list_screen.dart
│   │   │   └── widgets/peer_tile.dart
│   │   ├── relay_config/
│   │   │   ├── providers/relay_provider.dart
│   │   │   ├── screens/relay_config_screen.dart
│   │   │   └── widgets/relay_tile.dart
│   │   └── identity/
│   │       ├── providers/identity_provider.dart
│   │       └── screens/identity_screen.dart
│   └── shared/
│       ├── widgets/
│       │   ├── loading_indicator.dart
│       │   └── status_badge.dart
│       └── constants.dart         # Colors, strings, config
├── android/
│   └── app/src/main/java/.../MainActivity.java  # GoInit() call
├── ios/
│   └── Runner/AppDelegate.swift                  # GoInit() call
├── windows/
│   └── runner/main.cpp                           # GoInit() call
├── pubspec.yaml
└── proto/                        # Symlink or copy of go/proto/relay.proto
```

## gRPC Integration

### Dart proto generation

```yaml
# pubspec.yaml dependencies
dependencies:
  grpc: ^4.0.0
  protobuf: ^3.0.0
  riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0
  flutter_riverpod: ^2.5.0
  go_router: ^14.0.0
  intl: ^0.19.0
  share_plus: ^9.0.0  # share public key

dev_dependencies:
  build_runner: ^2.4.0
  riverpod_generator: ^2.4.0
  protoc_plugin: ^21.0.0
```

Generate Dart proto:

```bash
cd flutter
protoc --dart_out=lib/core/grpc -I../go/proto ../go/proto/relay.proto
```

### Client singleton

```dart
class GrpcClient {
  static final GrpcClient _instance = GrpcClient._();
  static GrpcClient get instance => _instance;

  late final ClientChannel _channel;
  late final RelayClientClient _stub;

  Future<void> init() async {
    _channel = ClientChannel(
      '127.0.0.1',
      port: 9876,
      transportOptions: const ChannelTransportOptions(
        // Use plaintext — localhost only
        usePlaintext: true,
      ),
    );
    _stub = RelayClientClient(_channel);
  }

  RelayClientClient get stub => _stub;

  Future<void> shutdown() async {
    await _channel.shutdown();
  }
}
```

## Riverpod Providers

### Identity provider

```dart
@riverpod
class Identity extends _$Identity {
  @override
  Future<IdentityInfo> build() async {
    return GrpcClient.instance.stub.getIdentity(Empty());
  }
}
```

### Relay status provider

```dart
@riverpod
Stream<RelayStatusList> relayStatus(Ref ref) async* {
  while (true) {
    final status = await GrpcClient.instance.stub.getRelayStatus(Empty());
    yield status;
    await Future.delayed(const Duration(seconds: 10));
  }
}
```

### Chat provider

```dart
@riverpod
class Chat extends _$Chat {
  @override
  Future<List<ReceivedMessage>> build() async {
    final resp = await GrpcClient.instance.stub.pollMessages(PollRequest());
    return resp.messages;
  }

  Future<SendResponse> sendMessage(String peerPubkey, String text) async {
    return GrpcClient.instance.stub.sendMessage(SendRequest(
      peerPubkey: peerPubkey,
      plaintext: utf8.encode(text),
    ));
  }
}
```

## Go Bridge (Platform Initialization)

### Android (MainActivity)

```java
public class MainActivity extends FlutterActivity {
  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    // Start Go gRPC server in background thread
    new Thread(() -> {
      GoRelayd.startGRPCServer(9876, 
        new String[]{"203.0.113.1"}, "msg.local-domain", true,
        getFilesDir().getAbsolutePath() + "/relayd");
    }).start();
  }

  @Override
  protected void onDestroy() {
    GoRelayd.stopGRPCServer();
    super.onDestroy();
  }
}
```

### iOS (AppDelegate)

```swift
@main
class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    DispatchQueue.global().async {
      let docsDir = FileManager.default.urls(for: .documentDirectory, 
        in: .userDomainMask).first!.path + "/relayd"
      GoRelayd.startGRPCServer(9876, 
        ["203.0.113.1"], "msg.local-domain", true, docsDir)
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### Windows (main.cpp)

```cpp
#include <flutter/dart_plugin_registrant.h>
#include "GoRelayd.h"

int APIENTRY wWinMain() {
  // ... Flutter init ...
  std::thread goThread([]() {
    GoRelayd::StartGRPCServer(9876, {"203.0.113.1"}, "msg.local-domain", true);
  });
  goThread.detach();
  // ... run Flutter ...
}
```

### Dart GoBridge (platform channel abstraction)

```dart
class GoBridge {
  static Future<void> start() async {
    // Platform channel to trigger Go init if needed
    // For PoC, Go init happens in native code before Flutter starts
  }
}
```

## Screens (Detailed)

### Chat List Screen

- Shows list of 1:1 conversations, sorted by most recent message
- Each row: peer nickname, last message preview, timestamp, unread indicator
- Tap → ChatScreen
- FAB → PeerListScreen (to select a peer to message)
- Empty state: "Add a peer to start messaging"

### Chat Screen

- AppBar: peer nickname
- Body: ListView of message bubbles
  - Sent messages: right-aligned, blue/green
  - Received messages: left-aligned, grey
  - Each bubble: text content, timestamp, delivery status (sent/queued/failed)
- Bottom: text input field + send button
- Send: calls ChatProvider.sendMessage()
- Auto-scroll to bottom on new messages
- Poll messages every 5 seconds via gRPC PollMessages

### Peer List Screen

- List of known peers (nickname + public key fingerprint)
- FAB: Add peer dialog (nickname, public key base64)
- Tap: navigate to ChatScreen with that peer
- Swipe to delete peer

### Relay Config Screen

- List of configured relay endpoints
- Each row: address, status badge (online/offline/blackout), latency
- FAB: Add relay dialog (IP:port)
- Swipe to remove relay
- Top banner: blackout mode indicator (red banner if detector reports blackout)

### Identity Screen

- Display own public key (base64, monospace, copy button)
- "Share" button using share_plus
- Key regeneration note: "Regenerating key breaks existing conversations"

## Go Library Modifications (gomobile)

The existing `relayd` client daemon code needs a thin wrapper for gomobile:

```go
// package gomobile

import (
    "path/filepath"
    "github.com/user/dns-transport/internal/client"
)

var daemon *client.Daemon

// StartGRPCServer is called from native code.
// dataDir should be app's private directory (Context.getFilesDir on Android,
// NSDocumentDirectory on iOS, AppData on Windows).
func StartGRPCServer(grpcPort int, relays []string, zone string, forceBlackout bool, dataDir string) {
    go func() {
        err := client.RunDaemon(grpcPort, relays, zone, dataDir, forceBlackout)
        if err != nil {
            log.Fatal(err)
        }
    }()
}

// StopGRPCServer shuts down the gRPC server and cleans up.
func StopGRPCServer() {
    // Signal daemon to stop via context cancellation
    // (implementation TBD — for PoC, process exit suffices)
}
```

Create `go/cmd/gomobile/bridge.go` with this. Build:

```bash
cd go
gomobile bind -target=android/arm64,ios/arm64 \
  -o flutter/android/app/libs/relayd.aar \
  github.com/user/dns-transport/cmd/gomobile

gomobile bind -target=ios/arm64 \
  -o flutter/ios/Runner/relayd.xcframework \
  github.com/user/dns-transport/cmd/gomobile
```

For Windows, build a C shared library:

```bash
cd go
go build -buildmode=c-shared -o flutter/windows/relayd.dll \
  github.com/user/dns-transport/cmd/gomobile
```

## Error Handling

- gRPC connection refused → show "Daemon not running" banner
- gRPC timeout → show "Connection lost" with retry button
- SendMessage returns queued=true → show clock icon, background retry
- SendMessage throws gRPC error → show snackbar with error message

## Out of Scope (PoC)

- Image/file transfer (future)
- Voice/video notes (future)
- Group chat (future)
- Push notifications
- End-to-end read receipts
- Message editing/deletion
- Search

## Dependency Graph

```
flutter_app → grpc (Dart)
           → protobuf (Dart)
           → flutter_riverpod
           → riverpod_annotation
           → go_router
           → intl
           → share_plus
           └── platform channels → gomobile Go library
```

## Testing Strategy

- Unit tests: Riverpod providers (mock gRPC stub)
- Widget tests: ChatScreen, ChatListScreen (with test data)
- Integration test: Full send/receive flow with mock Go daemon
- Platform channels tested via flutter_driver

## Threat Model Note

The Go daemon runs in the same process on mobile. If an attacker gains code
execution in the Flutter process, they can access the Go daemon's gRPC
endpoint on localhost:9876. On rooted/jailbroken devices, the identity key
file at `~/.config/relayd/identity.key` is readable. This is inherent risk
to the platform, not a design flaw.
