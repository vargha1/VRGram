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
}
