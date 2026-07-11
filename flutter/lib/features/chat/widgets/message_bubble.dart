import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/chat_provider.dart';
import '../../../shared/constants.dart';
import 'media_bubble.dart';
import '../../peers/providers/peer_provider.dart';

class MessageBubble extends ConsumerWidget {
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
      case MessageStatus.sending:
        return Icons.hourglass_top;
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
      case MessageStatus.sending:
        return AppColors.queued;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgColor =
        message.isSent ? AppColors.sentBubble : AppColors.receivedBubble;
    final textColor = message.isSent ? Colors.white : Colors.black;
    final alignment =
        message.isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    // Resolve sender nickname from pubkey
    String? senderLabel;
    if (message.fromPeer != null) {
      final nickname =
          ref.read(peerProvider.notifier).findNicknameByPubkey(message.fromPeer!);
      senderLabel = nickname ??
          message.fromPeer!.substring(0, min(16, message.fromPeer!.length));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (senderLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2, left: 8),
              child: Text(
                senderLabel,
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
                if (message.mimeType != null)
                  MediaBubble(message: message)
                else
                  Text(message.text, style: TextStyle(color: textColor)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(message.serverTimestamp ?? message.timestamp),
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
