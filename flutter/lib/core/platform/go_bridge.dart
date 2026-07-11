import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:grpc/grpc.dart';

import '../grpc/relay.pb.dart';
import '../grpc/relay.pbgrpc.dart';
import 'app_data_dir.dart';

class GoBridge {
  static Process? _process;
  static bool _started = false;
  static const _channel = MethodChannel('vrgram/bridge');
  static const defaultRelay = '31.15.17.161:9876';

  /// Start the Go daemon and wait for gRPC server to be ready.
  static Future<void> start({
    int grpcPort = 9876,
    String dataDir = '',
    int p2pPort = 4001,
    String bootstrap = '',
    String relays = defaultRelay,
    String zone = 'msg.local-domain',
    String dnsResolver = '8.8.8.8:53',
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
        dnsResolver: dnsResolver,
      );
    } else {
      // Mobile: start daemon via native method channel
      await _startMobileDaemon(
        grpcPort: grpcPort,
        dataDir: dataDir,
        p2pPort: p2pPort,
        bootstrap: bootstrap,
        relays: relays,
        zone: zone,
        dnsResolver: dnsResolver,
      );
    }

    await _waitForGRPC(grpcPort);
  }

  /// Mobile: call native GoBridge.startDaemon via method channel.
  static Future<void> _startMobileDaemon({
    required int grpcPort,
    required String dataDir,
    required int p2pPort,
    required String bootstrap,
    required String relays,
    required String zone,
    required String dnsResolver,
  }) async {
    try {
      debugPrint('Starting Go daemon via method channel...');
      final result = await _channel.invokeMethod('startDaemon', {
        'grpcPort': grpcPort,
        'dataDir': dataDir,
        'p2pPort': p2pPort,
        'zone': zone,
        'relays': relays,
        'bootstrap': bootstrap,
        'dnsResolver': dnsResolver,
      });
      debugPrint('Go daemon method channel returned: $result');
    } on PlatformException catch (e) {
      debugPrint('Failed to start Go daemon: ${e.code} - ${e.message}');
    } catch (e) {
      debugPrint('Failed to start Go daemon: $e');
    }
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
    required String dnsResolver,
  }) async {
    // Kill any orphan relayd from a previous app instance so the new one
    // starts with the correct --data-dir and auth token paths match.
    await _killOrphanDaemon();

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
    if (dnsResolver.isNotEmpty) {
      args.addAll(['--dns-resolver', dnsResolver]);
    }

    debugPrint('Starting relayd: $binaryPath ${args.join(' ')}');

    try {
      // Start relayd as a child process (stdin piped to /dev/null, stdout/stderr captured)
      _process = await Process.start(binaryPath, args,
        runInShell: false,
      );
      // Close stdin immediately (we don't send input)
      _process!.stdin.close();
      // Pipe stdout/stderr to debug console
      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((l) => debugPrint('[relayd] $l'));
      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((l) => debugPrint('[relayd:err] $l'));
      // Handle exit
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
    // Check next to the current executable
    if (Platform.script.path.isNotEmpty) {
      final dir = File(Platform.script.path).parent.path;
      final localPath = '$dir${Platform.pathSeparator}$name';
      if (await File(localPath).exists()) return localPath;
    }

    // Check current working directory
    final cwdPath = '${Directory.current.path}${Platform.pathSeparator}$name';
    if (await File(cwdPath).exists()) return cwdPath;

    // Check ../go/ (development mode)
    final devPath = '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}go${Platform.pathSeparator}$name';
    if (await File(devPath).exists()) return devPath;

    // Check ../ (project root, development mode)
    final rootPath = '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}$name';
    if (await File(rootPath).exists()) return rootPath;

    // Not found
    return null;
  }

  /// Poll gRPC server until it responds (keeps trying past timeout).
  static Future<void> _waitForGRPC(int port, {Duration timeout = const Duration(seconds: 60)}) async {
    final deadline = DateTime.now().add(timeout);
    bool warned = false;
    while (DateTime.now().isBefore(deadline)) {
      try {
        final channel = ClientChannel(
          '127.0.0.1',
          port: port,
          options: ChannelOptions(
            credentials: const ChannelCredentials.insecure(),
          ),
        );
        final stub = RelayClient(channel);
        await stub.getIdentity(Empty());
        await channel.shutdown();
        debugPrint('gRPC server ready on port $port');
        return;
      } catch (_) {
        // Read Go daemon startup log to show progress
        _printStartupLog();
        if (!warned && deadline.difference(DateTime.now()).inSeconds < 10) {
          debugPrint('Warning: gRPC server still not ready, will keep trying...');
          warned = true;
        }
        // Not ready yet
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    // After final timeout, try indefinitely with 1s intervals
    debugPrint('gRPC server not ready within $timeout, continuing to poll indefinitely');
    while (true) {
      try {
        final channel = ClientChannel(
          '127.0.0.1',
          port: port,
          options: ChannelOptions(
            credentials: const ChannelCredentials.insecure(),
          ),
        );
        final stub = RelayClient(channel);
        await stub.getIdentity(Empty());
        await channel.shutdown();
        debugPrint('gRPC server finally ready');
        return;
      } catch (_) {
        _printStartupLog();
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  /// Read Go daemon's startup.log and print any new lines.
  static DateTime _lastStartupLogRead = DateTime(2000);
  static Future<void> _printStartupLog() async {
    try {
      final file = AppDataDir.file('startup.log');
      if (await file.exists()) {
        final mod = await file.lastModified();
        if (mod.isAfter(_lastStartupLogRead)) {
          final content = await file.readAsString();
          _lastStartupLogRead = mod;
          for (final line in content.split('\n')) {
            if (line.trim().isNotEmpty) {
              debugPrint('[daemon] $line');
            }
          }
        }
      }
    } catch (_) {}
  }

  /// Kill any orphan relayd daemon from a previous app session.
  /// On desktop, stale relayd processes hold port 9876 and use the wrong
  /// data directory, causing gRPC auth token mismatch for the new instance.
  static Future<void> _killOrphanDaemon() async {
    if (!isDesktop) return;
    try {
      if (Platform.isWindows) {
        // taskkill /f ignores "not found" exit code, so we capture all output
        await Process.run('taskkill', ['/f', '/im', 'relayd.exe'],
            runInShell: true);
      } else {
        // pkill -0 checks existence, -9 kills; ignore failures
        await Process.run('pkill', ['-9', 'relayd'], runInShell: true);
      }
    } catch (_) {
      // No orphan process — fine.
    }
  }

  static bool get isDesktop => !Platform.isAndroid && !Platform.isIOS;
}
