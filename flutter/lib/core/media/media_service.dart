import 'dart:io';
import '../grpc/client.dart';
import '../grpc/relay.pb.dart';

class MediaService {
  final GrpcClient _client;

  /// Max file size for gRPC transport (4MB)
  static const int maxGrpcFileSize = 4 * 1024 * 1024;

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

    // I1: Check file size before sending
    if (bytes.length > maxGrpcFileSize) {
      throw Exception('File too large for current transport');
    }

    final request = SendMediaRequest(
      peerPubkey: peerPubkey,
      mediaData: bytes,
      filename: filename,
      mimeType: mimeType,
      preferredTransport: transport,
    );

    return _client.stub.sendMedia(request);
  }
}
