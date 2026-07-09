import 'dart:io';
import '../grpc/client.dart';
import '../grpc/relay.pb.dart';

class MediaService {
  final GrpcClient _client;

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
