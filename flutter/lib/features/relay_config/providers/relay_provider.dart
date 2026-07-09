import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';
import '../../../shared/constants.dart';

class RelayConfig {
  final String address;
  final String dnsResolver;
  RelayConfig({required this.address, required this.dnsResolver});

  Map<String, dynamic> toJson() => {'address': address, 'dnsResolver': dnsResolver};

  factory RelayConfig.fromJson(Map<String, dynamic> json) => RelayConfig(
    address: json['address'] as String,
    dnsResolver: json['dnsResolver'] as String? ?? '8.8.8.8:53',
  );
}

class RelayList extends Notifier<List<RelayConfig>> {
  static const _fileName = 'relays.json';
  String _defaultDnsResolver = '8.8.8.8:53';

  String get _filePath => '${Directory.current.path}/$_fileName';

  @override
  List<RelayConfig> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    try {
      final file = File(_filePath);
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final relays = (json['relays'] as List? ?? [])
            .map((e) => RelayConfig.fromJson(e as Map<String, dynamic>))
            .toList();
        _defaultDnsResolver = json['dnsResolver'] as String? ?? '8.8.8.8:53';
        state = relays;
      }
    } catch (e) {
      debugPrint('Failed to load relays: $e');
    }
  }

  Future<void> _save() async {
    try {
      final file = File(_filePath);
      await file.writeAsString(jsonEncode({
        'relays': state.map((r) => r.toJson()).toList(),
        'dnsResolver': _defaultDnsResolver,
      }));
    } catch (e) {
      debugPrint('Failed to save relays: $e');
    }
  }

  Future<void> addRelay(String address, String dnsResolver) async {
    state = [...state, RelayConfig(address: address, dnsResolver: dnsResolver)];
    await _save();
  }

  Future<void> removeRelay(int index) async {
    state = [...state]..removeAt(index);
    await _save();
  }

  Future<void> setDnsResolver(String dnsResolver) async {
    _defaultDnsResolver = dnsResolver;
    await _save();
  }

  String get defaultDnsResolver => _defaultDnsResolver;
}

final relayProvider = NotifierProvider<RelayList, List<RelayConfig>>(RelayList.new);

final relayStatusProvider =
    FutureProvider.autoDispose<RelayStatusList>((ref) async {
  final client = GrpcClient();
  return client.stub.getRelayStatus(Empty());
});

final autoRefreshRelayStatus =
    StreamProvider.autoDispose<RelayStatusList>((ref) async* {
  while (true) {
    await Future.delayed(AppDurations.relayStatusInterval);
    final status = await ref.read(relayStatusProvider.future);
    yield status;
  }
});

final isBlackoutProvider = FutureProvider<bool>((ref) async {
  final status = await ref.read(relayStatusProvider.future);
  return status.endpoints.any((e) => e.blackoutMode);
});