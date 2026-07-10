import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';
import '../../../core/media/media_service.dart';
import '../../../core/platform/app_data_dir.dart';

enum MessageStatus { sent, queued, failed, received, sending }

class ChatMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isSent;
  final MessageStatus status;
  final String? fromPeer;
  final String? toPeer;
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
    this.toPeer,
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
    String? toPeer,
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
      toPeer: toPeer ?? this.toPeer,
      mimeType: mimeType ?? this.mimeType,
      filename: filename ?? this.filename,
      estimatedSeconds: estimatedSeconds ?? this.estimatedSeconds,
      mediaMessageId: mediaMessageId ?? this.mediaMessageId,
      mediaProgress: mediaProgress ?? this.mediaProgress,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'isSent': isSent,
        'status': status.name,
        'fromPeer': fromPeer,
        'toPeer': toPeer,
        'mimeType': mimeType,
        'filename': filename,
        'estimatedSeconds': estimatedSeconds,
        'mediaMessageId': mediaMessageId,
        'mediaProgress': mediaProgress,
        'localFilePath': localFilePath,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        text: json['text'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isSent: json['isSent'] as bool,
        status: MessageStatus.values
            .firstWhere((e) => e.name == json['status']),
        fromPeer: json['fromPeer'] as String?,
        toPeer: json['toPeer'] as String?,
        mimeType: json['mimeType'] as String?,
        filename: json['filename'] as String?,
        estimatedSeconds: json['estimatedSeconds'] as int?,
        mediaMessageId: json['mediaMessageId'] as String?,
        mediaProgress: (json['mediaProgress'] as num?)?.toDouble(),
        localFilePath: json['localFilePath'] as String?,
      );
}

class ChatList extends Notifier<List<ChatMessage>> {
  Timer? _pollTimer;
  static const _fileName = 'messages.json';
  bool _loaded = false;

  @override
  List<ChatMessage> build() {
    ref.onDispose(() => _pollTimer?.cancel());
    _load();
    return [];
  }

  Future<void> _load() async {
    try {
      final file = AppDataDir.file(_fileName);
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as List;
        final loaded = json
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
        // Only replace state if no messages were added before load completed
        if (!_loaded) {
          state = loaded;
          _loaded = true;
          debugPrint('[ChatList] loaded ${state.length} messages');
        }
      } else {
        _loaded = true;
      }
    } catch (e) {
      debugPrint('[ChatList] failed to load messages: $e');
      _loaded = true;
    }
  }

  Future<void> _save() async {
    if (AppDataDir.path.isEmpty) return;
    try {
      final file = AppDataDir.file(_fileName);
      await file.writeAsString(
          jsonEncode(state.map((m) => m.toJson()).toList()));
    } catch (e) {
      debugPrint('[ChatList] failed to save messages: $e');
    }
  }

  void addMessage(ChatMessage msg) {
    // Skip duplicates — same messageId already exists
    if (state.any((m) => m.id == msg.id)) return;
    state = [...state, msg];
    _save();
  }

  void updateMessage(String id, ChatMessage updated) {
    state = state.map((m) => m.id == id ? updated : m).toList();
    _save();
  }

  void updateStatus(String id, MessageStatus status) {
    state = state.map((m) {
      if (m.id == id) {
        return m.copyWith(status: status);
      }
      return m;
    }).toList();
    _save();
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

  /// Send a text message: add optimistically, call gRPC, update status.
  Future<bool> sendMessage(String peerPubkey, String text) async {
    final msgId = DateTime.now().millisecondsSinceEpoch.toString();
    debugPrint('[ChatList] sendMessage: id=$msgId to=$peerPubkey text="$text"');

    addMessage(ChatMessage(
      id: msgId,
      text: text,
      timestamp: DateTime.now(),
      isSent: true,
      status: MessageStatus.sent,
      toPeer: peerPubkey,
    ));

    try {
      final client = GrpcClient();
      final resp = await client.stub.sendMessage(SendRequest(
        peerPubkey: peerPubkey,
        plaintext: utf8.encode(text),
      ));
      debugPrint(
          '[ChatList] sendMessage OK: queued=${resp.queued} msgId=${resp.messageId}');
      updateStatus(
          msgId, resp.queued ? MessageStatus.queued : MessageStatus.sent);
      return true;
    } catch (e) {
      debugPrint('[ChatList] sendMessage FAILED: $e');
      updateStatus(msgId, MessageStatus.failed);
      return false;
    }
  }

  void startMediaStatusPolling(String msgId, String mediaMessageId) {
    _pollTimer?.cancel();
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

final chatProvider =
    NotifierProvider<ChatList, List<ChatMessage>>(ChatList.new);

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
        toPeer: params.peerPubkey,
        mimeType: params.mimeType,
        filename: filename,
        estimatedSeconds: null,
      ));

  try {
    final resp = await mediaService.sendFile(
      peerPubkey: params.peerPubkey,
      filePath: params.filePath,
      mimeType: params.mimeType,
    );

    ref.read(chatProvider.notifier).updateMessage(
          msgId,
          ChatMessage(
            id: msgId,
            text: filename,
            timestamp: DateTime.now(),
            isSent: true,
            status: MessageStatus.sending,
            toPeer: params.peerPubkey,
            mimeType: params.mimeType,
            filename: filename,
            estimatedSeconds: resp.estimatedSeconds,
            mediaMessageId: resp.messageId,
          ),
        );

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
