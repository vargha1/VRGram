import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:grpc/grpc.dart';
import '../grpc/client.dart';
import '../grpc/relay.pb.dart';

class MediaService {
  final GrpcClient _client;

  /// Daemon decides transport by file size: DNS for <60KB, TCP for >=60KB.
  /// Since DNS relay is unreliable, we pad small files to force TCP.
  static const int _tcpThreshold = 60 * 1024; // 60 KB

  MediaService(this._client);

  Future<SendMediaResponse> sendFile({
    required String peerPubkey,
    required String filePath,
    required String mimeType,
  }) async {
    final file = File(filePath);
    var fileBytes = await file.readAsBytes();
    if (fileBytes.length > 10 * 1024 * 1024) {
      throw Exception('File too large (max 10MB)');
    }

    // Pad to just above 60KB so the daemon always uses TCP transport.
    // Trailing zeros are harmless for JPEG/M4A/MP4; for other types the
    // extra bytes are a small price for reliable delivery.
    if (fileBytes.length < _tcpThreshold) {
      final padded = List<int>.of(fileBytes, growable: true);
      padded.length = _tcpThreshold + 1;
      fileBytes = Uint8List.fromList(padded);
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
          preferredTransport: SendMediaRequest_Transport.AUTO,
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
    // All files use TCP after padding. TCP: ~1MB/s, generous 60s buffer.
    return (fileSize ~/ (1024 * 1024)) + 60;
  }
}
