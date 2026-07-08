import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';

final identityProvider = FutureProvider<IdentityInfo>((ref) async {
  final client = GrpcClient();
  return client.stub.getIdentity(Empty());
});

final identityPubkeyProvider = Provider<String>((ref) {
  final identity = ref.watch(identityProvider);
  return identity.when(
    data: (info) => info.pubkey,
    loading: () => '',
    error: (_, _) => '',
  );
});

final identityShortProvider = Provider<String>((ref) {
  final pubkey = ref.watch(identityPubkeyProvider);
  if (pubkey.length > 16) {
    return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 8)}';
  }
  return pubkey;
});
