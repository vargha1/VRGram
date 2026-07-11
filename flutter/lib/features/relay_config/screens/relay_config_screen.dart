import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/relay_provider.dart';
import '../widgets/relay_tile.dart';
import 'add_relay_dialog.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';
import '../../../core/platform/app_data_dir.dart';
import '../../../shared/constants.dart';

/// DNS transport modes the user can select.
enum TransportMode { auto, tcp, udp }

final transportModeProvider =
    NotifierProvider<TransportModeNotifier, TransportMode>(TransportModeNotifier.new);

class TransportModeNotifier extends Notifier<TransportMode> {
  @override
  TransportMode build() {
    _load();
    return TransportMode.auto;
  }

  Future<void> _load() async {
    try {
      final file = AppDataDir.file('transport_mode');
      if (await file.exists()) {
        final val = (await file.readAsString()).trim().toLowerCase();
        switch (val) {
          case 'tcp':
            state = TransportMode.tcp;
            break;
          case 'udp':
            state = TransportMode.udp;
            break;
          default:
            state = TransportMode.auto;
        }
      }
    } catch (_) {}
  }

  Future<void> setMode(TransportMode mode) async {
    state = mode;
    try {
      final names = {TransportMode.auto: 'auto', TransportMode.tcp: 'tcp', TransportMode.udp: 'udp'};
      await AppDataDir.file('transport_mode').writeAsString(names[mode]!);
    } catch (_) {}
  }
}

final chunkSizeProvider =
    NotifierProvider<ChunkSizeNotifier, int>(ChunkSizeNotifier.new);

class ChunkSizeNotifier extends Notifier<int> {
  @override
  int build() {
    _load();
    return 75;
  }

  static const int min = 32;
  static const int max = 200;

  Future<void> _load() async {
    try {
      final file = AppDataDir.file('chunk_size');
      if (await file.exists()) {
        final val = int.tryParse((await file.readAsString()).trim());
        if (val != null && val >= min && val <= max) {
          state = val;
        }
      }
    } catch (_) {}
  }

  Future<void> setSize(int size) async {
    final clamped = size.clamp(min, max);
    state = clamped;
    try {
      await AppDataDir.file('chunk_size').writeAsString(clamped.toString());
    } catch (_) {}
  }
}

class RelayConfigScreen extends ConsumerWidget {
  const RelayConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relays = ref.watch(relayProvider);
    final dnsResolver = ref.watch(relayProvider.notifier).defaultDnsResolver;
    final statusAsync = ref.watch(relayStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Relay Servers')),
      body: Column(
        children: [
          // DNS Resolver field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: TextEditingController(text: dnsResolver),
              decoration: const InputDecoration(
                labelText: 'Default DNS Resolver',
                hintText: '8.8.8.8:53',
              ),
              onSubmitted: (value) async {
                if (value.trim().isNotEmpty) {
                  await ref.read(relayProvider.notifier).setDnsResolver(value.trim());
                }
              },
            ),
          ),
          // DNS transport mode selector
          Consumer(builder: (context, ref, _) {
            final mode = ref.watch(transportModeProvider);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Text('DNS transport: ', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  _ModeChip('Auto', TransportMode.auto, mode, ref),
                  const SizedBox(width: 4),
                  _ModeChip('TCP', TransportMode.tcp, mode, ref),
                  const SizedBox(width: 4),
                  _ModeChip('UDP', TransportMode.udp, mode, ref),
                ],
              ),
            );
          }),
          const Divider(height: 8),
          // DNS chunk size
          Consumer(builder: (context, ref, _) {
            final size = ref.watch(chunkSizeProvider);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Text('Chunk size:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 160,
                    child: Slider(
                      value: size.toDouble(),
                      min: ChunkSizeNotifier.min.toDouble(),
                      max: ChunkSizeNotifier.max.toDouble(),
                      divisions: (ChunkSizeNotifier.max - ChunkSizeNotifier.min) ~/ 8,
                      label: '$size B',
                      onChanged: (v) => ref.read(chunkSizeProvider.notifier).setSize(v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text('$size B', style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 4),
          // Blackout mode banner
          statusAsync.when(
            data: (statusList) {
              if (statusList.endpoints.any((e) => e.blackoutMode)) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: AppColors.blackoutBanner,
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppStrings.blackoutMode,
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Relay list
          Expanded(
            child: statusAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (statusList) {
                if (relays.isEmpty) {
                  return const Center(child: Text('No relays configured'));
                }
                return ListView.builder(
                  itemCount: relays.length,
                  itemBuilder: (_, i) {
                    final relay = relays[i];
                    final status = statusList.endpoints.firstWhere(
                      (s) => s.address == relay.address,
                      orElse: () => RelayStatus(address: relay.address, reachable: false),
                    );
                    return RelayTile(
                      status: status,
                      dnsResolver: relay.dnsResolver,
                      onDelete: () async {
                        await GrpcClient().stub.removeRelay(RelayEndpoint(address: relay.address));
                        await ref.read(relayProvider.notifier).removeRelay(i);
                        ref.invalidate(relayStatusProvider);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showDialog<Map<String, String>>(
            context: context,
            builder: (_) => const AddRelayDialog(),
          );
          if (result != null) {
            await GrpcClient().stub.addRelay(RelayEndpoint(address: result['address']!));
            await ref.read(relayProvider.notifier).addRelay(result['address']!, result['dnsResolver']!);
            ref.invalidate(relayStatusProvider);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// A small selectable chip for transport mode.
class _ModeChip extends StatelessWidget {
  final String label;
  final TransportMode value;
  final TransportMode current;
  final WidgetRef ref;

  const _ModeChip(this.label, this.value, this.current, this.ref);

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => ref.read(transportModeProvider.notifier).setMode(value),
      visualDensity: VisualDensity.compact,
    );
  }
}