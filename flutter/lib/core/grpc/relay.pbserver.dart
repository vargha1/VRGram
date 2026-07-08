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

import 'package:protobuf/protobuf.dart' as $pb;

import 'relay.pb.dart' as $0;
import 'relay.pbjson.dart';

export 'relay.pb.dart';

abstract class RelayClientServiceBase extends $pb.GeneratedService {
  $async.Future<$0.SendResponse> sendMessage(
      $pb.ServerContext ctx, $0.SendRequest request);
  $async.Future<$0.PollResponse> pollMessages(
      $pb.ServerContext ctx, $0.PollRequest request);
  $async.Future<$0.RelayStatusList> getRelayStatus(
      $pb.ServerContext ctx, $0.Empty request);
  $async.Future<$0.Empty> addRelay(
      $pb.ServerContext ctx, $0.RelayEndpoint request);
  $async.Future<$0.Empty> removeRelay(
      $pb.ServerContext ctx, $0.RelayEndpoint request);
  $async.Future<$0.IdentityInfo> getIdentity(
      $pb.ServerContext ctx, $0.Empty request);
  $async.Future<$0.Empty> addPeer($pb.ServerContext ctx, $0.PeerInfo request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'SendMessage':
        return $0.SendRequest();
      case 'PollMessages':
        return $0.PollRequest();
      case 'GetRelayStatus':
        return $0.Empty();
      case 'AddRelay':
        return $0.RelayEndpoint();
      case 'RemoveRelay':
        return $0.RelayEndpoint();
      case 'GetIdentity':
        return $0.Empty();
      case 'AddPeer':
        return $0.PeerInfo();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'SendMessage':
        return sendMessage(ctx, request as $0.SendRequest);
      case 'PollMessages':
        return pollMessages(ctx, request as $0.PollRequest);
      case 'GetRelayStatus':
        return getRelayStatus(ctx, request as $0.Empty);
      case 'AddRelay':
        return addRelay(ctx, request as $0.RelayEndpoint);
      case 'RemoveRelay':
        return removeRelay(ctx, request as $0.RelayEndpoint);
      case 'GetIdentity':
        return getIdentity(ctx, request as $0.Empty);
      case 'AddPeer':
        return addPeer(ctx, request as $0.PeerInfo);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json =>
      RelayClientServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => RelayClientServiceBase$messageJson;
}
