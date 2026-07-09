import 'package:flutter/material.dart';
import 'media_picker.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSend;
  final Function(MediaAction)? onMediaSelected;
  const ChatInput({super.key, required this.onSend, this.onMediaSelected});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
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
            icon: const Icon(Icons.send),
            color: Theme.of(context).primaryColor,
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}
