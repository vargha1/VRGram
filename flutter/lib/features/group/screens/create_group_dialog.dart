import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/group_provider.dart';
import '../../peers/providers/peer_provider.dart';

class CreateGroupDialog extends ConsumerStatefulWidget {
  const CreateGroupDialog({super.key});
  @override
  ConsumerState<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends ConsumerState<CreateGroupDialog> {
  final _nameController = TextEditingController();
  final _selected = <String>{};
  bool _creating = false;

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selected.isEmpty) return;
    setState(() => _creating = true);
    try {
      await ref.read(groupProvider.notifier).createGroup(name, _selected.toList());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      setState(() => _creating = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peers = ref.watch(peerProvider);
    return AlertDialog(
      title: const Text('New Group'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Group Name'),
            ),
            const SizedBox(height: 12),
            const Text('Select Members:', style: TextStyle(fontWeight: FontWeight.bold)),
            if (peers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No contacts yet. Add peers first.'),
              )
            else
              ...peers.map((peer) => CheckboxListTile(
                    dense: true,
                    title: Text(peer.nickname),
                    subtitle: Text('${peer.pubkey.substring(0, 12)}...'),
                    value: _selected.contains(peer.pubkey),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) { _selected.add(peer.pubkey); }
                        else { _selected.remove(peer.pubkey); }
                      });
                    },
                  )),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _creating ? null : _create,
          child: _creating
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }
}
