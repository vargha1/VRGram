import 'dart:async';
import 'dart:io';
import 'package:grpc/grpc.dart';
import '../grpc/client.dart';
import '../grpc/relay.pb.dart';

class MediaService {
  final GrpcClient _client;

  /// Media always sent via TCP relay.
  static const _maxFileSize = 10 * 1024 * 1024; // 10 MB

  MediaService(this._client);

  Future<SendMediaResponse> sendFile({
    required String peerPubkey,
    required String filePath,
    required String mimeType,
  }) async {
    final file = File(filePath);
    final fileBytes = await file.readAsBytes();
    if (fileBytes.length > _maxFileSize) {
      throw Exception('File too large (max 10MB)');
    }

    final filename = filePath.split('/').last.split('\\').last;

    try {
      final deadline = Duration(seconds: _estimateTimeout(fileBytes.length));
      final metadata = GrpcClient.authToken != null
          ? {'x-auth-token': GrpcClient.authToken!}
          : null;

      final resp = await _client.stub.sendMedia(
        SendMediaRequest(
          peerPubkey: peerPubkey,
          mediaData: fileBytes,
          filename: filename,
          mimeType: mimeType,
        ),
        options: metadata != null ? CallOptions(metadata: metadata) : null,
      ).timeout(deadline);
      return resp;
    } on TimeoutException {
      throw Exception('Upload timed out');
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  int _estimateTimeout(int fileSize) {
    // TCP: ~1MB/s, generous 60s buffer
    return (fileSize ~/ (1024 * 1024)) + 60;
  }
}
