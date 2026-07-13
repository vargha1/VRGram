import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/notifications/notification_service.dart';
import 'features/chat/providers/message_list_provider.dart';
import 'features/chat/screens/chat_list_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/peers/providers/peer_provider.dart';
import 'features/peers/screens/peer_list_screen.dart';
import 'features/relay_config/screens/relay_config_screen.dart';
import 'features/identity/screens/identity_screen.dart';
import 'shared/constants.dart';
import 'core/theme_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (_, state) =>
            ChatScreen(peer: state.extra as Peer),
      ),
      GoRoute(
        path: '/peers',
        builder: (_, _) => const PeerListScreen(),
      ),
      GoRoute(
        path: '/relays',
        builder: (_, _) => const RelayConfigScreen(),
      ),
      GoRoute(
        path: '/identity',
        builder: (_, _) => const IdentityScreen(),
      ),
    ],
  );
});

class VRGramApp extends ConsumerStatefulWidget {
  const VRGramApp({super.key});

  @override
  ConsumerState<VRGramApp> createState() => _VRGramAppState();
}

class _VRGramAppState extends ConsumerState<VRGramApp> {
  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    // Start global message polling (runs for app lifetime)
    ref.watch(pollMessagesProvider);
    // Start media file scanner (checks daemon-downloaded media files)
    ref.watch(receivedMediaProvider);

    // Handle notification tap navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final peerPubkey = NotificationService.getPendingNavigationPubkey();
      if (peerPubkey != null && context.mounted) {
        // Find peer in the peer list
        final peers = ref.read(peerProvider);
        final peer = peers.where((p) => p.pubkey == peerPubkey).firstOrNull;
        if (peer != null) {
          context.go('/chat', extra: peer);
        } else {
          // Peer not found — navigate to peers list so user can add them
          context.go('/peers');
        }
      }
    });

    return MaterialApp.router(
      title: AppStrings.appName,
      theme: ThemeData(
        colorSchemeSeed: AppColors.primary,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: AppColors.primary,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
