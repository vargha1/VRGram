import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';

class DhtStatus {
  final bool dhtConnected;
  final int discoveredRelays;
  final bool libp2pAvailable;
  final String dnsMode;

  DhtStatus({
    required this.dhtConnected,
    required this.discoveredRelays,
    required this.libp2pAvailable,
    required this.dnsMode,
  });

  factory DhtStatus.fromResponse(TransportStatusResponse resp) {
    return DhtStatus(
      dhtConnected: resp.dhtConnected,
      discoveredRelays: resp.discoveredRelays,
      libp2pAvailable: resp.libp2pDirect || resp.libp2pCircuit,
      dnsMode: resp.dnsMode,
    );
  }
}

final dhtStatusProvider = FutureProvider.autoDispose<DhtStatus>((ref) async {
  final client = GrpcClient();
  final response = await client.stub.getTransportStatus(Empty());
  return DhtStatus.fromResponse(response);
});
