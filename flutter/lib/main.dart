import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/grpc/client.dart';
import 'core/grpc/relay.pb.dart';
import 'core/platform/app_data_dir.dart';
import 'core/platform/go_bridge.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On mobile, get data directory from native side before starting daemon
  String dataDir = '';
  if (!GoBridge.isDesktop) {
    const channel = MethodChannel('vrgram/bridge');
    try {
      dataDir = await channel.invokeMethod('getDataDir') ?? '';
      AppDataDir.init(dataDir);
    } catch (e) {
      debugPrint('Failed to get dataDir: $e');
    }
  } else {
    dataDir = Directory.current.path;
    AppDataDir.init(dataDir);
  }

  // Start Go daemon
  await GoBridge.start(dataDir: dataDir);

  // Initialize gRPC client
  await GrpcClient().init();

  // Sync persisted data to daemon (blocking — ensures daemon knows relays)
  await _syncRelays();

  runApp(const ProviderScope(child: VRGramApp()));
}

/// Sync persisted relays from JSON to daemon via gRPC.
/// If no file exists, write default relay so subsequent launches pick it up.
Future<void> _syncRelays() async {
  final file = AppDataDir.file('relays.json');
  if (!await file.exists()) {
    // First launch — write default relay so daemon's loadRelaysFromConfig
    // picks it up on next launch. Format: {"relays": ["addr:port"]}
    // (Go daemon expects array of strings, not objects.)
    await file.writeAsString(jsonEncode({
      'relays': [GoBridge.defaultRelay],
    }));
    // Sync the default relay to the running daemon too
    try {
      await GrpcClient().stub.addRelay(RelayEndpoint(
        address: GoBridge.defaultRelay,
      ));
      debugPrint('Added default relay: ${GoBridge.defaultRelay}');
    } catch (e) {
      debugPrint('Failed to sync default relay: $e');
    }
    return;
  }
  // File exists — sync its contents
  try {
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final relays = json['relays'] as List? ?? [];
    for (final entry in relays) {
      // Handle both legacy format (map with 'address') and current format (plain string)
      String addr;
      if (entry is Map) {
        addr = entry['address'] as String;
      } else {
        addr = entry as String;
      }
      await GrpcClient().stub.addRelay(RelayEndpoint(address: addr));
    }
    debugPrint('Synced ${relays.length} relays to daemon');
  } catch (e) {
    debugPrint('Failed to sync relays: $e');
  }
}
