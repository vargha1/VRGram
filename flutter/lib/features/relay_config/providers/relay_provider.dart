import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';
import '../../../shared/constants.dart';

final relayStatusProvider =
    FutureProvider.autoDispose<RelayStatusList>((ref) async {
  final client = GrpcClient();
  return client.stub.getRelayStatus(Empty());
});

final autoRefreshRelayStatus =
    StreamProvider.autoDispose<RelayStatusList>((ref) async* {
  while (true) {
    await Future.delayed(AppDurations.relayStatusInterval);
    final status = await ref.read(relayStatusProvider.future);
    yield status;
  }
});

final isBlackoutProvider = FutureProvider<bool>((ref) async {
  final status = await ref.read(relayStatusProvider.future);
  return status.endpoints.any((e) => e.blackoutMode);
});
