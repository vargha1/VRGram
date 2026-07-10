import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';
import '../../../shared/constants.dart';
import 'chat_provider.dart';

final pollMessagesProvider = StreamProvider<void>((ref) async* {
  while (true) {
    await Future.delayed(AppDurations.messagePollInterval);
    try {
      final client = GrpcClient();
      final resp = await client.stub.pollMessages(PollRequest());
      for (final msg in resp.messages) {
        ref.read(chatProvider.notifier).addMessage(ChatMessage(
              id: msg.messageId,
              text: utf8.decode(msg.plaintext),
              timestamp: msg.hasTimestamp()
                  ? DateTime.fromMillisecondsSinceEpoch(msg.timestamp.toInt())
                  : DateTime.now(),
              isSent: false,
              status: MessageStatus.received,
              fromPeer: msg.fromPeer,
            ));
      }
    } catch (_) {
      // gRPC error — will retry on next poll
    }
  }
});
