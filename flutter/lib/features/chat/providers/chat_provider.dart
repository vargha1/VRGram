import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';
import '../../../core/media/media_service.dart';

enum MessageStatus { sent, queued, failed, received, sending }

class ChatMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isSent;
  final MessageStatus status;
  final String? fromPeer;
  final String? mimeType;
  final String? filename;
  final int? estimatedSeconds;
  final String? mediaMessageId;
  final double? mediaProgress;
  final String? localFilePath;

  ChatMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isSent,
    required this.status,
    this.fromPeer,
    this.mimeType,
    this.filename,
    this.estimatedSeconds,
    this.mediaMessageId,
    this.mediaProgress,
    this.localFilePath,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    DateTime? timestamp,
    bool? isSent,
    MessageStatus? status,
    String? fromPeer,
    String? mimeType,
    String? filename,
    int? estimatedSeconds,
    String? mediaMessageId,
    double? mediaProgress,
    String? localFilePath,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isSent: isSent ?? this.isSent,
      status: status ?? this.status,
      fromPeer: fromPeer ?? this.fromPeer,
      mimeType: mimeType ?? this.mimeType,
      filename: filename ?? this.filename,
      estimatedSeconds: estimatedSeconds ?? this.estimatedSeconds,
      mediaMessageId: mediaMessageId ?? this.mediaMessageId,
      mediaProgress: mediaProgress ?? this.mediaProgress,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }
}

class ChatList extends Notifier<List<ChatMessage>> {
  Timer? _pollTimer;

  @override
  List<ChatMessage> build() {
    ref.onDispose(() => _pollTimer?.cancel());
    return [];
  }

  void addMessage(ChatMessage msg) {
    state = [...state, msg];
  }

  void updateMessage(String id, ChatMessage updated) {
    state = state.map((m) => m.id == id ? updated : m).toList();
  }

  void updateStatus(String id, MessageStatus status) {
    state = state.map((m) {
      if (m.id == id) {
        return m.copyWith(status: status);
      }
      return m;
    }).toList();
  }

  void updateMediaProgress(String id, double progress) {
    state = state.map((m) {
      if (m.id == id) {
        return m.copyWith(mediaProgress: progress);
      }
      return m;
    }).toList();
  }

  void updateMediaMessageId(String id, String mediaMessageId) {
    state = state.map((m) {
      if (m.id == id) {
        return m.copyWith(mediaMessageId: mediaMessageId);
      }
      return m;
    }).toList();
  }

  void startMediaStatusPolling(String msgId, String mediaMessageId) {
    _pollTimer?.cancel();
    // I6: Store client reference once instead of creating per tick
    final client = GrpcClient();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final resp = await client.stub
            .getMediaStatus(GetMediaStatusRequest(messageId: mediaMessageId));
        final progress = _statusToProgress(resp.status);
        updateMediaProgress(msgId, progress);

        if (resp.status == MediaStatusResponse_Status.COMPLETE) {
          _pollTimer?.cancel();
          updateStatus(msgId, MessageStatus.received);
        } else if (resp.status == MediaStatusResponse_Status.FAILED) {
          _pollTimer?.cancel();
          updateStatus(msgId, MessageStatus.failed);
        }
      } catch (_) {
        // Polling errors are ignored; next tick retries
      }
    });
  }

  double _statusToProgress(MediaStatusResponse_Status status) {
    switch (status) {
      case MediaStatusResponse_Status.QUEUED:
        return 0.1;
      case MediaStatusResponse_Status.SENDING:
        return 0.3;
      case MediaStatusResponse_Status.ARRIVING:
        return 0.7;
      case MediaStatusResponse_Status.COMPLETE:
        return 1.0;
      case MediaStatusResponse_Status.FAILED:
        return 0.0;
      default:
        return 0.0;
    }
  }
}

final chatProvider = NotifierProvider<ChatList, List<ChatMessage>>(ChatList.new);

final sendMessageProvider =
    FutureProvider.family<void, SendParams>((ref, params) async {
  final client = GrpcClient();
  final msgId = DateTime.now().millisecondsSinceEpoch.toString();

  ref.read(chatProvider.notifier).addMessage(ChatMessage(
        id: msgId,
        text: params.text,
        timestamp: DateTime.now(),
        isSent: true,
        status: MessageStatus.sent,
      ));

  try {
    final resp = await client.stub.sendMessage(SendRequest(
      peerPubkey: params.peerPubkey,
      plaintext: utf8.encode(params.text),
    ));
    ref.read(chatProvider.notifier).updateStatus(
          msgId,
          resp.queued ? MessageStatus.queued : MessageStatus.sent,
        );
  } catch (e) {
    ref.read(chatProvider.notifier).updateStatus(msgId, MessageStatus.failed);
    rethrow;
  }
});

class SendParams {
  final String peerPubkey;
  final String text;
  SendParams({required this.peerPubkey, required this.text});
}

final sendMediaProvider =
    FutureProvider.family<SendMediaResponse, SendMediaParams>(
        (ref, params) async {
  final client = GrpcClient();
  final mediaService = MediaService(client);
  final msgId = DateTime.now().millisecondsSinceEpoch.toString();

  // Extract filename for display
  final filename = params.filePath.split('/').last.split('\\').last;

  // Add pending message immediately
  ref.read(chatProvider.notifier).addMessage(ChatMessage(
        id: msgId,
        text: filename,
        timestamp: DateTime.now(),
        isSent: true,
        status: MessageStatus.sending,
        mimeType: params.mimeType,
        filename: filename,
        estimatedSeconds: null, // set after response
      ));

  try {
    final resp = await mediaService.sendFile(
      peerPubkey: params.peerPubkey,
      filePath: params.filePath,
      mimeType: params.mimeType,
    );

    // Update with estimated time and messageId from server
    ref.read(chatProvider.notifier).updateMessage(
          msgId,
          ChatMessage(
            id: msgId,
            text: filename,
            timestamp: DateTime.now(),
            isSent: true,
            status: MessageStatus.sending,
            mimeType: params.mimeType,
            filename: filename,
            estimatedSeconds: resp.estimatedSeconds,
            mediaMessageId: resp.messageId,
          ),
        );

    // Start polling for transfer status
    ref.read(chatProvider.notifier).startMediaStatusPolling(
          msgId,
          resp.messageId,
        );

    return resp;
  } catch (e) {
    ref.read(chatProvider.notifier).updateStatus(msgId, MessageStatus.failed);
    rethrow;
  }
});

class SendMediaParams {
  final String peerPubkey;
  final String filePath;
  final String mimeType;

  SendMediaParams({
    required this.peerPubkey,
    required this.filePath,
    required this.mimeType,
  });
}
