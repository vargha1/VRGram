import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/relay_provider.dart';
import '../widgets/relay_tile.dart';
import 'add_relay_dialog.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';
import '../../../shared/constants.dart';

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