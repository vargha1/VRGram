// This is a generated file - do not edit.
//
// Generated from relay.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'relay.pb.dart' as $0;

export 'relay.pb.dart';

@$pb.GrpcServiceName('relaypb.RelayClient')
class RelayClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  RelayClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.SendResponse> sendMessage(
    $0.SendRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$sendMessage, request, options: options);
  }

  $grpc.ResponseFuture<$0.PollResponse> pollMessages(
    $0.PollRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$pollMessages, request, options: options);
  }

  $grpc.ResponseFuture<$0.RelayStatusList> getRelayStatus(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getRelayStatus, request, options: options);
  }

  $grpc.ResponseFuture<$0.Empty> addRelay(
    $0.RelayEndpoint request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$addRelay, request, options: options);
  }

  $grpc.ResponseFuture<$0.Empty> removeRelay(
    $0.RelayEndpoint request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$removeRelay, request, options: options);
  }

  $grpc.ResponseFuture<$0.IdentityInfo> getIdentity(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getIdentity, request, options: options);
  }

  $grpc.ResponseFuture<$0.Empty> addPeer(
    $0.PeerInfo request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$addPeer, request, options: options);
  }

  $grpc.ResponseFuture<$0.TransportStatusResponse> getTransportStatus(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getTransportStatus, request, options: options);
  }

  /// New media RPCs
  $grpc.ResponseFuture<$0.SendMediaResponse> sendMedia(
    $0.SendMediaRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$sendMedia, request, options: options);
  }

  $grpc.ResponseFuture<$0.MediaStatusResponse> getMediaStatus(
    $0.GetMediaStatusRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getMediaStatus, request, options: options);
  }

  $grpc.ResponseFuture<$0.Empty> cancelSend(
    $0.CancelSendRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$cancelSend, request, options: options);
  }

  $grpc.ResponseFuture<$0.SendMediaResponse> sendMediaStream(
    $async.Stream<$0.MediaUploadChunk> request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$sendMediaStream, request, options: options)
        .single;
  }

  $grpc.ResponseFuture<$0.GenerateInviteCodeResponse> generateInviteCode(
    $0.GenerateInviteCodeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$generateInviteCode, request, options: options);
  }

  $grpc.ResponseFuture<$0.JoinViaCodeResponse> joinViaCode(
    $0.JoinViaCodeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$joinViaCode, request, options: options);
  }

  $grpc.ResponseFuture<$0.Empty> removePeer(
    $0.PeerInfo request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$removePeer, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListPeersResponse> listPeers(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listPeers, request, options: options);
  }

  $grpc.ResponseFuture<$0.CreateGroupResponse> createGroup(
    $0.CreateGroupRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createGroup, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListGroupsResponse> listGroups(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listGroups, request, options: options);
  }

  $grpc.ResponseFuture<$0.Empty> leaveGroup(
    $0.LeaveGroupRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$leaveGroup, request, options: options);
  }

  $grpc.ResponseFuture<$0.Empty> removeGroupMember(
    $0.RemoveGroupMemberRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$removeGroupMember, request, options: options);
  }

  // method descriptors

  static final _$sendMessage =
      $grpc.ClientMethod<$0.SendRequest, $0.SendResponse>(
          '/relaypb.RelayClient/SendMessage',
          ($0.SendRequest value) => value.writeToBuffer(),
          $0.SendResponse.fromBuffer);
  static final _$pollMessages =
      $grpc.ClientMethod<$0.PollRequest, $0.PollResponse>(
          '/relaypb.RelayClient/PollMessages',
          ($0.PollRequest value) => value.writeToBuffer(),
          $0.PollResponse.fromBuffer);
  static final _$getRelayStatus =
      $grpc.ClientMethod<$0.Empty, $0.RelayStatusList>(
          '/relaypb.RelayClient/GetRelayStatus',
          ($0.Empty value) => value.writeToBuffer(),
          $0.RelayStatusList.fromBuffer);
  static final _$addRelay = $grpc.ClientMethod<$0.RelayEndpoint, $0.Empty>(
      '/relaypb.RelayClient/AddRelay',
      ($0.RelayEndpoint value) => value.writeToBuffer(),
      $0.Empty.fromBuffer);
  static final _$removeRelay = $grpc.ClientMethod<$0.RelayEndpoint, $0.Empty>(
      '/relaypb.RelayClient/RemoveRelay',
      ($0.RelayEndpoint value) => value.writeToBuffer(),
      $0.Empty.fromBuffer);
  static final _$getIdentity = $grpc.ClientMethod<$0.Empty, $0.IdentityInfo>(
      '/relaypb.RelayClient/GetIdentity',
      ($0.Empty value) => value.writeToBuffer(),
      $0.IdentityInfo.fromBuffer);
  static final _$addPeer = $grpc.ClientMethod<$0.PeerInfo, $0.Empty>(
      '/relaypb.RelayClient/AddPeer',
      ($0.PeerInfo value) => value.writeToBuffer(),
      $0.Empty.fromBuffer);
  static final _$getTransportStatus =
      $grpc.ClientMethod<$0.Empty, $0.TransportStatusResponse>(
          '/relaypb.RelayClient/GetTransportStatus',
          ($0.Empty value) => value.writeToBuffer(),
          $0.TransportStatusResponse.fromBuffer);
  static final _$sendMedia =
      $grpc.ClientMethod<$0.SendMediaRequest, $0.SendMediaResponse>(
          '/relaypb.RelayClient/SendMedia',
          ($0.SendMediaRequest value) => value.writeToBuffer(),
          $0.SendMediaResponse.fromBuffer);
  static final _$getMediaStatus =
      $grpc.ClientMethod<$0.GetMediaStatusRequest, $0.MediaStatusResponse>(
          '/relaypb.RelayClient/GetMediaStatus',
          ($0.GetMediaStatusRequest value) => value.writeToBuffer(),
          $0.MediaStatusResponse.fromBuffer);
  static final _$cancelSend =
      $grpc.ClientMethod<$0.CancelSendRequest, $0.Empty>(
          '/relaypb.RelayClient/CancelSend',
          ($0.CancelSendRequest value) => value.writeToBuffer(),
          $0.Empty.fromBuffer);
  static final _$sendMediaStream =
      $grpc.ClientMethod<$0.MediaUploadChunk, $0.SendMediaResponse>(
          '/relaypb.RelayClient/SendMediaStream',
          ($0.MediaUploadChunk value) => value.writeToBuffer(),
          $0.SendMediaResponse.fromBuffer);
  static final _$generateInviteCode = $grpc.ClientMethod<
          $0.GenerateInviteCodeRequest, $0.GenerateInviteCodeResponse>(
      '/relaypb.RelayClient/GenerateInviteCode',
      ($0.GenerateInviteCodeRequest value) => value.writeToBuffer(),
      $0.GenerateInviteCodeResponse.fromBuffer);
  static final _$joinViaCode =
      $grpc.ClientMethod<$0.JoinViaCodeRequest, $0.JoinViaCodeResponse>(
          '/relaypb.RelayClient/JoinViaCode',
          ($0.JoinViaCodeRequest value) => value.writeToBuffer(),
          $0.JoinViaCodeResponse.fromBuffer);
  static final _$removePeer = $grpc.ClientMethod<$0.PeerInfo, $0.Empty>(
      '/relaypb.RelayClient/RemovePeer',
      ($0.PeerInfo value) => value.writeToBuffer(),
      $0.Empty.fromBuffer);
  static final _$listPeers = $grpc.ClientMethod<$0.Empty, $0.ListPeersResponse>(
      '/relaypb.RelayClient/ListPeers',
      ($0.Empty value) => value.writeToBuffer(),
      $0.ListPeersResponse.fromBuffer);
  static final _$createGroup =
      $grpc.ClientMethod<$0.CreateGroupRequest, $0.CreateGroupResponse>(
          '/relaypb.RelayClient/CreateGroup',
          ($0.CreateGroupRequest value) => value.writeToBuffer(),
          $0.CreateGroupResponse.fromBuffer);
  static final _$listGroups =
      $grpc.ClientMethod<$0.Empty, $0.ListGroupsResponse>(
          '/relaypb.RelayClient/ListGroups',
          ($0.Empty value) => value.writeToBuffer(),
          $0.ListGroupsResponse.fromBuffer);
  static final _$leaveGroup =
      $grpc.ClientMethod<$0.LeaveGroupRequest, $0.Empty>(
          '/relaypb.RelayClient/LeaveGroup',
          ($0.LeaveGroupRequest value) => value.writeToBuffer(),
          $0.Empty.fromBuffer);
  static final _$removeGroupMember =
      $grpc.ClientMethod<$0.RemoveGroupMemberRequest, $0.Empty>(
          '/relaypb.RelayClient/RemoveGroupMember',
          ($0.RemoveGroupMemberRequest value) => value.writeToBuffer(),
          $0.Empty.fromBuffer);
}

@$pb.GrpcServiceName('relaypb.RelayClient')
abstract class RelayClientServiceBase extends $grpc.Service {
  $core.String get $name => 'relaypb.RelayClient';

  RelayClientServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.SendRequest, $0.SendResponse>(
        'SendMessage',
        sendMessage_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SendRequest.fromBuffer(value),
        ($0.SendResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PollRequest, $0.PollResponse>(
        'PollMessages',
        pollMessages_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PollRequest.fromBuffer(value),
        ($0.PollResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.RelayStatusList>(
        'GetRelayStatus',
        getRelayStatus_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.RelayStatusList value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RelayEndpoint, $0.Empty>(
        'AddRelay',
        addRelay_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.RelayEndpoint.fromBuffer(value),
        ($0.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RelayEndpoint, $0.Empty>(
        'RemoveRelay',
        removeRelay_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.RelayEndpoint.fromBuffer(value),
        ($0.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.IdentityInfo>(
        'GetIdentity',
        getIdentity_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.IdentityInfo value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PeerInfo, $0.Empty>(
        'AddPeer',
        addPeer_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PeerInfo.fromBuffer(value),
        ($0.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.TransportStatusResponse>(
        'GetTransportStatus',
        getTransportStatus_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.TransportStatusResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SendMediaRequest, $0.SendMediaResponse>(
        'SendMedia',
        sendMedia_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SendMediaRequest.fromBuffer(value),
        ($0.SendMediaResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.GetMediaStatusRequest, $0.MediaStatusResponse>(
            'GetMediaStatus',
            getMediaStatus_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GetMediaStatusRequest.fromBuffer(value),
            ($0.MediaStatusResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CancelSendRequest, $0.Empty>(
        'CancelSend',
        cancelSend_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CancelSendRequest.fromBuffer(value),
        ($0.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.MediaUploadChunk, $0.SendMediaResponse>(
        'SendMediaStream',
        sendMediaStream,
        true,
        false,
        ($core.List<$core.int> value) => $0.MediaUploadChunk.fromBuffer(value),
        ($0.SendMediaResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GenerateInviteCodeRequest,
            $0.GenerateInviteCodeResponse>(
        'GenerateInviteCode',
        generateInviteCode_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GenerateInviteCodeRequest.fromBuffer(value),
        ($0.GenerateInviteCodeResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.JoinViaCodeRequest, $0.JoinViaCodeResponse>(
            'JoinViaCode',
            joinViaCode_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.JoinViaCodeRequest.fromBuffer(value),
            ($0.JoinViaCodeResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PeerInfo, $0.Empty>(
        'RemovePeer',
        removePeer_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PeerInfo.fromBuffer(value),
        ($0.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.ListPeersResponse>(
        'ListPeers',
        listPeers_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.ListPeersResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.CreateGroupRequest, $0.CreateGroupResponse>(
            'CreateGroup',
            createGroup_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.CreateGroupRequest.fromBuffer(value),
            ($0.CreateGroupResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.ListGroupsResponse>(
        'ListGroups',
        listGroups_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.ListGroupsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.LeaveGroupRequest, $0.Empty>(
        'LeaveGroup',
        leaveGroup_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.LeaveGroupRequest.fromBuffer(value),
        ($0.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RemoveGroupMemberRequest, $0.Empty>(
        'RemoveGroupMember',
        removeGroupMember_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RemoveGroupMemberRequest.fromBuffer(value),
        ($0.Empty value) => value.writeToBuffer()));
  }

  $async.Future<$0.SendResponse> sendMessage_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.SendRequest> $request) async {
    return sendMessage($call, await $request);
  }

  $async.Future<$0.SendResponse> sendMessage(
      $grpc.ServiceCall call, $0.SendRequest request);

  $async.Future<$0.PollResponse> pollMessages_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.PollRequest> $request) async {
    return pollMessages($call, await $request);
  }

  $async.Future<$0.PollResponse> pollMessages(
      $grpc.ServiceCall call, $0.PollRequest request);

  $async.Future<$0.RelayStatusList> getRelayStatus_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return getRelayStatus($call, await $request);
  }

  $async.Future<$0.RelayStatusList> getRelayStatus(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.Empty> addRelay_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.RelayEndpoint> $request) async {
    return addRelay($call, await $request);
  }

  $async.Future<$0.Empty> addRelay(
      $grpc.ServiceCall call, $0.RelayEndpoint request);

  $async.Future<$0.Empty> removeRelay_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.RelayEndpoint> $request) async {
    return removeRelay($call, await $request);
  }

  $async.Future<$0.Empty> removeRelay(
      $grpc.ServiceCall call, $0.RelayEndpoint request);

  $async.Future<$0.IdentityInfo> getIdentity_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return getIdentity($call, await $request);
  }

  $async.Future<$0.IdentityInfo> getIdentity(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.Empty> addPeer_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.PeerInfo> $request) async {
    return addPeer($call, await $request);
  }

  $async.Future<$0.Empty> addPeer($grpc.ServiceCall call, $0.PeerInfo request);

  $async.Future<$0.TransportStatusResponse> getTransportStatus_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return getTransportStatus($call, await $request);
  }

  $async.Future<$0.TransportStatusResponse> getTransportStatus(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.SendMediaResponse> sendMedia_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SendMediaRequest> $request) async {
    return sendMedia($call, await $request);
  }

  $async.Future<$0.SendMediaResponse> sendMedia(
      $grpc.ServiceCall call, $0.SendMediaRequest request);

  $async.Future<$0.MediaStatusResponse> getMediaStatus_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetMediaStatusRequest> $request) async {
    return getMediaStatus($call, await $request);
  }

  $async.Future<$0.MediaStatusResponse> getMediaStatus(
      $grpc.ServiceCall call, $0.GetMediaStatusRequest request);

  $async.Future<$0.Empty> cancelSend_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CancelSendRequest> $request) async {
    return cancelSend($call, await $request);
  }

  $async.Future<$0.Empty> cancelSend(
      $grpc.ServiceCall call, $0.CancelSendRequest request);

  $async.Future<$0.SendMediaResponse> sendMediaStream(
      $grpc.ServiceCall call, $async.Stream<$0.MediaUploadChunk> request);

  $async.Future<$0.GenerateInviteCodeResponse> generateInviteCode_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GenerateInviteCodeRequest> $request) async {
    return generateInviteCode($call, await $request);
  }

  $async.Future<$0.GenerateInviteCodeResponse> generateInviteCode(
      $grpc.ServiceCall call, $0.GenerateInviteCodeRequest request);

  $async.Future<$0.JoinViaCodeResponse> joinViaCode_Pre($grpc.ServiceCall $call,
      $async.Future<$0.JoinViaCodeRequest> $request) async {
    return joinViaCode($call, await $request);
  }

  $async.Future<$0.JoinViaCodeResponse> joinViaCode(
      $grpc.ServiceCall call, $0.JoinViaCodeRequest request);

  $async.Future<$0.Empty> removePeer_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.PeerInfo> $request) async {
    return removePeer($call, await $request);
  }

  $async.Future<$0.Empty> removePeer(
      $grpc.ServiceCall call, $0.PeerInfo request);

  $async.Future<$0.ListPeersResponse> listPeers_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return listPeers($call, await $request);
  }

  $async.Future<$0.ListPeersResponse> listPeers(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.CreateGroupResponse> createGroup_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateGroupRequest> $request) async {
    return createGroup($call, await $request);
  }

  $async.Future<$0.CreateGroupResponse> createGroup(
      $grpc.ServiceCall call, $0.CreateGroupRequest request);

  $async.Future<$0.ListGroupsResponse> listGroups_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return listGroups($call, await $request);
  }

  $async.Future<$0.ListGroupsResponse> listGroups(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.Empty> leaveGroup_Pre($grpc.ServiceCall $call,
      $async.Future<$0.LeaveGroupRequest> $request) async {
    return leaveGroup($call, await $request);
  }

  $async.Future<$0.Empty> leaveGroup(
      $grpc.ServiceCall call, $0.LeaveGroupRequest request);

  $async.Future<$0.Empty> removeGroupMember_Pre($grpc.ServiceCall $call,
      $async.Future<$0.RemoveGroupMemberRequest> $request) async {
    return removeGroupMember($call, await $request);
  }

  $async.Future<$0.Empty> removeGroupMember(
      $grpc.ServiceCall call, $0.RemoveGroupMemberRequest request);
}
