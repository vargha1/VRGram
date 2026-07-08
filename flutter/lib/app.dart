import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/chat/screens/chat_list_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/peers/providers/peer_provider.dart';
import 'features/peers/screens/peer_list_screen.dart';
import 'features/relay_config/screens/relay_config_screen.dart';
import 'features/identity/screens/identity_screen.dart';

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
