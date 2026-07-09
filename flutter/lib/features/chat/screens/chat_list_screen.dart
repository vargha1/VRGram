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
            onPressed: () => context.push('/relays'),
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
              itemBuilder: (_, i) => ListTile(
                leading: CircleAvatar(
                  child: Text(peers[i].nickname[0].toUpperCase()),
                ),
                title: Text(peers[i].nickname),
                subtitle: messages.isEmpty
                    ? const Text('No messages')
                    : Text(messages.last.text),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/chat',
                    arguments: peers[i]),
              ),
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
