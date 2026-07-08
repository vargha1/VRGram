import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';

class Peer {
  final String nickname;
  final String pubkey;
  Peer({required this.nickname, required this.pubkey});
}

class PeerList extends Notifier<List<Peer>> {
  @override
  List<Peer> build() => [];

  void addPeer(String nickname, String pubkey) {
    state = [...state, Peer(nickname: nickname, pubkey: pubkey)];
  }

  void removePeer(int index) {
    state = [...state]..removeAt(index);
  }
}

final peerProvider = NotifierProvider<PeerList, List<Peer>>(PeerList.new);

final addPeerProvider = FutureProvider.family<void, PeerParams>((ref, params) async {
  final client = GrpcClient();
  await client.stub.addPeer(PeerInfo(
    nickname: params.nickname,
    pubkey: params.pubkey,
  ));
  ref.read(peerProvider.notifier).addPeer(params.nickname, params.pubkey);
});

class PeerParams {
  final String nickname;
  final String pubkey;
  PeerParams({required this.nickname, required this.pubkey});
}
