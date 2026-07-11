import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/chat_provider.dart';
import 'media_picker.dart';

class ChatInput extends ConsumerStatefulWidget {
  final String peerPubkey;
  final Function(String) onSend;
  final Function(MediaAction)? onMediaSelected;
  const ChatInput({
    super.key,
    required this.peerPubkey,
    required this.onSend,
    this.onMediaSelected,
  });

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final _ctrl = TextEditingController();
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  final _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _ctrl.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _ctrl.clear();
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => MediaPicker(
        onSelected: (action) {
          widget.onMediaSelected?.call(action);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      if (!mounted) return;
      setState(() => _isRecording = false);
      if (path != null) {
        ref.read(sendMediaProvider(SendMediaParams(
          peerPubkey: widget.peerPubkey,
          filePath: path,
          mimeType: 'audio/m4a',
        )));
      }
    } else {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
        }
        return;
      }
      final dir = Directory.systemTemp.path;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$dir/recording_$timestamp.m4a';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (!mounted) return;
      setState(() => _isRecording = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showMediaPicker,
          ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
            ),
          ),
          IconButton(
            icon: Icon(_isRecording ? Icons.stop : Icons.mic),
            onPressed: _toggleRecording,
            color: _isRecording ? Colors.red : null,
            tooltip: _isRecording ? 'Stop recording' : 'Start recording',
          ),
          IconButton(
            icon: const Icon(Icons.send),
            color: Theme.of(context).primaryColor,
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}
