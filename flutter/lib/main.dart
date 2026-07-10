import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/grpc/client.dart';
import 'core/grpc/relay.pb.dart';
import 'core/platform/go_bridge.dart';
import 'shared/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On mobile, get data directory from native side before starting daemon
  String dataDir = '';
  if (!GoBridge.isDesktop) {
    const channel = MethodChannel('vrgram/bridge');
    try {
      dataDir = await channel.invokeMethod('getDataDir') ?? '';
    } catch (e) {
      debugPrint('Failed to get dataDir: $e');
    }
  }

  // Start Go daemon
  await GoBridge.start(dataDir: dataDir);

  // Initialize gRPC client
  await GrpcClient().init();

  // Sync persisted data to daemon
  if (!GoBridge.isDesktop) {
    await _syncPeers();
    await _syncRelays();
  }

  runApp(const ProviderScope(child: VRGramApp()));
}

/// Sync persisted peers from JSON to daemon via gRPC.
Future<void> _syncPeers() async {
  final file = File('${Directory.current.path}/peers.json');
  if (!await file.exists()) return;
  try {
    final json = jsonDecode(await file.readAsString()) as List;
    for (final entry in json) {
      final peer = entry as Map<String, dynamic>;
      await GrpcClient().stub.addPeer(PeerInfo(
        nickname: peer['nickname'] as String,
        pubkey: peer['pubkey'] as String,
      ));
    }
    debugPrint('Synced ${json.length} peers to daemon');
  } catch (e) {
    debugPrint('Failed to sync peers: $e');
  }
}

/// Sync persisted relays from JSON to daemon via gRPC.
Future<void> _syncRelays() async {
  final file = File('${Directory.current.path}/relays.json');
  if (!await file.exists()) return;
  try {
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final relays = json['relays'] as List? ?? [];
    for (final entry in relays) {
      final relay = entry as Map<String, dynamic>;
      await GrpcClient().stub.addRelay(RelayEndpoint(
        address: relay['address'] as String,
      ));
    }
    debugPrint('Synced ${relays.length} relays to daemon');
  } catch (e) {
    debugPrint('Failed to sync relays: $e');
  }
}

class VRGramApp extends ConsumerWidget {
  const VRGramApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      theme: ThemeData(
        colorSchemeSeed: AppColors.primary,
        useMaterial3: true,
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
