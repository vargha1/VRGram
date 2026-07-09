import 'package:flutter/material.dart';

class AddRelayDialog extends StatefulWidget {
  const AddRelayDialog({super.key});

  @override
  State<AddRelayDialog> createState() => _AddRelayDialogState();
}

class _AddRelayDialogState extends State<AddRelayDialog> {
  final _relayCtrl = TextEditingController();
  final _dnsCtrl = TextEditingController(text: '8.8.8.8:53');

  @override
  void dispose() {
    _relayCtrl.dispose();
    _dnsCtrl.dispose();
    super.dispose();
  }

  bool _isValidRelayAddress(String addr) {
    // Accept IP:port or domain:port
    final parts = addr.split(':');
    if (parts.length != 2) return false;
    final port = int.tryParse(parts[1]);
    if (port == null || port < 1 || port > 65535) return false;
    return parts[0].isNotEmpty;
  }

  bool _isValidDNSResolver(String addr) {
    if (addr.isEmpty) return true;
    final parts = addr.split(':');
    if (parts.length != 2) return false;
    final port = int.tryParse(parts[1]);
    if (port == null || port < 1 || port > 65535) return false;
    // DNS resolver must be IP:port (not domain)
    final ip = parts[0];
    final octets = ip.split('.');
    if (octets.length != 4) return false;
    for (final o in octets) {
      final v = int.tryParse(o);
      if (v == null || v < 0 || v > 255) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Relay'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _relayCtrl,
            decoration: const InputDecoration(
              labelText: 'Relay address (IP:port or domain:port)',
              hintText: '203.0.113.1:53 or relay.example.com:53',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _dnsCtrl,
            decoration: const InputDecoration(
              labelText: 'DNS resolver (IP:port, optional)',
              hintText: '8.8.8.8:53',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final relay = _relayCtrl.text.trim();
            if (!_isValidRelayAddress(relay)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invalid relay address format')),
              );
              return;
            }
            if (!_isValidDNSResolver(_dnsCtrl.text.trim())) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invalid DNS resolver format')),
              );
              return;
            }
            Navigator.pop(context, {
              'address': relay,
              'dnsResolver': _dnsCtrl.text.trim(),
            });
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}