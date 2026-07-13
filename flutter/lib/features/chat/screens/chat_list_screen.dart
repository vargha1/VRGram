import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/chat_provider.dart';
import '../../peers/providers/peer_provider.dart';
import '../../peers/screens/peer_list_screen.dart';
import '../../group/screens/group_list_screen.dart';
import '../../../shared/constants.dart';
import '../../../core/theme_provider.dart';

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
            icon: const Icon(Icons.person),
            onPressed: () => context.push('/profile'),
            tooltip: 'Profile',
          ),
          IconButton(
            icon: const Icon(Icons.dns),
            onPressed: () => context.push('/relays'),
            tooltip: 'Relay servers',
          ),
          PopupMenuButton<ThemeMode>(
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: 'Theme',
            onSelected: (mode) => ref.read(themeModeProvider.notifier).setMode(mode),
            itemBuilder: (_) => [
              const PopupMenuItem(value: ThemeMode.system, child: Text('System')),
              const PopupMenuItem(value: ThemeMode.light, child: Text('Light')),
              const PopupMenuItem(value: ThemeMode.dark, child: Text('Dark')),
            ],
          ),
        ],
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Groups', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.groups)),
            title: const Text('Groups'),
            subtitle: const Text('View and manage group chats'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const GroupListScreen())),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Direct Messages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          if (peers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Text(AppStrings.noPeers),
                  SizedBox(height: 8),
                  // No button here — FilledButton can't be const
                ],
              ),
            )
          else
            ...List.generate(peers.length, (i) {
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
            }),
          // Add contacts button when peers empty
          if (peers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PeerListScreen(),
                  ),
                ),
                child: const Text('Add contacts'),
              ),
            ),
        ],
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
