import 'package:grpc/grpc.dart';
import 'relay.pbgrpc.dart';

class GrpcClient {
  static final GrpcClient _instance = GrpcClient._();
  factory GrpcClient() => _instance;
  GrpcClient._();

  static const int _port = 9876;

  late final ClientChannel _channel;
  late final RelayClientClient _stub;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _channel = ClientChannel(
      '127.0.0.1',
      port: _port,
      options: ChannelOptions(
        credentials: const ChannelCredentials.insecure(),
      ),
    );
    _stub = RelayClientClient(_channel);
    _initialized = true;
  }

  RelayClientClient get stub {
    if (!_initialized) {
      throw StateError('GrpcClient not initialized. Call init() first.');
    }
    return _stub;
  }

  Future<void> shutdown() async {
    if (!_initialized) return;
    await _channel.shutdown();
    _initialized = false;
  }
}
