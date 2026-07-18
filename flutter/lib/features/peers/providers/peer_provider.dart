import 'dart:async';
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
  Timer? _refreshTimer;

  @override
  List<Peer> build() {
    _load();
    // Periodically refresh peer list from daemon so profile_updates
    // (nickname changes from other peers) propagate to UI.
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refreshFromDaemon();
    });
    ref.onDispose(() => _refreshTimer?.cancel());
    return [];
  }

  Future<void> _load() async {
    try {
      final file = AppDataDir.file(_fileName);
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as List;
        state = json.map((e) {
          final peer = Peer.fromJson(e as Map<String, dynamic>);
          // Auto-repair "VRGram identity: " prefix in stored pubkeys
          return Peer(nickname: peer.nickname, pubkey: sanitizePubkey(peer.pubkey));
        }).toList();
        _save(); // persist repaired data
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

  /// Strip "VRGram identity: " prefix from shared pubkey strings.
  static String sanitizePubkey(String raw) {
    final s = raw.trim();
    const prefix = 'VRGram identity: ';
    if (s.startsWith(prefix)) {
      return s.substring(prefix.length).trim();
    }
    return s;
  }

  /// Find a peer's nickname by their public key. Returns null if not found.
  String? findNicknameByPubkey(String pubkey) {
    for (final peer in state) {
      if (peer.pubkey == pubkey) return peer.nickname;
    }
    return null;
  }

  Future<void> addPeer(String nickname, String pubkey) async {
    final clean = sanitizePubkey(pubkey);
    try {
      final client = GrpcClient();
      await client.stub.addPeer(PeerInfo(nickname: nickname, pubkey: clean));
    } catch (e) {
      debugPrint('addPeer gRPC failed: $e');
    }
    state = [...state, Peer(nickname: nickname, pubkey: clean)];
    await _save();
  }

  Future<void> removePeerByPubkey(String pubkey) async {
    try {
      final client = GrpcClient();
      await client.stub.removePeer(PeerInfo(pubkey: pubkey, nickname: ''));
    } catch (e) {
      debugPrint('removePeer gRPC failed: $e');
    }
    state = state.where((p) => p.pubkey != pubkey).toList();
    await _save();
  }

  Future<void> removePeer(int index) async {
    state = [...state]..removeAt(index);
    await _save();
  }

  /// Refresh peer list from daemon via gRPC ListPeers.
  Future<void> refreshFromDaemon() async {
    try {
      final client = GrpcClient();
      final resp = await client.stub.listPeers(Empty());
      state = resp.peers
          .map((p) => Peer(nickname: p.nickname, pubkey: sanitizePubkey(p.pubkey)))
          .toList();
      await _save();
    } catch (e) {
      debugPrint('refreshFromDaemon failed: $e');
    }
  }
}

final peerProvider = NotifierProvider<PeerList, List<Peer>>(PeerList.new);

final addPeerProvider = FutureProvider.family<void, PeerParams>((ref, params) async {
  final cleanPubkey = PeerList.sanitizePubkey(params.pubkey);
  final client = GrpcClient();
  await client.stub.addPeer(PeerInfo(
    nickname: params.nickname,
    pubkey: cleanPubkey,
  ));
  await ref.read(peerProvider.notifier).addPeer(params.nickname, cleanPubkey);
});

class PeerParams {
  final String nickname;
  final String pubkey;
  PeerParams({required this.nickname, required this.pubkey});
}
