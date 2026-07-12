import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../grpc/client.dart';
import '../grpc/relay.pb.dart';

class MediaService {
  final GrpcClient _client;
  final _uuid = const Uuid();
  
  MediaService(this._client);

  Future<SendMediaResponse> sendFile({
    required String peerPubkey,
    required String filePath,
    required String mimeType,
  }) async {
    final file = File(filePath);
    final fileSize = await file.length();
    if (fileSize > 50 * 1024 * 1024) {
      throw Exception('File too large (max 50MB)');
    }
    
    final transferId = _uuid.v4();
    const chunkSize = 256 * 1024; // 256KB
    
    try {
      final stream = _createUploadStream(transferId, file, chunkSize,
          peerPubkey, filePath, mimeType);
      final resp = await _client.stub.sendMediaStream(stream).timeout(
        Duration(seconds: _estimateTimeout(fileSize)),
      );
      return resp;
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  Stream<MediaUploadChunk> _createUploadStream(
      String transferId, File file, int chunkSize,
      String peerPubkey, String filePath, String mimeType) async* {
    // First chunk: JSON metadata with peer info
    final filename = filePath.split('/').last.split('\\').last;
    final header = jsonEncode({
      'peer_pubkey': peerPubkey,
      'file_name': filename,
      'mime_type': mimeType,
    });
    yield MediaUploadChunk(
      transferId: transferId,
      data: utf8.encode(header),
      chunkIndex: 0,
    );

    // Subsequent chunks: raw file data
    int index = 1;
    final stream = file.openRead();
    await for (final data in stream) {
      for (int offset = 0; offset < data.length; offset += chunkSize) {
        final end = (offset + chunkSize > data.length) ? data.length : offset + chunkSize;
        yield MediaUploadChunk(
          transferId: transferId,
          data: data.sublist(offset, end),
          chunkIndex: index++,
        );
      }
    }
  }

  int _estimateTimeout(int fileSize) {
    // ~10KB/s for DNS, ~1MB/s for TCP
    if (fileSize < 128 * 1024) {
      return (fileSize ~/ (10 * 1024)) + 30; // DNS: ~10KB/s, +30s buffer
    }
    return (fileSize ~/ (1024 * 1024)) + 30; // TCP: ~1MB/s, +30s buffer
  }
}
