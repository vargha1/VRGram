import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../providers/chat_provider.dart';
import '../../../shared/constants.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  IconData _statusIcon() {
    switch (message.status) {
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.queued:
        return Icons.access_time;
      case MessageStatus.failed:
        return Icons.error_outline;
      case MessageStatus.received:
        return Icons.check_circle_outline;
    }
  }

  Color _statusColor() {
    switch (message.status) {
      case MessageStatus.sent:
        return Colors.grey;
      case MessageStatus.queued:
        return AppColors.queued;
      case MessageStatus.failed:
        return Colors.red;
      case MessageStatus.received:
        return AppColors.online;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        message.isSent ? AppColors.sentBubble : AppColors.receivedBubble;
    final textColor = message.isSent ? Colors.white : Colors.black;
    final alignment =
        message.isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (message.fromPeer != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2, left: 8),
              child: Text(
                message.fromPeer!,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.text, style: TextStyle(color: textColor)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(message.timestamp),
                      style: TextStyle(
                          fontSize: 10, color: textColor.withAlpha(150)),
                    ),
                    if (message.isSent) ...[
                      const SizedBox(width: 4),
                      Icon(_statusIcon(), size: 14, color: _statusColor()),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
