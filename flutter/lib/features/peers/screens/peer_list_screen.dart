import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/peer_provider.dart';
import '../widgets/peer_tile.dart';
import 'add_peer_dialog.dart';
import '../../chat/screens/chat_screen.dart';
import '../../../shared/constants.dart';

class PeerListScreen extends ConsumerStatefulWidget {
  const PeerListScreen({super.key});

  @override
  ConsumerState<PeerListScreen> createState() => _PeerListScreenState();
}

class _PeerListScreenState extends ConsumerState<PeerListScreen> {
  @override
  void initState() {
    super.initState();
    // Sync peer list from daemon on open (catches auto-added peers from hello)
    Future.microtask(() => ref.read(peerProvider.notifier).refreshFromDaemon());
  }

  @override
  Widget build(BuildContext context) {
    final peers = ref.watch(peerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(peerProvider.notifier).refreshFromDaemon(),
          ),
        ],
      ),
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
                    ref.read(peerProvider.notifier).removePeerByPubkey(peers[i].pubkey),
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
