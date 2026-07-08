import 'package:flutter/material.dart';

class AddRelayDialog extends StatefulWidget {
  const AddRelayDialog({super.key});

  @override
  State<AddRelayDialog> createState() => _AddRelayDialogState();
}

class _AddRelayDialogState extends State<AddRelayDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Relay'),
      content: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(
          labelText: 'Relay address (IP:port)',
          hintText: '203.0.113.1:53',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_ctrl.text.isNotEmpty) Navigator.pop(context, _ctrl.text);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
