import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/peer_provider.dart';
import '../widgets/peer_tile.dart';
import 'add_peer_dialog.dart';
import '../../chat/screens/chat_screen.dart';
import '../../../shared/constants.dart';

class PeerListScreen extends ConsumerWidget {
  const PeerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peers = ref.watch(peerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: peers.isEmpty
          ? const Center(child: Text(AppStrings.noPeers))
          : ListView.builder(
              itemCount: peers.length,
              itemBuilder: (_, i) => PeerTile(
                peer: peers[i],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(peer: peers[i]),
                  ),
                ),
                onDelete: () =>
                    ref.read(peerProvider.notifier).removePeer(i),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showDialog<Map<String, String>>(
            context: context,
            builder: (_) => const AddPeerDialog(),
          );
          if (result != null) {
            ref
                .read(peerProvider.notifier)
                .addPeer(result['nickname']!, result['pubkey']!);
          }
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
