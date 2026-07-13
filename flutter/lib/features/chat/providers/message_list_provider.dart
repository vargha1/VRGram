import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/platform/app_data_dir.dart';
import '../../../shared/constants.dart';
import '../../peers/providers/peer_provider.dart';
import 'chat_provider.dart';

final pollMessagesProvider = StreamProvider<void>((ref) async* {
  while (true) {
    await Future.delayed(AppDurations.messagePollInterval);
    try {
      final client = GrpcClient();
      final resp = await client.stub.pollMessages(PollRequest());
      // Get peer list to resolve nicknames for notifications
      final peerList = ref.read(peerProvider);
      for (final msg in resp.messages) {
        final serverTs = msg.hasServerTimestampMs() && msg.serverTimestampMs > 0
            ? DateTime.fromMillisecondsSinceEpoch(msg.serverTimestampMs.toInt())
            : DateTime.now();

        ref.read(chatProvider.notifier).addMessage(ChatMessage(
              id: msg.messageId,
              text: utf8.decode(msg.plaintext),
              timestamp: serverTs,
              serverTimestamp: msg.hasServerTimestampMs() && msg.serverTimestampMs > 0
                  ? DateTime.fromMillisecondsSinceEpoch(msg.serverTimestampMs.toInt())
                  : null,
              isSent: false,
              status: MessageStatus.received,
              fromPeer: msg.fromPeer,
              sequenceNumber: msg.hasSequenceNumber() && msg.sequenceNumber > 0
                  ? msg.sequenceNumber.toInt()
                  : null,
            ));

        // Show local notification for incoming message
        final fromPeer = msg.fromPeer;
        if (fromPeer != null && fromPeer.isNotEmpty) {
          final peerNickname = peerList
              .where((p) => p.pubkey == fromPeer)
              .map((p) => p.nickname)
              .firstOrNull;
          // Always show notification even if nickname unknown — use truncated pubkey
          final displayName = peerNickname ?? fromPeer.substring(0, min(8, fromPeer.length)) + '…';
          NotificationService().showMessageNotification(
            peerPubkey: fromPeer,
            peerNickname: displayName,
            messagePreview: utf8.decode(msg.plaintext),
            messageId: msg.messageId,
          );
        }
      }
    } catch (e) {
      debugPrint('[pollMessagesProvider] error: $e');
    }
    yield null;
  }
});

/// Scans media_received/ directory for files downloaded by the daemon.
/// Each media file has a .meta sidecar with MIME type and original filename.
final receivedMediaProvider = StreamProvider<void>((ref) async* {
  final seen = <String>{};
  while (true) {
    await Future.delayed(const Duration(seconds: 3));
    try {
      final dir = Directory('${AppDataDir.path}/media_received');
      if (!await dir.exists()) continue;
      final files = await dir.list().toList();
      for (final entity in files) {
        final path = entity.path;
        // Skip .meta sidecar files and already-processed files
        if (path.endsWith('.meta') || seen.contains(path)) continue;
        seen.add(path);

        final name = entity.path.split('/').last.split('\\').last; // e.g. "abc123.jpg"
        // Extract msgId by removing extension
        final dot = name.lastIndexOf('.');
        if (dot <= 0) continue;
        final msgId = name.substring(0, dot);
        final ext = name.substring(dot);

        // Read .meta sidecar
        String mimeType = 'application/octet-stream';
        String filename = name;
        String? senderPubkey;
        DateTime? serverTimestamp;
        final metaFile = File('$path.meta');
        if (await metaFile.exists()) {
          try {
            final meta = jsonDecode(await metaFile.readAsString());
            mimeType = meta['mime'] as String? ?? mimeType;
            filename = meta['filename'] as String? ?? filename;
            senderPubkey = meta['sender_pubkey'] as String?;
            final tsMs = meta['server_timestamp_ms'] as String?;
            if (tsMs != null) {
              final ts = int.tryParse(tsMs);
              if (ts != null && ts > 0) {
                serverTimestamp = DateTime.fromMillisecondsSinceEpoch(ts);
              }
            }
          } catch (e) {}
        }

        // Use file modification time as fallback timestamp
        final fileTimestamp = serverTimestamp ?? File(path).statSync().modified;

        ref.read(chatProvider.notifier).addMessage(ChatMessage(
              id: msgId,
              text: filename,
              timestamp: fileTimestamp,
              serverTimestamp: serverTimestamp,
              isSent: false,
              status: MessageStatus.received,
              fromPeer: senderPubkey,
              mimeType: mimeType,
              filename: filename,
              localFilePath: path,
            ));
      }
    } catch (e) {
      // Directory may not exist yet
    }
    yield null;
  }
});
