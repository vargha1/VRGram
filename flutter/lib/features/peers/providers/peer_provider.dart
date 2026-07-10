import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';
import '../../../core/platform/app_data_dir.dart';

class Peer {
  final String nickname;
  final String pubkey;
  Peer({required this.nickname, required this.pubkey});

  Map<String, dynamic> toJson() => {'nickname': nickname, 'pubkey': pubkey};

  factory Peer.fromJson(Map<String, dynamic> json) =>
      Peer(nickname: json['nickname'] as String, pubkey: json['pubkey'] as String);
}

class PeerList extends Notifier<List<Peer>> {
  static const _fileName = 'peers.json';

  @override
  List<Peer> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    try {
      final file = AppDataDir.file(_fileName);
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as List;
        state = json.map((e) => Peer.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Failed to load peers: $e');
    }
  }

  Future<void> _save() async {
    try {
      final file = AppDataDir.file(_fileName);
      await file.writeAsString(jsonEncode(state.map((p) => p.toJson()).toList()));
    } catch (e) {
      debugPrint('Failed to save peers: $e');
    }
  }

  Future<void> addPeer(String nickname, String pubkey) async {
    state = [...state, Peer(nickname: nickname, pubkey: pubkey)];
    await _save();
  }

  Future<void> removePeer(int index) async {
    state = [...state]..removeAt(index);
    await _save();
  }
}

final peerProvider = NotifierProvider<PeerList, List<Peer>>(PeerList.new);

final addPeerProvider = FutureProvider.family<void, PeerParams>((ref, params) async {
  final client = GrpcClient();
  await client.stub.addPeer(PeerInfo(
    nickname: params.nickname,
    pubkey: params.pubkey,
  ));
  await ref.read(peerProvider.notifier).addPeer(params.nickname, params.pubkey);
});

class PeerParams {
  final String nickname;
  final String pubkey;
  PeerParams({required this.nickname, required this.pubkey});
}
