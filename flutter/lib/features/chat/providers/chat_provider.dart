import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';
import '../../../core/media/media_service.dart';
import '../../../core/platform/app_data_dir.dart';

const _uuid = Uuid();

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
  final int? sequenceNumber;
  final DateTime? serverTimestamp;

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
    this.sequenceNumber,
    this.serverTimestamp,
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
    int? sequenceNumber,
    DateTime? serverTimestamp,
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
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      serverTimestamp: serverTimestamp ?? this.serverTimestamp,
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
        'sequenceNumber': sequenceNumber,
        'serverTimestamp': serverTimestamp?.toIso8601String(),
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
        sequenceNumber: json['sequenceNumber'] as int?,
        serverTimestamp: json['serverTimestamp'] != null
            ? DateTime.parse(json['serverTimestamp'] as String)
            : null,
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
          // Stale queued messages from a previous session have no way to
          // make progress — mark them as failed.
          final stale = loaded.map((m) {
            if (m.status == MessageStatus.queued &&
                DateTime.now().difference(m.timestamp).inMinutes > 2) {
              return m.copyWith(status: MessageStatus.failed);
            }
            return m;
          }).toList();
          // Merge with messages added by sendMessage / sendMediaProvider
          // before _load() completed (e.g., during startup race).
          for (final msg in state) {
            if (!stale.any((m) => m.id == msg.id)) {
              stale.add(msg);
            }
          }
          stale.sort((a, b) {
            final aTime = a.serverTimestamp ?? a.timestamp;
            final bTime = b.serverTimestamp ?? b.timestamp;
            final timeCmp = aTime.compareTo(bTime);
            if (timeCmp != 0) return timeCmp;
            final aSeq = a.sequenceNumber;
            final bSeq = b.sequenceNumber;
            if (aSeq != null && bSeq != null) return aSeq.compareTo(bSeq);
            return a.id.compareTo(b.id);
          });
          state = stale;
          _loaded = true;
          debugPrint('[ChatList] loaded ${stale.length} messages (${state.length} in state)');
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
    // If message already exists (by id), update it with relay metadata
    final existingIdx = state.indexWhere((m) => m.id == msg.id);
    if (existingIdx >= 0) {
      final existing = state[existingIdx];
      // Only update metadata from polled version — keep original isSent/status
      final updated = existing.copyWith(
        serverTimestamp: msg.serverTimestamp ?? existing.serverTimestamp,
        sequenceNumber: msg.sequenceNumber ?? existing.sequenceNumber,
      );
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIdx) updated else state[i],
      ];
      _save();
      return;
    }
    final newList = [...state, msg];
    // Sort by effective timestamp (serverTimestamp preferred), then sequence as tiebreaker
    newList.sort((a, b) {
      final aTime = a.serverTimestamp ?? a.timestamp;
      final bTime = b.serverTimestamp ?? b.timestamp;
      final timeCmp = aTime.compareTo(bTime);
      if (timeCmp != 0) return timeCmp;
      // Tiebreaker: sequence number if both have it
      final aSeq = a.sequenceNumber;
      final bSeq = b.sequenceNumber;
      if (aSeq != null && bSeq != null) {
        return aSeq.compareTo(bSeq);
      }
      // Stable sort fallback
      return a.id.compareTo(b.id);
    });
    state = newList;
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

  /// Strip "VRGram identity: " prefix from shared pubkey strings.
  static String _sanitizePubkey(String raw) {
    final s = raw.trim();
    const prefix = 'VRGram identity: ';
    if (s.startsWith(prefix)) {
      return s.substring(prefix.length).trim();
    }
    return s;
  }

  /// Send a text message: add optimistically, call gRPC, update status.
  Future<bool> sendMessage(String peerPubkey, String text) async {
    final pubkey = _sanitizePubkey(peerPubkey);
    final msgId = _uuid.v4();
    debugPrint('[ChatList] sendMessage: id=$msgId to=$pubkey text="$text"');

    addMessage(ChatMessage(
      id: msgId,
      text: text,
      timestamp: DateTime.now(),
      isSent: true,
      status: MessageStatus.sent,
      toPeer: pubkey,
    ));

    try {
      final client = GrpcClient();
      final resp = await client.stub
          .sendMessage(SendRequest(
            peerPubkey: pubkey,
            plaintext: utf8.encode(text),
          ))
          .timeout(const Duration(seconds: 35));
      debugPrint(
          '[ChatList] sendMessage OK: queued=${resp.queued} msgId=${resp.messageId}');
      if (resp.queued) {
        updateStatus(msgId, MessageStatus.queued);
        // If message stays queued for >2 min, the DNS relay is unreachable
        // and the offline queue won't make progress — mark as failed.
        Future.delayed(const Duration(minutes: 2), () {
          final current = state.where((m) => m.id == msgId);
          if (current.isNotEmpty && current.first.status == MessageStatus.queued) {
            debugPrint('[ChatList] queue timeout for $msgId — marking failed');
            updateStatus(msgId, MessageStatus.failed);
          }
        });
      } else {
        updateStatus(msgId, MessageStatus.sent);
      }
      return true;
    } on TimeoutException {
      debugPrint('[ChatList] sendMessage TIMEOUT');
      updateStatus(msgId, MessageStatus.failed);
      return false;
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
        updateMediaProgress(msgId, resp.progressPct / 100.0);
        updateStatus(msgId, _protoStatusToMessage(resp.status));

        if (resp.status == MediaStatusResponse_Status.COMPLETE) {
          _pollTimer?.cancel();
        } else if (resp.status == MediaStatusResponse_Status.FAILED) {
          _pollTimer?.cancel();
        }
      } catch (_) {}
    });
  }

  MessageStatus _protoStatusToMessage(MediaStatusResponse_Status status) {
    switch (status) {
      case MediaStatusResponse_Status.QUEUED: return MessageStatus.sending;
      case MediaStatusResponse_Status.SENDING: return MessageStatus.sending;
      case MediaStatusResponse_Status.ARRIVING: return MessageStatus.sending;
      case MediaStatusResponse_Status.COMPLETE: return MessageStatus.received;
      case MediaStatusResponse_Status.FAILED: return MessageStatus.failed;
      default: return MessageStatus.sending;
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
  final msgId = _uuid.v4();

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
    // Show error in chat bubble so user sees what went wrong
    ref.read(chatProvider.notifier).updateMessage(
      msgId,
      ChatMessage(
        id: msgId,
        text: 'Send failed: $e',
        timestamp: DateTime.now(),
        isSent: true,
        status: MessageStatus.failed,
        toPeer: params.peerPubkey,
        mimeType: null,
        filename: filename,
      ),
    );
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
