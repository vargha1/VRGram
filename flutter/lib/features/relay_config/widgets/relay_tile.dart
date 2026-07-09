import 'package:flutter/material.dart';
import '../../../core/grpc/relay.pb.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/constants.dart';

class RelayTile extends StatelessWidget {
  final RelayStatus status;
  final String? dnsResolver;
  final VoidCallback onDelete;

  const RelayTile({super.key, required this.status, this.dnsResolver, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = status.blackoutMode
        ? AppColors.blackoutBanner
        : status.reachable
            ? AppColors.online
            : AppColors.offline;
    final label = status.blackoutMode
        ? 'Blackout'
        : status.reachable
            ? 'Online'
            : 'Offline';

    return ListTile(
      leading: Icon(Icons.dns, color: color),
      title: Text(status.address),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(color: color, label: label),
              if (status.latencyMs > 0) ...[
                const SizedBox(width: 8),
                Text('${status.latencyMs}ms', style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
          if (dnsResolver != null && dnsResolver!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('DNS: $dnsResolver', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
    );
  }
}
