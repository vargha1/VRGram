import 'package:flutter/material.dart';

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
              Navigator.pop(context, {
                'nickname': _nicknameCtrl.text,
                'pubkey': _pubkeyCtrl.text,
              });
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
