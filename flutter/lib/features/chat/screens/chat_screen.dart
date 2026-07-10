import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../../peers/providers/peer_provider.dart';

class ChatScreen extends ConsumerWidget {
  final Peer peer;
  const ChatScreen({super.key, required this.peer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allMessages = ref.watch(chatProvider);

    // Filter to only messages with this peer
    final messages = allMessages.where((m) =>
        m.toPeer == peer.pubkey || m.fromPeer == peer.pubkey).toList();

    return Scaffold(
      appBar: AppBar(title: Text(peer.nickname)),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(child: Text('No messages yet'))
                : ListView.builder(
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (_, i) => MessageBubble(
                      message: messages[messages.length - 1 - i],
                    ),
                  ),
          ),
          ChatInput(
            onSend: (text) {
              ref.read(chatProvider.notifier).sendMessage(
                    peer.pubkey,
                    text,
                  );
            },
            onMediaSelected: (action) {
              // Media handling will be implemented in Task 7
            },
          ),
        ],
      ),
    );
  }
}
