import 'dart:async';
import 'package:grpc/grpc.dart';
import 'relay.pb.dart';
import 'relay.pbgrpc.dart';

class GrpcClient {
  static final GrpcClient _instance = GrpcClient._();
  factory GrpcClient() => _instance;
  GrpcClient._();

  static const int _port = 9876;
  static const Duration _grpcTimeout = Duration(seconds: 30);

  late final ClientChannel _channel;
  late final RelayClientClient _stub;
  final Completer<void> _ready = Completer<void>();

  Future<void> init() async {
    if (_ready.isCompleted) return;
    _channel = ClientChannel(
      '127.0.0.1',
      port: _port,
      options: ChannelOptions(
        credentials: const ChannelCredentials.insecure(),
        // Drop idle connections after 30s so stale channel doesn't block sends
        idleTimeout: const Duration(seconds: 30),
      ),
    );
    _stub = RelayClientClient(_channel,
        options: CallOptions(timeout: _grpcTimeout));
    _ready.complete();
  }

  RelayClientClient get stub {
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
