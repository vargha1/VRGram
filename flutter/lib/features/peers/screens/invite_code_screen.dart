import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';
import '../providers/peer_provider.dart';

class InviteCodeScreen extends ConsumerStatefulWidget {
  const InviteCodeScreen({super.key});
  @override
  ConsumerState<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends ConsumerState<InviteCodeScreen> {
  String? _generatedCode;
  bool _generating = false;
  final _codeController = TextEditingController();
  bool _joining = false;

  Future<void> _generateCode() async {
    setState(() => _generating = true);
    try {
      final client = GrpcClient();
      final resp = await client.stub
          .generateInviteCode(GenerateInviteCodeRequest(nickname: ''))
          .timeout(const Duration(seconds: 10));
      setState(() => _generatedCode = resp.code);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generate failed: $e')),
        );
      }
    } finally {
      setState(() => _generating = false);
    }
  }

  Future<void> _joinViaCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _joining = true);
    try {
      final client = GrpcClient();
      final resp = await client.stub
          .joinViaCode(JoinViaCodeRequest(code: code))
          .timeout(const Duration(seconds: 10));
      // Add peer to local list using response info
      await ref.read(peerProvider.notifier).addPeer(
            resp.peerNickname,
            resp.peerPubkey,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected with ${resp.peerNickname}')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Join failed: $e')),
        );
      }
    } finally {
      setState(() => _joining = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Invite'),
          bottom: const TabBar(
            tabs: [Tab(text: 'My Code'), Tab(text: 'Enter Code')],
          ),
        ),
        body: TabBarView(
          children: [
            // Generate tab
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Text('Share this code with someone to connect.'),
                const SizedBox(height: 16),
                if (_generatedCode != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(_generatedCode!,
                        style: const TextStyle(fontSize: 14, fontFamily: 'monospace')),
                  ),
                  const SizedBox(height: 12),
                  // QR code
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: QrImageView(
                      data: _generatedCode!,
                      version: QrVersions.auto,
                      size: 180,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    ElevatedButton.icon(
                      onPressed: () => Clipboard.setData(
                          ClipboardData(text: _generatedCode!)),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _generateCode,
                      icon: const Icon(Icons.refresh),
                      label: const Text('New Code'),
                    ),
                  ]),
                ] else ...[
                  ElevatedButton(
                    onPressed: _generateCode,
                    child: _generating
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Generate Invite Code'),
                  ),
                ],
              ]),
            ),
            // Join tab
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Text('Paste someone\'s invite code to connect.'),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Invite Code',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _joining ? null : _joinViaCode,
                  child: _joining
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Join'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
