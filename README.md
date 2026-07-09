# VRGram

Censorship-resilient P2P messaging over DNS transport with decentralized relay discovery.

## Quick Start (Windows Desktop)

```bash
# Build everything (Go daemon + Flutter app)
build_portable.bat windows

# Run the portable app
flutter\build\windows\x64\runner\Release\vrgram.exe
```

The app auto-starts relayd and connects. No manual daemon setup.

## Manual Build & Run

```bash
# 1. Build Go daemon
cd go && go build ./cmd/relayd/

# 2. Run everything
cd ../flutter && flutter run
```

Flutter's GoBridge auto-finds relayd.exe in `../go/` and spawns it.

## One Binary Architecture

`relayd` (single binary) embeds libp2p + DHT + DNS engine + gRPC server.
Flutter auto-starts it. No separate p2pd process needed anymore.

```
┌──────────┐  gRPC :9877  ┌────────────────────────────────────┐
│  Flutter  │◄────────────►│  relayd (Go)                       │
│  (UI)     │              │  ┌──────────┐  ┌───────────────┐  │
│           │              │  │ DNS eng  │  │ libp2p+DHT    │  │
│           │              │  │ +queue   │  │ +media stream │  │
│           │              │  └──────────┘  └───────────────┘  │
│           │              │  E2E crypto (X25519+XChaCha20)     │
│           │              │  Media: AES-256-GCM per file       │
└──────────┘              └────────────────────────────────────┘
```

Text messages: DNS TXT chunks via DHT-discovered relays.
Small media (< 240 KB): Parallel DNS.
Large media (>= 240 KB): libp2p fast lane.

## Build Variants

```bash
build_portable.bat windows    # Windows portable app
build_portable.bat apk        # Android APK (Go not embedded yet)
build_portable.bat all        # Both
```

## Android

APK builds but Go daemon isn't embedded (requires gomobile setup).
The app opens without relayd — shows "daemon not connected" state.
To embed, see `go/mobile/bridge.go` for gomobile instructions.
