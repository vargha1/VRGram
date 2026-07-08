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
    final statusAsync = ref.watch(relayStatusProvider);
    final blackoutAsync = ref.watch(isBlackoutProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Relay Servers')),
      body: Column(
        children: [
          // Blackout mode banner
          if (blackoutAsync.asData?.value == true)
            Container(
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
            ),
          // Relay list
          Expanded(
            child: statusAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (statusList) {
                if (statusList.endpoints.isEmpty) {
                  return const Center(child: Text('No relays configured'));
                }
                return ListView.builder(
                  itemCount: statusList.endpoints.length,
                  itemBuilder: (_, i) => RelayTile(
                    status: statusList.endpoints[i],
                    onDelete: () async {
                      await GrpcClient().stub.removeRelay(
                        RelayEndpoint(
                          address: statusList.endpoints[i].address,
                        ),
                      );
                      ref.invalidate(relayStatusProvider);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final address = await showDialog<String>(
            context: context,
            builder: (_) => const AddRelayDialog(),
          );
          if (address != null) {
            await GrpcClient()
                .stub
                .addRelay(RelayEndpoint(address: address));
            ref.invalidate(relayStatusProvider);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
