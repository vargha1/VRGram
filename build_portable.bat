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
    echo Usage: build_portable ^<windows^|apk^|all^>
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
go build -ldflags="-s -w -buildid=" -o "%FLUTTER_DIR%/build/windows/x64/runner/Release/relayd.exe" ./cmd/relayd/
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
go build -ldflags="-s -w -buildid=" -o "%FLUTTER_DIR%/android/app/src/main/res/raw/relayd_android" ./cmd/relayd/
set GOOS=
set GOARCH=
set CGO_ENABLED=
if %ERRORLEVEL% neq 0 (
    echo WARNING: Go cross-compile for Android failed (optional)
) else (
    echo relayd_android built successfully
)

REM Build shared library via c-shared
echo === Building libvrgram.so ===
if not exist "%FLUTTER_DIR%/android/app/src/main/jniLibs/arm64-v8a" mkdir "%FLUTTER_DIR%/android/app/src/main/jniLibs/arm64-v8a"
set GOOS=android
set GOARCH=arm64
set CGO_ENABLED=1
set CC=%ANDROID_NDK_HOME%\toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android21-clang
go build -buildmode=c-shared -ldflags="-s -w -buildid= -checklinkname=0" -o "%FLUTTER_DIR%/android/app/src/main/jniLibs/arm64-v8a/libvrgram.so" ./mobileso/
set GOOS=
set GOARCH=
set CGO_ENABLED=
set CC=
if %ERRORLEVEL% neq 0 (
    echo ERROR: c-shared build failed
    echo Ensure Android NDK is configured.
    exit /b 1
)
echo libvrgram.so built successfully
if "%1%"=="apk" goto build_flutter_apk
goto build_flutter_all

:: --- Build Flutter app ---
:build_flutter_windows
echo === Building Flutter Windows app ===
cd /d "%FLUTTER_DIR%"
flutter build windows --split-debug-info=build/debug-info --obfuscate
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
flutter build apk --split-debug-info=build/debug-info
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
flutter build windows --split-debug-info=build/debug-info --obfuscate
flutter build apk --split-debug-info=build/debug-info
echo Build complete
goto end

:end
echo.
echo === Done ===
