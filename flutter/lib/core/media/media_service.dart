import 'dart:io';
import 'package:grpc/grpc.dart';
import '../grpc/client.dart';
import '../grpc/relay.pb.dart';

class MediaService {
  final GrpcClient _client;

  /// Max file size for media transport (10 MB, matches daemon's MediaMaxHardCap)
  static const int maxMediaFileSize = 10 * 1024 * 1024;

  /// Media uploads go through DNS transport which is slow (many round-trips).
  /// Use a long gRPC timeout so they don't get killed at 30s.
  static const Duration _mediaTimeout = Duration(seconds: 300);

  MediaService(this._client);

  Future<SendMediaResponse> sendFile({
    required String peerPubkey,
    required String filePath,
    required String mimeType,
    SendMediaRequest_Transport transport = SendMediaRequest_Transport.AUTO,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final filename = filePath.split('/').last.split('\\').last;

    // Check file size before sending
    if (bytes.length > maxMediaFileSize) {
      throw Exception('File too large (max ${maxMediaFileSize ~/ 1048576} MB)');
    }

    final request = SendMediaRequest(
      peerPubkey: peerPubkey,
      mediaData: bytes,
      filename: filename,
      mimeType: mimeType,
      preferredTransport: transport,
    );

    return _client.stub.sendMedia(request,
        options: CallOptions(timeout: _mediaTimeout));
  }
}
