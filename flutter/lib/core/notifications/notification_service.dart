import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Tracks which peer chat is currently open so we don't notify for it.
final activeChatPubkey = ValueNotifier<String?>(null);

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// IDs already notified, to avoid duplicate notifications per session.
  final Set<String> _notifiedMessageIds = {};

  /// Initialize notification channels and permissions.
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      'messages_channel',
      'Messages',
      description: 'Incoming messages from peers',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Request notification permission on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('[NotificationService] initialized');
  }

  /// Show a notification for a new incoming message.
  /// Skips if the user is currently viewing the chat for [peerPubkey].
  Future<void> showMessageNotification({
    required String peerPubkey,
    required String peerNickname,
    required String messagePreview,
    required String messageId,
  }) async {
    if (!_initialized) return;
    // Avoid duplicate notifications for same message
    if (_notifiedMessageIds.contains(messageId)) return;
    _notifiedMessageIds.add(messageId);

    // Skip if user is viewing this chat
    if (activeChatPubkey.value == peerPubkey) return;

    // Truncate long messages for notification body
    final body =
        messagePreview.length > 120
            ? '${messagePreview.substring(0, 120)}…'
            : messagePreview;

    // Use hash of peerPubkey as stable notification ID per peer (max 1 per chat)
    final notificationId = _hashToId(peerPubkey);

    const androidDetails = AndroidNotificationDetails(
      'messages_channel',
      'Messages',
      channelDescription: 'Incoming messages from peers',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Payload: peerPubkey so tap opens the right chat
    await _plugin.show(
      id: notificationId,
      title: peerNickname,
      body: body,
      notificationDetails: details,
      payload: peerPubkey,
    );

    debugPrint(
        '[NotificationService] notification shown for $peerNickname ($peerPubkey)');
  }

  /// Handle notification tap — payload is the peerPubkey.
  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    debugPrint(
        '[NotificationService] notification tapped, payload=$payload');
    // Store payload so app.dart can pick it up and navigate
    _pendingNavigatePubkey = payload;
  }

  /// Pubkey to navigate to when the app gains focus from a notification tap.
  /// App reads this once, then clears it.
  static String? getPendingNavigationPubkey() {
    final key = _pendingNavigatePubkey;
    _pendingNavigatePubkey = null;
    return key;
  }

  static String? _pendingNavigatePubkey;

  /// Simple hash of a string to a positive int for notification IDs.
  int _hashToId(String s) {
    final bytes = s.codeUnits;
    int hash = 0;
    for (final b in bytes) {
      hash = (hash * 31 + b) % (1 << 31);
    }
    return hash.abs();
  }
}
