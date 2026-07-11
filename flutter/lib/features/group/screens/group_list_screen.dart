import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/group_provider.dart';
import 'create_group_dialog.dart';
import 'group_chat_screen.dart';

class GroupListScreen extends ConsumerStatefulWidget {
  const GroupListScreen({super.key});
  @override
  ConsumerState<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends ConsumerState<GroupListScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh groups from daemon on screen load
    Future.microtask(() => ref.read(groupProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(groupProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showDialog(
            context: context,
            builder: (_) => const CreateGroupDialog(),
          );
          ref.read(groupProvider.notifier).refresh();
        },
        child: const Icon(Icons.add),
      ),
      body: groups.isEmpty
          ? const Center(child: Text('No groups yet'))
          : ListView.builder(
              itemCount: groups.length,
              itemBuilder: (_, i) => ListTile(
                leading: const CircleAvatar(child: Icon(Icons.groups)),
                title: Text(groups[i].name),
                subtitle: Text('${groups[i].members.length} members'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupChatScreen(group: groups[i]),
                  ),
                ),
              ),
            ),
    );
  }
}
