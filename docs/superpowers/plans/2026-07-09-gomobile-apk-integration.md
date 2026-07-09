# gomobile APK Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Embed relayd daemon in Android APK via gomobile bind so the Go backend runs in-process on Android.

**Architecture:** Build `go/mobile/bridge.go` into `gomobile.aar` via `gomobile bind`. Wire AAR into Android Gradle build. Start daemon from `MainActivity.kt` before Flutter engine loads. Flutter waits for gRPC readiness on all platforms.

**Tech Stack:** Go (gomobile bind), Kotlin (Android), Dart (Flutter), gRPC, Android Gradle

## Global Constraints

- gomobile bind targets `arm64-v8a` only (no `armeabi-v7a`)
- Daemon runs in-process, app lifetime only (no foreground service)
- gRPC port: 9876, p2p port: 4001, zone: `msg.local-domain`
- Desktop flow unchanged — relayd.exe subprocess via `go_bridge.dart`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `flutter/android/app/build.gradle.kts` | Modify | Add AAR dependency, fix ABI filters |
| `flutter/android/app/src/main/AndroidManifest.xml` | Modify | Add INTERNET permission |
| `flutter/android/app/src/main/kotlin/.../MainActivity.kt` | Modify | Start GoRelayd daemon |
| `flutter/lib/core/platform/go_bridge.dart` | Modify | Wait for gRPC on mobile |
| `build_portable.bat` | Modify | Add gomobile bind step |

---

### Task 1: Android build config

**Files:**
- Modify: `flutter/android/app/build.gradle.kts`
- Modify: `flutter/android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Produces: AAR dependency wired, INTERNET permission added, abiFilters set to arm64 only

- [ ] **Step 1: Add INTERNET permission to AndroidManifest.xml**

Add before `<application>` tag:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

- [ ] **Step 2: Update build.gradle.kts**

Replace `android` block's `defaultConfig` and add `dependencies`:

```kotlin
plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.vrgram"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.14206865"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.vrgram"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation(files("libs/gomobile.aar"))
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
```

- [ ] **Step 3: Commit**

```bash
git add flutter/android/app/build.gradle.kts flutter/android/app/src/main/AndroidManifest.xml
git commit -m "feat: wire gomobile AAR into Android build, add INTERNET permission"
```

---

### Task 2: Start GoRelayd in MainActivity

**Files:**
- Modify: `flutter/android/app/src/main/kotlin/com/example/vrgram/MainActivity.kt`

**Interfaces:**
- Consumes: `GoRelayd` class from `gomobile.aar` (gomobile-generated)
- Produces: Daemon starts before Flutter engine loads

- [ ] **Step 1: Update MainActivity.kt**

```kotlin
package com.example.vrgram

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import mobile.GoRelayd

class MainActivity : FlutterActivity() {
    private val CHANNEL = "vrgram/bridge"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Start Go daemon before Flutter engine loads
        val dataDir = applicationContext.filesDir.absolutePath
        GoRelayd.startDaemon(
            9876,                    // grpcPort
            "",                      // relayList (comma-separated, empty = none)
            "msg.local-domain",      // zone
            "false",                 // forceBlackout
            dataDir,                 // dataDir
            4001,                    // p2pPort
            "",                      // bootstrapAddrs
        )

        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDataDir" -> {
                        result.success(dataDir)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add flutter/android/app/src/main/kotlin/com/example/vrgram/MainActivity.kt
git commit -m "feat: start GoRelayd daemon from MainActivity on Android"
```

---

### Task 3: Wait for gRPC on mobile

**Files:**
- Modify: `flutter/lib/core/platform/go_bridge.dart`

**Interfaces:**
- Consumes: `GrpcClient` (unchanged), `GoRelayd` daemon on port 9876
- Produces: gRPC readiness wait on all platforms

- [ ] **Step 1: Update go_bridge.dart**

Replace the `start()` method and remove the desktop-only guard:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';

import '../grpc/relay.pb.dart';
import '../grpc/relay.pbgrpc.dart';

class GoBridge {
  static Process? _process;
  static bool _started = false;

  /// Start the Go daemon and wait for gRPC server to be ready.
  static Future<void> start({
    int grpcPort = 9876,
    String dataDir = '',
    int p2pPort = 4001,
    String bootstrap = '',
    String relays = '',
    String zone = 'msg.local-domain',
  }) async {
    if (_started) return;
    _started = true;

    if (isDesktop) {
      await _startDesktopDaemon(
        grpcPort: grpcPort,
        dataDir: dataDir,
        p2pPort: p2pPort,
        bootstrap: bootstrap,
        relays: relays,
        zone: zone,
      );
    }
    // On mobile, native code (MainActivity) starts the daemon via gomobile
    // before Flutter engine loads. Just wait for gRPC readiness below.

    await _waitForGRPC(grpcPort);
  }

  /// Stop the Go daemon.
  static Future<void> stop() async {
    if (_process != null) {
      _process!.kill();
      await _process!.exitCode;
      _process = null;
    }
    _started = false;
  }

  /// Desktop: spawn relayd as a subprocess.
  static Future<void> _startDesktopDaemon({
    required int grpcPort,
    required String dataDir,
    required int p2pPort,
    required String bootstrap,
    required String relays,
    required String zone,
  }) async {
    // Find relayd binary next to the Flutter executable or in PATH
    final binaryName = Platform.isWindows ? 'relayd.exe' : 'relayd';
    final binaryPath = await _findBinary(binaryName);
    if (binaryPath == null) {
      debugPrint('Warning: relayd binary not found, daemon not started');
      return;
    }

    final args = <String>[
      'client',
      '--grpc-port', grpcPort.toString(),
      '--zone', zone,
      '--p2p-port', p2pPort.toString(),
    ];

    if (dataDir.isNotEmpty) {
      args.addAll(['--data-dir', dataDir]);
    }
    if (bootstrap.isNotEmpty) {
      args.addAll(['--bootstrap', bootstrap]);
    }
    if (relays.isNotEmpty) {
      args.addAll(['--relay', relays]);
    }

    debugPrint('Starting relayd: $binaryPath ${args.join(' ')}');

    try {
      _process = await Process.start(binaryPath, args,
        runInShell: false,
      );
      _process!.stdin.close();
      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((l) => debugPrint('[relayd] $l'));
      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((l) => debugPrint('[relayd:err] $l'));
      _process!.exitCode.then((code) {
        debugPrint('relayd exited with code $code');
        _process = null;
      });
    } catch (e) {
      debugPrint('Failed to start relayd: $e');
    }
  }

  /// Find the relayd binary in common locations.
  static Future<String?> _findBinary(String name) async {
    if (Platform.script.path.isNotEmpty) {
      final dir = File(Platform.script.path).parent.path;
      final localPath = '$dir${Platform.pathSeparator}$name';
      if (await File(localPath).exists()) return localPath;
    }

    final cwdPath = '${Directory.current.path}${Platform.pathSeparator}$name';
    if (await File(cwdPath).exists()) return cwdPath;

    final devPath = '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}go${Platform.pathSeparator}$name';
    if (await File(devPath).exists()) return devPath;

    return null;
  }

  /// Poll gRPC server until it responds.
  static Future<void> _waitForGRPC(int port, {Duration timeout = const Duration(seconds: 30)}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final channel = ClientChannel(
          '127.0.0.1',
          port: port,
          options: ChannelOptions(
            credentials: const ChannelCredentials.insecure(),
          ),
        );
        final stub = RelayClientClient(channel);
        await stub.getIdentity(Empty());
        await channel.shutdown();
        debugPrint('gRPC server ready on port $port');
        return;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    debugPrint('Warning: gRPC server did not become ready within $timeout');
  }

  static bool get isDesktop => !Platform.isAndroid && !Platform.isIOS;
}
```

- [ ] **Step 2: Commit**

```bash
git add flutter/lib/core/platform/go_bridge.dart
git commit -m "feat: wait for gRPC readiness on mobile (not just desktop)"
```

---

### Task 4: Add gomobile build step to build_portable.bat

**Files:**
- Modify: `build_portable.bat`

**Interfaces:**
- Consumes: `go/gomobile.exe`, `go/mobile/bridge.go`
- Produces: `flutter/android/app/libs/gomobile.aar` before APK build

- [ ] **Step 1: Update build_portable.bat**

Replace the `:build_go_android` section and `:build_flutter_apk` section:

```bat
@echo off
REM Build VRGram portable Windows app (relayd + Flutter UI in one package)
REM
REM Prerequisites:
REM   - Go installed and in PATH
REM   - Flutter SDK installed and in PATH
REM   - Android SDK + NDK for APK build (optional)
REM
REM Usage:
REM   build_portable.bat windows    - Build Windows portable app
REM   build_portable.bat apk        - Build Android APK
REM   build_portable.bat all        - Build both

setlocal enabledelayedexpansion

if "%1"=="" (
    echo Usage: build_portable.bat ^<windows^|apk^|all^>
    exit /b 1
)

set PROJECT_DIR=%~dp0
set GO_DIR=%PROJECT_DIR%go
set FLUTTER_DIR=%PROJECT_DIR%flutter

:: --- Build Go relayd binary ---
:build_go
echo === Building relayd (Go) ===
cd /d "%GO_DIR%"
if "%1"=="apk" goto build_go_android
if "%1"=="all" goto build_go_windows

:build_go_windows
echo Target: windows/amd64
go build -o "%FLUTTER_DIR%/build/windows/x64/runner/Release/relayd.exe" ./cmd/relayd/
if %ERRORLEVEL% neq 0 (
    echo ERROR: Go build failed
    exit /b 1
)
echo relayd.exe built successfully
if "%1"=="windows" goto build_flutter_windows
goto build_go_android

:build_go_android
echo Target: android/arm64

REM Cross-compile relayd binary (optional, for res/raw)
set GOOS=android
set GOARCH=arm64
set CGO_ENABLED=0
go build -o "%FLUTTER_DIR%/android/app/src/main/res/raw/relayd_android" ./cmd/relayd/
set GOOS=
set GOARCH=
set CGO_ENABLED=
if %ERRORLEVEL% neq 0 (
    echo WARNING: Go cross-compile for Android failed (optional)
) else (
    echo relayd_android built successfully
)

REM Build gomobile AAR
echo === Building gomobile AAR ===
if not exist "%FLUTTER_DIR%/android/app/libs" mkdir "%FLUTTER_DIR%/android/app/libs"
gomobile bind -target=android -o "%FLUTTER_DIR%/android/app/libs/gomobile.aar" ./mobile/
if %ERRORLEVEL% neq 0 (
    echo ERROR: gomobile bind failed
    echo Ensure gomobile is installed and Android NDK is configured.
    exit /b 1
)
echo gomobile.aar built successfully
if "%1%"=="apk" goto build_flutter_apk
goto build_flutter_all

:: --- Build Flutter app ---
:build_flutter_windows
echo === Building Flutter Windows app ===
cd /d "%FLUTTER_DIR%"
flutter build windows --no-tree-shake-icons
if %ERRORLEVEL% neq 0 (
    echo ERROR: Flutter Windows build failed
    exit /b 1
)
echo.
echo === Build complete ===
echo Windows app: %FLUTTER_DIR%build\windows\x64\runner\Release\vrgram.exe
echo relayd:      %FLUTTER_DIR%build\windows\x64\runner\Release\relayd.exe
echo.
echo The app auto-starts relayd when launched.
goto end

:build_flutter_apk
echo === Building Flutter APK ===
cd /d "%FLUTTER_DIR%"
flutter build apk --no-tree-shake-icons
if %ERRORLEVEL% neq 0 (
    echo ERROR: Flutter APK build failed
    exit /b 1
)
echo.
echo === Build complete ===
echo APK: %FLUTTER_DIR%build\app\outputs\flutter-apk\app-release.apk
echo The app auto-starts relayd via gomobile on launch.
goto end

:build_flutter_all
echo === Building Flutter Windows + APK ===
cd /d "%FLUTTER_DIR%"
flutter build windows --no-tree-shake-icons
flutter build apk --no-tree-shake-icons
echo Build complete
goto end

:end
echo.
echo === Done ===
```

- [ ] **Step 2: Commit**

```bash
git add build_portable.bat
git commit -m "feat: add gomobile bind step to Android APK build"
```

---

### Task 5: Build and verify APK

- [ ] **Step 1: Build gomobile AAR**

```bash
cd go/
gomobile bind -target=android -o ../flutter/android/app/libs/gomobile.aar ./mobile/
```

Expected: `flutter/android/app/libs/gomobile.aar` created

- [ ] **Step 2: Build Flutter APK**

```bash
cd flutter/
flutter build apk --no-tree-shake-icons
```

Expected: APK at `flutter/build/app/outputs/flutter-apk/app-release.apk`

- [ ] **Step 3: Verify APK contains native lib**

```bash
unzip -l flutter/build/app/outputs/flutter-apk/app-release.apk | grep gomobile
```

Expected: `gomobile.aar` or extracted `.so` files visible in APK

- [ ] **Step 4: Commit final state**

```bash
git add -A
git commit -m "feat: gomobile APK integration complete"
```
