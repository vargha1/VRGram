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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class SendRequest extends $pb.GeneratedMessage {
  factory SendRequest({
    $core.String? peerPubkey,
    $core.List<$core.int>? plaintext,
  }) {
    final result = create();
    if (peerPubkey != null) result.peerPubkey = peerPubkey;
    if (plaintext != null) result.plaintext = plaintext;
    return result;
  }

  SendRequest._();

  factory SendRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SendRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerPubkey')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'plaintext', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendRequest copyWith(void Function(SendRequest) updates) =>
      super.copyWith((message) => updates(message as SendRequest))
          as SendRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendRequest create() => SendRequest._();
  @$core.override
  SendRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SendRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendRequest>(create);
  static SendRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerPubkey => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerPubkey($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerPubkey() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerPubkey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get plaintext => $_getN(1);
  @$pb.TagNumber(2)
  set plaintext($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPlaintext() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlaintext() => $_clearField(2);
}

class SendResponse extends $pb.GeneratedMessage {
  factory SendResponse({
    $core.String? messageId,
    $core.bool? queued,
    $core.int? chunkCount,
  }) {
    final result = create();
    if (messageId != null) result.messageId = messageId;
    if (queued != null) result.queued = queued;
    if (chunkCount != null) result.chunkCount = chunkCount;
    return result;
  }

  SendResponse._();

  factory SendResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SendResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..aOB(2, _omitFieldNames ? '' : 'queued')
    ..aI(3, _omitFieldNames ? '' : 'chunkCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendResponse copyWith(void Function(SendResponse) updates) =>
      super.copyWith((message) => updates(message as SendResponse))
          as SendResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendResponse create() => SendResponse._();
  @$core.override
  SendResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SendResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendResponse>(create);
  static SendResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get queued => $_getBF(1);
  @$pb.TagNumber(2)
  set queued($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasQueued() => $_has(1);
  @$pb.TagNumber(2)
  void clearQueued() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get chunkCount => $_getIZ(2);
  @$pb.TagNumber(3)
  set chunkCount($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasChunkCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearChunkCount() => $_clearField(3);
}

class PollRequest extends $pb.GeneratedMessage {
  factory PollRequest() => create();

  PollRequest._();

  factory PollRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PollRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PollRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PollRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PollRequest copyWith(void Function(PollRequest) updates) =>
      super.copyWith((message) => updates(message as PollRequest))
          as PollRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PollRequest create() => PollRequest._();
  @$core.override
  PollRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PollRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PollRequest>(create);
  static PollRequest? _defaultInstance;
}

class PollResponse extends $pb.GeneratedMessage {
  factory PollResponse({
    $core.Iterable<ReceivedMessage>? messages,
  }) {
    final result = create();
    if (messages != null) result.messages.addAll(messages);
    return result;
  }

  PollResponse._();

  factory PollResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PollResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PollResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..pPM<ReceivedMessage>(1, _omitFieldNames ? '' : 'messages',
        subBuilder: ReceivedMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PollResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PollResponse copyWith(void Function(PollResponse) updates) =>
      super.copyWith((message) => updates(message as PollResponse))
          as PollResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PollResponse create() => PollResponse._();
  @$core.override
  PollResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PollResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PollResponse>(create);
  static PollResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ReceivedMessage> get messages => $_getList(0);
}

class ReceivedMessage extends $pb.GeneratedMessage {
  factory ReceivedMessage({
    $core.String? fromPeer,
    $core.String? messageId,
    $core.List<$core.int>? plaintext,
    $fixnum.Int64? timestamp,
  }) {
    final result = create();
    if (fromPeer != null) result.fromPeer = fromPeer;
    if (messageId != null) result.messageId = messageId;
    if (plaintext != null) result.plaintext = plaintext;
    if (timestamp != null) result.timestamp = timestamp;
    return result;
  }

  ReceivedMessage._();

  factory ReceivedMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReceivedMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReceivedMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'fromPeer')
    ..aOS(2, _omitFieldNames ? '' : 'messageId')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'plaintext', $pb.PbFieldType.OY)
    ..aInt64(4, _omitFieldNames ? '' : 'timestamp')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReceivedMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReceivedMessage copyWith(void Function(ReceivedMessage) updates) =>
      super.copyWith((message) => updates(message as ReceivedMessage))
          as ReceivedMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReceivedMessage create() => ReceivedMessage._();
  @$core.override
  ReceivedMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReceivedMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReceivedMessage>(create);
  static ReceivedMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get fromPeer => $_getSZ(0);
  @$pb.TagNumber(1)
  set fromPeer($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFromPeer() => $_has(0);
  @$pb.TagNumber(1)
  void clearFromPeer() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get messageId => $_getSZ(1);
  @$pb.TagNumber(2)
  set messageId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessageId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get plaintext => $_getN(2);
  @$pb.TagNumber(3)
  set plaintext($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPlaintext() => $_has(2);
  @$pb.TagNumber(3)
  void clearPlaintext() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get timestamp => $_getI64(3);
  @$pb.TagNumber(4)
  set timestamp($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTimestamp() => $_has(3);
  @$pb.TagNumber(4)
  void clearTimestamp() => $_clearField(4);
}

class Empty extends $pb.GeneratedMessage {
  factory Empty() => create();

  Empty._();

  factory Empty.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Empty.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Empty',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Empty clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Empty copyWith(void Function(Empty) updates) =>
      super.copyWith((message) => updates(message as Empty)) as Empty;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Empty create() => Empty._();
  @$core.override
  Empty createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Empty getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Empty>(create);
  static Empty? _defaultInstance;
}

class RelayEndpoint extends $pb.GeneratedMessage {
  factory RelayEndpoint({
    $core.String? address,
  }) {
    final result = create();
    if (address != null) result.address = address;
    return result;
  }

  RelayEndpoint._();

  factory RelayEndpoint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RelayEndpoint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RelayEndpoint',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'address')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelayEndpoint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelayEndpoint copyWith(void Function(RelayEndpoint) updates) =>
      super.copyWith((message) => updates(message as RelayEndpoint))
          as RelayEndpoint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RelayEndpoint create() => RelayEndpoint._();
  @$core.override
  RelayEndpoint createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RelayEndpoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RelayEndpoint>(create);
  static RelayEndpoint? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get address => $_getSZ(0);
  @$pb.TagNumber(1)
  set address($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearAddress() => $_clearField(1);
}

class RelayStatusList extends $pb.GeneratedMessage {
  factory RelayStatusList({
    $core.Iterable<RelayStatus>? endpoints,
  }) {
    final result = create();
    if (endpoints != null) result.endpoints.addAll(endpoints);
    return result;
  }

  RelayStatusList._();

  factory RelayStatusList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RelayStatusList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RelayStatusList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..pPM<RelayStatus>(1, _omitFieldNames ? '' : 'endpoints',
        subBuilder: RelayStatus.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelayStatusList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelayStatusList copyWith(void Function(RelayStatusList) updates) =>
      super.copyWith((message) => updates(message as RelayStatusList))
          as RelayStatusList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RelayStatusList create() => RelayStatusList._();
  @$core.override
  RelayStatusList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RelayStatusList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RelayStatusList>(create);
  static RelayStatusList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<RelayStatus> get endpoints => $_getList(0);
}

class RelayStatus extends $pb.GeneratedMessage {
  factory RelayStatus({
    $core.String? address,
    $core.bool? reachable,
    $fixnum.Int64? latencyMs,
    $core.String? lastError,
    $core.bool? blackoutMode,
  }) {
    final result = create();
    if (address != null) result.address = address;
    if (reachable != null) result.reachable = reachable;
    if (latencyMs != null) result.latencyMs = latencyMs;
    if (lastError != null) result.lastError = lastError;
    if (blackoutMode != null) result.blackoutMode = blackoutMode;
    return result;
  }

  RelayStatus._();

  factory RelayStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RelayStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RelayStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'address')
    ..aOB(2, _omitFieldNames ? '' : 'reachable')
    ..aInt64(3, _omitFieldNames ? '' : 'latencyMs')
    ..aOS(4, _omitFieldNames ? '' : 'lastError')
    ..aOB(5, _omitFieldNames ? '' : 'blackoutMode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelayStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RelayStatus copyWith(void Function(RelayStatus) updates) =>
      super.copyWith((message) => updates(message as RelayStatus))
          as RelayStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RelayStatus create() => RelayStatus._();
  @$core.override
  RelayStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RelayStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RelayStatus>(create);
  static RelayStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get address => $_getSZ(0);
  @$pb.TagNumber(1)
  set address($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearAddress() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get reachable => $_getBF(1);
  @$pb.TagNumber(2)
  set reachable($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReachable() => $_has(1);
  @$pb.TagNumber(2)
  void clearReachable() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get latencyMs => $_getI64(2);
  @$pb.TagNumber(3)
  set latencyMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLatencyMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearLatencyMs() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get lastError => $_getSZ(3);
  @$pb.TagNumber(4)
  set lastError($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLastError() => $_has(3);
  @$pb.TagNumber(4)
  void clearLastError() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get blackoutMode => $_getBF(4);
  @$pb.TagNumber(5)
  set blackoutMode($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBlackoutMode() => $_has(4);
  @$pb.TagNumber(5)
  void clearBlackoutMode() => $_clearField(5);
}

class IdentityInfo extends $pb.GeneratedMessage {
  factory IdentityInfo({
    $core.String? pubkey,
  }) {
    final result = create();
    if (pubkey != null) result.pubkey = pubkey;
    return result;
  }

  IdentityInfo._();

  factory IdentityInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IdentityInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IdentityInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'pubkey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IdentityInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IdentityInfo copyWith(void Function(IdentityInfo) updates) =>
      super.copyWith((message) => updates(message as IdentityInfo))
          as IdentityInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IdentityInfo create() => IdentityInfo._();
  @$core.override
  IdentityInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IdentityInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<IdentityInfo>(create);
  static IdentityInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pubkey => $_getSZ(0);
  @$pb.TagNumber(1)
  set pubkey($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPubkey() => $_has(0);
  @$pb.TagNumber(1)
  void clearPubkey() => $_clearField(1);
}

class PeerInfo extends $pb.GeneratedMessage {
  factory PeerInfo({
    $core.String? nickname,
    $core.String? pubkey,
  }) {
    final result = create();
    if (nickname != null) result.nickname = nickname;
    if (pubkey != null) result.pubkey = pubkey;
    return result;
  }

  PeerInfo._();

  factory PeerInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PeerInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PeerInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'nickname')
    ..aOS(2, _omitFieldNames ? '' : 'pubkey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerInfo copyWith(void Function(PeerInfo) updates) =>
      super.copyWith((message) => updates(message as PeerInfo)) as PeerInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PeerInfo create() => PeerInfo._();
  @$core.override
  PeerInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PeerInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PeerInfo>(create);
  static PeerInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get nickname => $_getSZ(0);
  @$pb.TagNumber(1)
  set nickname($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNickname() => $_has(0);
  @$pb.TagNumber(1)
  void clearNickname() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get pubkey => $_getSZ(1);
  @$pb.TagNumber(2)
  set pubkey($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPubkey() => $_has(1);
  @$pb.TagNumber(2)
  void clearPubkey() => $_clearField(2);
}

class TransportStatusResponse extends $pb.GeneratedMessage {
  factory TransportStatusResponse({
    $core.bool? dhtConnected,
    $core.int? discoveredRelays,
    $core.bool? libp2pDirect,
    $core.bool? libp2pCircuit,
    $core.String? dnsMode,
  }) {
    final result = create();
    if (dhtConnected != null) result.dhtConnected = dhtConnected;
    if (discoveredRelays != null) result.discoveredRelays = discoveredRelays;
    if (libp2pDirect != null) result.libp2pDirect = libp2pDirect;
    if (libp2pCircuit != null) result.libp2pCircuit = libp2pCircuit;
    if (dnsMode != null) result.dnsMode = dnsMode;
    return result;
  }

  TransportStatusResponse._();

  factory TransportStatusResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TransportStatusResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransportStatusResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'dhtConnected')
    ..aI(2, _omitFieldNames ? '' : 'discoveredRelays')
    ..aOB(3, _omitFieldNames ? '' : 'libp2pDirect')
    ..aOB(4, _omitFieldNames ? '' : 'libp2pCircuit')
    ..aOS(5, _omitFieldNames ? '' : 'dnsMode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransportStatusResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransportStatusResponse copyWith(void Function(TransportStatusResponse) updates) =>
      super.copyWith((message) => updates(message as TransportStatusResponse))
          as TransportStatusResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TransportStatusResponse create() => TransportStatusResponse._();
  @$core.override
  TransportStatusResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TransportStatusResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransportStatusResponse>(create);
  static TransportStatusResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get dhtConnected => $_getBF(0);
  @$pb.TagNumber(1)
  set dhtConnected($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDhtConnected() => $_has(0);
  @$pb.TagNumber(1)
  void clearDhtConnected() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get discoveredRelays => $_getIZ(1);
  @$pb.TagNumber(2)
  set discoveredRelays($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDiscoveredRelays() => $_has(1);
  @$pb.TagNumber(2)
  void clearDiscoveredRelays() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get libp2pDirect => $_getBF(2);
  @$pb.TagNumber(3)
  set libp2pDirect($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLibp2pDirect() => $_has(2);
  @$pb.TagNumber(3)
  void clearLibp2pDirect() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get libp2pCircuit => $_getBF(3);
  @$pb.TagNumber(4)
  set libp2pCircuit($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLibp2pCircuit() => $_has(3);
  @$pb.TagNumber(4)
  void clearLibp2pCircuit() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get dnsMode => $_getSZ(4);
  @$pb.TagNumber(5)
  set dnsMode($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDnsMode() => $_has(4);
  @$pb.TagNumber(5)
  void clearDnsMode() => $_clearField(5);
}

class RelayClientApi {
  final $pb.RpcClient _client;

  RelayClientApi(this._client);

  $async.Future<SendResponse> sendMessage(
          $pb.ClientContext? ctx, SendRequest request) =>
      _client.invoke<SendResponse>(
          ctx, 'RelayClient', 'SendMessage', request, SendResponse());
  $async.Future<PollResponse> pollMessages(
          $pb.ClientContext? ctx, PollRequest request) =>
      _client.invoke<PollResponse>(
          ctx, 'RelayClient', 'PollMessages', request, PollResponse());
  $async.Future<RelayStatusList> getRelayStatus(
          $pb.ClientContext? ctx, Empty request) =>
      _client.invoke<RelayStatusList>(
          ctx, 'RelayClient', 'GetRelayStatus', request, RelayStatusList());
  $async.Future<Empty> addRelay(
          $pb.ClientContext? ctx, RelayEndpoint request) =>
      _client.invoke<Empty>(ctx, 'RelayClient', 'AddRelay', request, Empty());
  $async.Future<Empty> removeRelay(
          $pb.ClientContext? ctx, RelayEndpoint request) =>
      _client.invoke<Empty>(
          ctx, 'RelayClient', 'RemoveRelay', request, Empty());
  $async.Future<IdentityInfo> getIdentity(
          $pb.ClientContext? ctx, Empty request) =>
      _client.invoke<IdentityInfo>(
          ctx, 'RelayClient', 'GetIdentity', request, IdentityInfo());
  $async.Future<Empty> addPeer($pb.ClientContext? ctx, PeerInfo request) =>
      _client.invoke<Empty>(ctx, 'RelayClient', 'AddPeer', request, Empty());
  $async.Future<TransportStatusResponse> getTransportStatus(
          $pb.ClientContext? ctx, Empty request) =>
      _client.invoke<TransportStatusResponse>(
          ctx, 'RelayClient', 'GetTransportStatus', request, TransportStatusResponse());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
