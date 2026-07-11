import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';
import '../../../core/platform/app_data_dir.dart';

class GroupMember {
  final String pubkey;
  final String nickname;
  final String role;
  GroupMember({required this.pubkey, this.nickname = '', this.role = 'member'});

  Map<String, dynamic> toJson() => {'pubkey': pubkey, 'nickname': nickname, 'role': role};
  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
    pubkey: j['pubkey'] as String,
    nickname: j['nickname'] as String? ?? '',
    role: j['role'] as String? ?? 'member',
  );
}

class ChatGroup {
  final String id;
  final String name;
  final String adminPubkey;
  final List<GroupMember> members;
  ChatGroup({required this.id, required this.name, required this.adminPubkey, required this.members});

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'admin_pubkey': adminPubkey,
    'members': members.map((m) => m.toJson()).toList(),
  };
  factory ChatGroup.fromJson(Map<String, dynamic> j) => ChatGroup(
    id: j['id'] as String,
    name: j['name'] as String,
    adminPubkey: j['admin_pubkey'] as String,
    members: (j['members'] as List).map((e) => GroupMember.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

class GroupList extends Notifier<List<ChatGroup>> {
  static const _fileName = 'groups.json';

  @override
  List<ChatGroup> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    try {
      final file = AppDataDir.file(_fileName);
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as List;
        state = json.map((e) => ChatGroup.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Failed to load groups: $e');
    }
  }

  Future<void> _save() async {
    try {
      final file = AppDataDir.file(_fileName);
      await file.writeAsString(jsonEncode(state.map((g) => g.toJson()).toList()));
    } catch (e) {
      debugPrint('Failed to save groups: $e');
    }
  }

  /// Refresh groups list from daemon via gRPC
  Future<void> refresh() async {
    try {
      final client = GrpcClient();
      final resp = await client.stub.listGroups(Empty());
      final groups = resp.groups.map((g) => ChatGroup(
        id: g.groupId,
        name: g.name,
        adminPubkey: g.adminPubkey,
        members: g.members.map((m) => GroupMember(
          pubkey: m.pubkey,
          nickname: m.nickname,
          role: m.role,
        )).toList(),
      )).toList();
      state = groups;
      await _save();
    } catch (e) {
      debugPrint('refresh groups failed: $e');
    }
  }

  Future<void> createGroup(String name, List<String> memberPubkeys) async {
    try {
      final client = GrpcClient();
      await client.stub.createGroup(CreateGroupRequest(
        name: name,
        memberPubkeys: memberPubkeys,
      ));
      await refresh();
    } catch (e) {
      debugPrint('createGroup failed: $e');
      rethrow;
    }
  }

  void addGroup(ChatGroup group) {
    if (state.any((g) => g.id == group.id)) return;
    state = [...state, group];
    _save();
  }

  Future<void> leaveGroup(String groupId) async {
    try {
      final client = GrpcClient();
      await client.stub.leaveGroup(LeaveGroupRequest(groupId: groupId));
    } catch (e) {
      debugPrint('leaveGroup failed: $e');
    }
    state = state.where((g) => g.id != groupId).toList();
    _save();
  }
}

final groupProvider = NotifierProvider<GroupList, List<ChatGroup>>(GroupList.new);
