import 'package:flutter/material.dart';
import 'invite_code_screen.dart';

class AddPeerDialog extends StatefulWidget {
  const AddPeerDialog({super.key});

  @override
  State<AddPeerDialog> createState() => _AddPeerDialogState();
}

class _AddPeerDialogState extends State<AddPeerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameCtrl = TextEditingController();
  final _pubkeyCtrl = TextEditingController();

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _pubkeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Peer'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const InviteCodeScreen()));
                  if (result == true && context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.qr_code),
                label: const Text('Join via Invite Code'),
              ),
            ),
            TextFormField(
              controller: _nicknameCtrl,
              decoration: const InputDecoration(labelText: 'Nickname'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pubkeyCtrl,
              decoration: const InputDecoration(
                labelText: 'Public Key (base64)',
              ),
              maxLines: 2,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
                FilledButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      // Strip "VRGram identity: " prefix from shared keys
                      String raw = _pubkeyCtrl.text.trim();
                      const prefix = 'VRGram identity: ';
                      if (raw.startsWith(prefix)) {
                        raw = raw.substring(prefix.length).trim();
                      }
                      Navigator.pop(context, {
                        'nickname': _nicknameCtrl.text.trim(),
                        'pubkey': raw,
                      });
                    }
                  },
                  child: const Text('Add'),
                ),
      ],
    );
  }
}
