import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/chat_provider.dart';
import '../../peers/providers/peer_provider.dart';
import '../../peers/screens/peer_list_screen.dart';
import '../../../shared/constants.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peers = ref.watch(peerProvider);
    final messages = ref.watch(chatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key),
            onPressed: () => context.push('/identity'),
            tooltip: AppStrings.yourPublicKey,
          ),
          IconButton(
            icon: const Icon(Icons.dns),
            onPressed: () => context.push('/dht'),
            tooltip: 'Relay servers',
          ),
        ],
      ),
      body: peers.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(AppStrings.noPeers),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PeerListScreen(),
                      ),
                    ),
                    child: const Text('Add contacts'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: peers.length,
              itemBuilder: (_, i) {
                final peer = peers[i];
                // Find last message for this specific peer
                final peerMessages = messages.where((m) =>
                    m.toPeer == peer.pubkey || m.fromPeer == peer.pubkey).toList();
                final lastMsg = peerMessages.isNotEmpty ? peerMessages.last : null;

                return ListTile(
                  leading: CircleAvatar(
                    child: Text(peer.nickname[0].toUpperCase()),
                  ),
                  title: Text(peer.nickname),
                  subtitle: lastMsg == null
                      ? const Text('No messages')
                      : Text(
                          lastMsg.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/chat', extra: peer),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PeerListScreen()),
        ),
        child: const Icon(Icons.chat),
      ),
    );
  }
}
