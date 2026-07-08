import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';

enum MessageStatus { sent, queued, failed, received }

class ChatMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isSent;
  final MessageStatus status;
  final String? fromPeer;

  ChatMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isSent,
    required this.status,
    this.fromPeer,
  });
}

class ChatList extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() => [];

  void addMessage(ChatMessage msg) {
    state = [...state, msg];
  }

  void updateStatus(String id, MessageStatus status) {
    state = state.map((m) {
      if (m.id == id) {
        return ChatMessage(
          id: m.id,
          text: m.text,
          timestamp: m.timestamp,
          isSent: m.isSent,
          status: status,
          fromPeer: m.fromPeer,
        );
      }
      return m;
    }).toList();
  }
}

final chatProvider = NotifierProvider<ChatList, List<ChatMessage>>(ChatList.new);

final sendMessageProvider =
    FutureProvider.family<void, SendParams>((ref, params) async {
  final client = GrpcClient();
  final msgId = DateTime.now().millisecondsSinceEpoch.toString();

  ref.read(chatProvider.notifier).addMessage(ChatMessage(
        id: msgId,
        text: params.text,
        timestamp: DateTime.now(),
        isSent: true,
        status: MessageStatus.sent,
      ));

  try {
    final resp = await client.stub.sendMessage(SendRequest(
      peerPubkey: params.peerPubkey,
      plaintext: utf8.encode(params.text),
    ));
    ref.read(chatProvider.notifier).updateStatus(
          msgId,
          resp.queued ? MessageStatus.queued : MessageStatus.sent,
        );
  } catch (e) {
    ref.read(chatProvider.notifier).updateStatus(msgId, MessageStatus.failed);
    rethrow;
  }
});

class SendParams {
  final String peerPubkey;
  final String text;
  SendParams({required this.peerPubkey, required this.text});
}
