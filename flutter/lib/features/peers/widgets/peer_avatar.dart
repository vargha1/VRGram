import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/peer_provider.dart';

class PeerAvatar extends ConsumerWidget {
  final String pubkey;
  final String nickname;
  final double radius;

  const PeerAvatar({
    super.key,
    required this.pubkey,
    required this.nickname,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picAsync = ref.watch(peerProfilePicProvider(pubkey));
    final theme = Theme.of(context);

    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      backgroundImage: picAsync.whenOrNull(
        data: (path) => path != null ? FileImage(File(path)) : null,
      ),
      child: picAsync.whenOrNull(
            data: (path) => path != null
                ? null
                : Text(
                    nickname.isNotEmpty
                        ? nickname[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: radius * 0.8,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
          ) ??
          Text(
            nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: radius * 0.8,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
    );
  }
}
