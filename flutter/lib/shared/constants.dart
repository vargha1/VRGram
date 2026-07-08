import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF1A73E8);
  static const sentBubble = Color(0xFF1A73E8);
  static const receivedBubble = Color(0xFFE8E8E8);
  static const blackoutBanner = Color(0xFFD32F2F);
  static const online = Color(0xFF4CAF50);
  static const offline = Color(0xFF9E9E9E);
  static const queued = Color(0xFFFFC107);
}

class AppStrings {
  static const appName = 'VRGram';
  static const daemonNotRunning = 'Daemon not running';
  static const connectionLost = 'Connection lost';
  static const blackoutMode = 'Blackout mode \u2014 using domestic relays only';
  static const noPeers = 'Add a peer to start messaging';
  static const noMessages = 'No messages yet';
  static const send = 'Send';
  static const addRelay = 'Add relay';
  static const addPeer = 'Add peer';
  static const yourPublicKey = 'Your Public Key';
  static const copyKey = 'Copy';
  static const keyCopied = 'Public key copied';
}

class AppDurations {
  static const messagePollInterval = Duration(seconds: 5);
  static const relayStatusInterval = Duration(seconds: 10);
  static const daemonStartDelay = Duration(milliseconds: 500);
}
