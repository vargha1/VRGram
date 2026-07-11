import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';
import 'relay.pb.dart';
import 'relay.pbgrpc.dart';
import '../platform/app_data_dir.dart';

class GrpcClient {
  static final GrpcClient _instance = GrpcClient._();
  factory GrpcClient() => _instance;
  GrpcClient._();

  static const int _port = 9876;
  static const Duration _grpcTimeout = Duration(seconds: 30);

  late final ClientChannel _channel;
  late final RelayClient _stub;
  final Completer<void> _ready = Completer<void>();

  /// Auth token read from daemon, passed as metadata on every gRPC call.
  static String? authToken;

  /// Initialize gRPC client and read auth token.
  /// Retries reading auth token until daemon writes it.
  Future<void> init({Duration authTimeout = const Duration(seconds: 10)}) async {
    if (_ready.isCompleted) return;

    await _loadAuthTokenWithRetry(authTimeout);

    _channel = ClientChannel(
      '127.0.0.1',
      port: _port,
      options: ChannelOptions(
        credentials: const ChannelCredentials.insecure(),
        idleTimeout: const Duration(seconds: 30),
      ),
    );
    _stub = RelayClient(_channel,
        options: CallOptions(timeout: _grpcTimeout));
    _ready.complete();
  }

  /// Retry reading auth_token file until it exists or timeout.
  Future<void> _loadAuthTokenWithRetry(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final file = AppDataDir.file('auth_token');
        if (await file.exists()) {
          // Token stored as hex string (64 hex chars = 32 bytes)
          final tokenStr = await file.readAsString();
          final trimmed = tokenStr.trim();
          if (trimmed.length == 64) {
            authToken = trimmed;
            debugPrint('GrpcClient: auth token loaded (${authToken?.length} chars)');
            return;
          }
          debugPrint('GrpcClient: auth token wrong length: ${trimmed.length} (expected 64)');
        }
      } catch (e) {
        debugPrint('GrpcClient: auth token read error: $e');
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    debugPrint('GrpcClient: auth token file not found within $timeout, continuing without auth');
  }

  RelayClient get stub {
    if (!_ready.isCompleted) {
      throw StateError('GrpcClient not initialized. Call init() first.');
    }
    return _stub;
  }

  Future<void> shutdown() async {
    if (!_ready.isCompleted) return;
    await _channel.shutdown();
  }

  Future<TransportStatusResponse> getTransportStatus() async {
    await _ready.future;
    return stub.getTransportStatus(Empty());
  }
}
