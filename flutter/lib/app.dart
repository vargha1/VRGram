import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/notifications/notification_service.dart';
import 'features/chat/providers/message_list_provider.dart';
import 'features/chat/screens/chat_list_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/peers/providers/peer_provider.dart';
import 'features/peers/screens/peer_list_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/relay_config/screens/relay_config_screen.dart';
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
        path: '/profile',
        builder: (_, _) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/peers',
        builder: (_, _) => const PeerListScreen(),
      ),
      GoRoute(
        path: '/relays',
        builder: (_, _) => const RelayConfigScreen(),
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
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
          surface: const Color(0xFF111318),
          surfaceContainerLowest: const Color(0xFF0C0E12),
          surfaceContainerLow: const Color(0xFF16181E),
          surfaceContainer: const Color(0xFF1B1D24),
          surfaceContainerHigh: const Color(0xFF252830),
          surfaceContainerHighest: const Color(0xFF30333C),
          onSurface: const Color(0xFFE3E2E6),
          onSurfaceVariant: const Color(0xFFC4C6D0),
          outline: const Color(0xFF8E9099),
          outlineVariant: const Color(0xFF44474F),
        ),
        scaffoldBackgroundColor: const Color(0xFF111318),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF16181E),
          foregroundColor: Color(0xFFE3E2E6),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1B1D24),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF2A2D35)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF16181E),
          surfaceTintColor: Colors.transparent,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF1B1D24),
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF1B1D24),
          surfaceTintColor: Colors.transparent,
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: const Color(0xFF252830),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
