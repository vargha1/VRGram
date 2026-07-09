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

    // Not found
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
        // Not ready yet
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    debugPrint('Warning: gRPC server did not become ready within $timeout');
  }

  static bool get isDesktop => !Platform.isAndroid && !Platform.isIOS;
}
