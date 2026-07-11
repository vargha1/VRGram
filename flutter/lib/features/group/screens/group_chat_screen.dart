import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/group_provider.dart';

class GroupChatScreen extends ConsumerWidget {
  final ChatGroup group;
  const GroupChatScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) async {
              if (action == 'leave') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Leave Group'),
                    content: Text('Leave "${group.name}"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave')),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await ref.read(groupProvider.notifier).leaveGroup(group.id);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'leave', child: Text('Leave Group')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Group info header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('${group.members.length} members'),
                Text('Admin: ${group.adminPubkey.substring(0, 12)}...'),
              ],
            ),
          ),
          // Members section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text('Members', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text('${group.members.length}'),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: group.members.length,
              itemBuilder: (_, i) {
                final member = group.members[i];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(member.nickname.isNotEmpty
                        ? member.nickname[0].toUpperCase()
                        : '?'),
                  ),
                  title: Text(member.nickname.isNotEmpty ? member.nickname : member.pubkey.substring(0, 16)),
                  subtitle: Text('${member.pubkey.substring(0, 20)}...'),
                  trailing: member.pubkey == group.adminPubkey
                      ? const Chip(label: Text('Admin', style: TextStyle(fontSize: 11)))
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
