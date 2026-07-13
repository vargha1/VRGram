import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/grpc/client.dart';
import '../../../core/grpc/relay.pb.dart';
import '../../../core/platform/app_data_dir.dart';

/// Current identity info (pubkey, nickname, bio).
final identityProvider = FutureProvider<IdentityInfo>((ref) async {
  final client = GrpcClient();
  return client.stub.getIdentity(Empty());
});

/// Shortened pubkey for display.
final identityShortProvider = Provider<String>((ref) {
  final identity = ref.watch(identityProvider);
  return identity.when(
    data: (info) {
      if (info.pubkey.length > 16) {
        return '${info.pubkey.substring(0, 8)}...${info.pubkey.substring(info.pubkey.length - 8)}';
      }
      return info.pubkey;
    },
    loading: () => '',
    error: (_, _) => '',
  );
});

/// Save profile (nickname + bio) to daemon. Invalidates identityProvider on success.
final updateProfileProvider = FutureProvider.family<void, ProfileParams>((ref, params) async {
  final client = GrpcClient();
  await client.stub.updateProfile(ProfileInfo(
    nickname: params.nickname,
    bio: params.bio,
  ));
  ref.invalidate(identityProvider);
});

class ProfileParams {
  final String nickname;
  final String bio;
  ProfileParams({required this.nickname, required this.bio});
}

/// Upload profile picture to daemon.
final uploadProfilePicProvider = FutureProvider.family<void, String>((ref, imagePath) async {
  final file = File(imagePath);
  final bytes = await file.readAsBytes();
  final client = GrpcClient();
  await client.stub.setProfilePic(SetProfilePicRequest(
    imageData: bytes,
    mimeType: 'image/jpeg',
  ));
  ref.invalidate(profilePicProvider);
});

/// Download profile picture from daemon. Returns null bytes if no pic set.
final profilePicProvider = FutureProvider<Uint8List?>((ref) async {
  final client = GrpcClient();
  final resp = await client.stub.getProfilePic(Empty());
  if (resp.imageData.isEmpty) return null;
  return resp.imageData;
});

/// Cached local path for profile pic (avoids re-downloading every rebuild).
final profilePicLocalPathProvider = Provider<String?>((ref) {
  final picAsync = ref.watch(profilePicProvider);
  return picAsync.when(
    data: (bytes) {
      if (bytes == null) return null;
      // Write to temp file so Image.file can display it
      final path = '${AppDataDir.path}/profile_pic_cache.jpg';
      File(path).writeAsBytesSync(bytes);
      return path;
    },
    loading: () => null,
    error: (_, _) => null,
  );
});
