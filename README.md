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

`relayd` (single binary) embeds DNS engine + gRPC server.
Flutter auto-starts it.

```
┌──────────┐  gRPC :9877  ┌────────────────────────────────────┐
│  Flutter  │◄────────────►│  relayd (Go)                       │
│  (UI)     │              │  ┌──────────┐                     │
│           │              │  │ DNS eng  │                     │
│           │              │  │ +queue   │                     │
│           │              │  └──────────┘                     │
│           │              │  E2E crypto (X25519+XChaCha20)     │
│           │              │  Media: AES-256-GCM per file       │
└──────────┘              └────────────────────────────────────┘
```

Text messages: DNS TXT chunks via relays.
Small media (< 60 KB): DNS, falls back to TCP on failure.
Large media (>= 60 KB): TCP via relay HTTP media server.

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
