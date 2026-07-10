import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/dht_provider.dart';
import '../../../shared/constants.dart';

class DhtStatusScreen extends ConsumerWidget {
  const DhtStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(dhtStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Network Status')),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (status) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusTile(
              icon: Icons.wifi,
              label: 'DHT Connected',
              value: status.dhtConnected ? 'Connected' : 'Disconnected',
              color: status.dhtConnected ? AppColors.online : AppColors.offline,
            ),
            const Divider(),
            _StatusTile(
              icon: Icons.hub,
              label: 'Relays Discovered',
              value: '${status.discoveredRelays}',
              color: status.discoveredRelays > 0
                  ? AppColors.online
                  : AppColors.offline,
            ),
            const Divider(),
            _StatusTile(
              icon: Icons.lan,
              label: 'libp2p Available',
              value: status.libp2pAvailable ? 'Yes' : 'No',
              color: status.libp2pAvailable
                  ? AppColors.online
                  : AppColors.offline,
            ),
            const Divider(),
            _StatusTile(
              icon: Icons.dns,
              label: 'DNS Mode',
              value: status.dnsMode,
              color: status.dnsMode == 'blackout'
                  ? AppColors.blackoutBanner
                  : AppColors.online,
            ),
            const SizedBox(height: 24),
            Center(
              child: FilledButton.icon(
                onPressed: () => context.push('/relays'),
                icon: const Icon(Icons.dns),
                label: const Text('Relay Servers'),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: FilledButton.icon(
                onPressed: () => ref.invalidate(dhtStatusProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatusTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
