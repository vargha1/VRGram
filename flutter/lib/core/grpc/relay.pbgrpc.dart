// Manually written gRPC client stub for RelayClient service (grpc 5.x API).
import 'package:grpc/grpc.dart';
import 'relay.pb.dart';

class RelayClientClient extends Client {
  static final _$sendMessage = ClientMethod<SendRequest, SendResponse>(
    '/relaypb.RelayClient/SendMessage',
    (SendRequest data) => data.writeToBuffer(),
    (List<int> data) => SendResponse.fromBuffer(data),
  );

  static final _$pollMessages = ClientMethod<PollRequest, PollResponse>(
    '/relaypb.RelayClient/PollMessages',
    (PollRequest data) => data.writeToBuffer(),
    (List<int> data) => PollResponse.fromBuffer(data),
  );

  static final _$getRelayStatus = ClientMethod<Empty, RelayStatusList>(
    '/relaypb.RelayClient/GetRelayStatus',
    (Empty data) => data.writeToBuffer(),
    (List<int> data) => RelayStatusList.fromBuffer(data),
  );

  static final _$addRelay = ClientMethod<RelayEndpoint, Empty>(
    '/relaypb.RelayClient/AddRelay',
    (RelayEndpoint data) => data.writeToBuffer(),
    (List<int> data) => Empty.fromBuffer(data),
  );

  static final _$removeRelay = ClientMethod<RelayEndpoint, Empty>(
    '/relaypb.RelayClient/RemoveRelay',
    (RelayEndpoint data) => data.writeToBuffer(),
    (List<int> data) => Empty.fromBuffer(data),
  );

  static final _$getIdentity = ClientMethod<Empty, IdentityInfo>(
    '/relaypb.RelayClient/GetIdentity',
    (Empty data) => data.writeToBuffer(),
    (List<int> data) => IdentityInfo.fromBuffer(data),
  );

  static final _$addPeer = ClientMethod<PeerInfo, Empty>(
    '/relaypb.RelayClient/AddPeer',
    (PeerInfo data) => data.writeToBuffer(),
    (List<int> data) => Empty.fromBuffer(data),
  );

  RelayClientClient(ClientChannel channel, {CallOptions? options})
      : super(channel, options: options);

  ResponseFuture<SendResponse> sendMessage(SendRequest request,
      {CallOptions? options}) {
    return $createUnaryCall(_$sendMessage, request, options: options);
  }

  ResponseFuture<PollResponse> pollMessages(PollRequest request,
      {CallOptions? options}) {
    return $createUnaryCall(_$pollMessages, request, options: options);
  }

  ResponseFuture<RelayStatusList> getRelayStatus(Empty request,
      {CallOptions? options}) {
    return $createUnaryCall(_$getRelayStatus, request, options: options);
  }

  ResponseFuture<Empty> addRelay(RelayEndpoint request,
      {CallOptions? options}) {
    return $createUnaryCall(_$addRelay, request, options: options);
  }

  ResponseFuture<Empty> removeRelay(RelayEndpoint request,
      {CallOptions? options}) {
    return $createUnaryCall(_$removeRelay, request, options: options);
  }

  ResponseFuture<IdentityInfo> getIdentity(Empty request,
      {CallOptions? options}) {
    return $createUnaryCall(_$getIdentity, request, options: options);
  }

  ResponseFuture<Empty> addPeer(PeerInfo request,
      {CallOptions? options}) {
    return $createUnaryCall(_$addPeer, request, options: options);
  }
}
