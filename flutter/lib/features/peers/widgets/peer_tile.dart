import 'package:flutter/material.dart';
import '../providers/peer_provider.dart';
import 'peer_avatar.dart';

class PeerTile extends StatelessWidget {
  final Peer peer;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const PeerTile({
    super.key,
    required this.peer,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: PeerAvatar(
        pubkey: peer.pubkey,
        nickname: peer.nickname,
        radius: 20,
      ),
      title: Text(peer.nickname),
      subtitle: Text(
        peer.pubkey.length > 24
            ? '${peer.pubkey.substring(0, 12)}...${peer.pubkey.substring(peer.pubkey.length - 12)}'
            : peer.pubkey,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }
}
