import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/media_picker.dart';
import '../../peers/providers/peer_provider.dart';

class ChatScreen extends ConsumerWidget {
  final Peer peer;
  const ChatScreen({super.key, required this.peer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allMessages = ref.watch(chatProvider);

    // Filter to only messages with this peer
    final messages = allMessages.where((m) =>
        m.toPeer == peer.pubkey || m.fromPeer == peer.pubkey).toList();

    return Scaffold(
      appBar: AppBar(title: Text(peer.nickname)),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(child: Text('No messages yet'))
                : ListView.builder(
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (_, i) => MessageBubble(
                      message: messages[messages.length - 1 - i],
                    ),
                  ),
          ),
          ChatInput(
            onSend: (text) {
              ref.read(chatProvider.notifier).sendMessage(
                    peer.pubkey,
                    text,
                  );
            },
            onMediaSelected: (action) =>
                _handleMediaAction(context, ref, action),
          ),
        ],
      ),
    );
  }

  void _handleMediaAction(
      BuildContext context, WidgetRef ref, MediaAction action) {
    switch (action) {
      case MediaAction.camera:
        _pickAndSend(ref, ImageSource.camera, 'image');
      case MediaAction.gallery:
        _pickAndSend(ref, ImageSource.gallery, 'image');
      case MediaAction.video:
        _pickAndSend(ref, ImageSource.camera, 'video');
      case MediaAction.file:
        _pickFileAndSend(ref);
      case MediaAction.voice:
        _recordAndSend(context, ref);
    }
  }

  Future<void> _pickAndSend(
      WidgetRef ref, ImageSource source, String type) async {
    final picker = ImagePicker();
    XFile? picked;
    if (type == 'video') {
      picked = await picker.pickVideo(source: source);
    } else {
      picked = await picker.pickImage(source: source);
    }
    if (picked == null) return;

    final mimeType = type == 'video' ? 'video/mp4' : 'image/jpeg';
    _sendFile(ref, picked.path, mimeType);
  }

  Future<void> _pickFileAndSend(WidgetRef ref) async {
    final result = await FilePicker.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    final mimeType = _guessMimeType(file.name);
    _sendFile(ref, file.path!, mimeType);
  }

  Future<void> _recordAndSend(BuildContext context, WidgetRef ref) async {
    // Simple voice recording via file picker's audio recording
    final result = await FilePicker.pickFiles(
      type: FileType.audio,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    _sendFile(ref, file.path!, 'audio/m4a');
  }

  void _sendFile(WidgetRef ref, String filePath, String mimeType) {
    ref.read(sendMediaProvider(
      SendMediaParams(
        peerPubkey: peer.pubkey,
        filePath: filePath,
        mimeType: mimeType,
      ),
    ));
  }

  String _guessMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mkv':
        return 'video/x-matroska';
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
      case 'aac':
        return 'audio/m4a';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'pdf':
        return 'application/pdf';
      case 'zip':
        return 'application/zip';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}
