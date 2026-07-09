# gomobile APK Integration Design

**Date:** 2026-07-09
**Goal:** Embed relayd daemon in Android APK via gomobile bind so the Go backend runs in-process on Android.

## Current State

- **Desktop:** Flutter spawns `relayd.exe` subprocess, gRPC on `127.0.0.1:9876`. Works.
- **Android:** APK builds but Go daemon is not embedded. `GoBridge.start()` is no-op on mobile. App shows "daemon not connected".

## Approach: gomobile bind → AAR

Use `go/mobile/bridge.go` (already written) to produce `gomobile.aar`. Wire into Android build. Start daemon from `MainActivity.kt` before Flutter engine loads.

## Changes

### 1. Build gomobile AAR

```bash
cd go/
gomobile bind -target=android -o ../flutter/android/app/libs/gomobile.aar ./mobile/
```

Produces `gomobile.aar` + `gomobile-sources.jar` in `flutter/android/app/libs/`.

### 2. Android build.gradle.kts

- Add `implementation(files("libs/gomobile.aar"))` to dependencies
- Remove `armeabi-v7a` from abiFilters (gomobile targets arm64 by default)
- Remove cmake abiFilters block (no native CMake needed)

### 3. MainActivity.kt

- Import `GoRelayd` (gomobile-generated Java class)
- In `configureFlutterEngine()`, call `GoRelayd.startDaemon(...)` before `super.configureFlutterEngine()`
- Parameters: `grpcPort=9876`, `relays=""`, `zone="msg.local-domain"`, `forceBlackout="false"`, `dataDir=<filesDir>`, `p2pPort=4001`, `bootstrapAddrs=""`
- Keep existing `getDataDir` MethodChannel handler

### 4. go_bridge.dart

- Remove `if (isDesktop)` guard on `_waitForGRPC()` — wait on all platforms
- On mobile, `GoBridge.start()` skips daemon spawn (native code handles it), but now waits for gRPC readiness

### 5. AndroidManifest.xml

- Add `<uses-permission android:name="android.permission.INTERNET" />`

### 6. build_portable.bat

- Add gomobile bind step before `flutter build apk`
- Requires: Go, gomobile, Android NDK with arm64 clang

## Data Flow

```
App launch → MainActivity.configureFlutterEngine()
  → GoRelayd.startDaemon(9876, relays, zone, false, filesDir, 4001, "")
  → Go runtime starts daemon goroutine (gRPC + p2p + DNS)
  → Flutter engine loads → GoBridge.start() → _waitForGRPC(9876)
  → GrpcClient connects to 127.0.0.1:9876
```

## Scope

- In-process daemon lifetime (app foreground only, no foreground service)
- Desktop flow unchanged
- gRPC protocol unchanged
- All Dart business logic unchanged

## Files Modified

| File | Change |
|------|--------|
| `flutter/android/app/libs/gomobile.aar` | New (built artifact) |
| `flutter/android/app/build.gradle.kts` | Add AAR dep, fix abiFilters |
| `flutter/android/app/src/main/kotlin/.../MainActivity.kt` | Start GoRelayd |
| `flutter/android/app/src/main/AndroidManifest.xml` | Add INTERNET permission |
| `flutter/lib/core/platform/go_bridge.dart` | Wait for gRPC on mobile |
| `build_portable.bat` | Add gomobile bind step |
