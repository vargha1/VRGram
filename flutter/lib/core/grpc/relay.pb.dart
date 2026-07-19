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

import 'relay.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'relay.pbenum.dart';

class SendMediaRequest extends $pb.GeneratedMessage {
  factory SendMediaRequest({
    $core.String? peerPubkey,
    $core.List<$core.int>? mediaData,
    $core.String? filename,
    $core.String? mimeType,
  }) {
    final result = create();
    if (peerPubkey != null) result.peerPubkey = peerPubkey;
    if (mediaData != null) result.mediaData = mediaData;
    if (filename != null) result.filename = filename;
    if (mimeType != null) result.mimeType = mimeType;
    return result;
  }

  SendMediaRequest._();

  factory SendMediaRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SendMediaRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendMediaRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerPubkey')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'mediaData', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'filename')
    ..aOS(4, _omitFieldNames ? '' : 'mimeType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendMediaRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendMediaRequest copyWith(void Function(SendMediaRequest) updates) =>
      super.copyWith((message) => updates(message as SendMediaRequest))
          as SendMediaRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendMediaRequest create() => SendMediaRequest._();
  @$core.override
  SendMediaRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SendMediaRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendMediaRequest>(create);
  static SendMediaRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerPubkey => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerPubkey($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerPubkey() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerPubkey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get mediaData => $_getN(1);
  @$pb.TagNumber(2)
  set mediaData($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMediaData() => $_has(1);
  @$pb.TagNumber(2)
  void clearMediaData() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get filename => $_getSZ(2);
  @$pb.TagNumber(3)
  set filename($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFilename() => $_has(2);
  @$pb.TagNumber(3)
  void clearFilename() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get mimeType => $_getSZ(3);
  @$pb.TagNumber(4)
  set mimeType($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMimeType() => $_has(3);
  @$pb.TagNumber(4)
  void clearMimeType() => $_clearField(4);
}

class SendMediaResponse extends $pb.GeneratedMessage {
  factory SendMediaResponse({
    $core.String? messageId,
    $core.int? estimatedSeconds,
    $core.String? transport,
  }) {
    final result = create();
    if (messageId != null) result.messageId = messageId;
    if (estimatedSeconds != null) result.estimatedSeconds = estimatedSeconds;
    if (transport != null) result.transport = transport;
    return result;
  }

  SendMediaResponse._();

  factory SendMediaResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SendMediaResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendMediaResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..aI(2, _omitFieldNames ? '' : 'estimatedSeconds')
    ..aOS(3, _omitFieldNames ? '' : 'transport')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendMediaResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendMediaResponse copyWith(void Function(SendMediaResponse) updates) =>
      super.copyWith((message) => updates(message as SendMediaResponse))
          as SendMediaResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendMediaResponse create() => SendMediaResponse._();
  @$core.override
  SendMediaResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SendMediaResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendMediaResponse>(create);
  static SendMediaResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get estimatedSeconds => $_getIZ(1);
  @$pb.TagNumber(2)
  set estimatedSeconds($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEstimatedSeconds() => $_has(1);
  @$pb.TagNumber(2)
  void clearEstimatedSeconds() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get transport => $_getSZ(2);
  @$pb.TagNumber(3)
  set transport($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTransport() => $_has(2);
  @$pb.TagNumber(3)
  void clearTransport() => $_clearField(3);
}

class GetMediaStatusRequest extends $pb.GeneratedMessage {
  factory GetMediaStatusRequest({
    $core.String? messageId,
  }) {
    final result = create();
    if (messageId != null) result.messageId = messageId;
    return result;
  }

  GetMediaStatusRequest._();

  factory GetMediaStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetMediaStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetMediaStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMediaStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMediaStatusRequest copyWith(
          void Function(GetMediaStatusRequest) updates) =>
      super.copyWith((message) => updates(message as GetMediaStatusRequest))
          as GetMediaStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetMediaStatusRequest create() => GetMediaStatusRequest._();
  @$core.override
  GetMediaStatusRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetMediaStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetMediaStatusRequest>(create);
  static GetMediaStatusRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => $_clearField(1);
}

class MediaStatusResponse extends $pb.GeneratedMessage {
  factory MediaStatusResponse({
    $core.String? messageId,
    MediaStatusResponse_Status? status,
    $core.int? progressPct,
    $core.String? error,
  }) {
    final result = create();
    if (messageId != null) result.messageId = messageId;
    if (status != null) result.status = status;
    if (progressPct != null) result.progressPct = progressPct;
    if (error != null) result.error = error;
    return result;
  }

  MediaStatusResponse._();

  factory MediaStatusResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MediaStatusResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaStatusResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..aE<MediaStatusResponse_Status>(2, _omitFieldNames ? '' : 'status',
        enumValues: MediaStatusResponse_Status.values)
    ..aI(3, _omitFieldNames ? '' : 'progressPct')
    ..aOS(4, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaStatusResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaStatusResponse copyWith(void Function(MediaStatusResponse) updates) =>
      super.copyWith((message) => updates(message as MediaStatusResponse))
          as MediaStatusResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MediaStatusResponse create() => MediaStatusResponse._();
  @$core.override
  MediaStatusResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MediaStatusResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaStatusResponse>(create);
  static MediaStatusResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => $_clearField(1);

  @$pb.TagNumber(2)
  MediaStatusResponse_Status get status => $_getN(1);
  @$pb.TagNumber(2)
  set status(MediaStatusResponse_Status value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get progressPct => $_getIZ(2);
  @$pb.TagNumber(3)
  set progressPct($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProgressPct() => $_has(2);
  @$pb.TagNumber(3)
  void clearProgressPct() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get error => $_getSZ(3);
  @$pb.TagNumber(4)
  set error($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasError() => $_has(3);
  @$pb.TagNumber(4)
  void clearError() => $_clearField(4);
}

class CancelSendRequest extends $pb.GeneratedMessage {
  factory CancelSendRequest({
    $core.String? messageId,
  }) {
    final result = create();
    if (messageId != null) result.messageId = messageId;
    return result;
  }

  CancelSendRequest._();

  factory CancelSendRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CancelSendRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CancelSendRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CancelSendRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CancelSendRequest copyWith(void Function(CancelSendRequest) updates) =>
      super.copyWith((message) => updates(message as CancelSendRequest))
          as CancelSendRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CancelSendRequest create() => CancelSendRequest._();
  @$core.override
  CancelSendRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CancelSendRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CancelSendRequest>(create);
  static CancelSendRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => $_clearField(1);
}

class MediaUploadChunk extends $pb.GeneratedMessage {
  factory MediaUploadChunk({
    $core.String? transferId,
    $core.List<$core.int>? data,
    $core.int? chunkIndex,
  }) {
    final result = create();
    if (transferId != null) result.transferId = transferId;
    if (data != null) result.data = data;
    if (chunkIndex != null) result.chunkIndex = chunkIndex;
    return result;
  }

  MediaUploadChunk._();

  factory MediaUploadChunk.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MediaUploadChunk.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaUploadChunk',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'transferId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..aI(3, _omitFieldNames ? '' : 'chunkIndex', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaUploadChunk clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaUploadChunk copyWith(void Function(MediaUploadChunk) updates) =>
      super.copyWith((message) => updates(message as MediaUploadChunk))
          as MediaUploadChunk;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MediaUploadChunk create() => MediaUploadChunk._();
  @$core.override
  MediaUploadChunk createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MediaUploadChunk getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaUploadChunk>(create);
  static MediaUploadChunk? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transferId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transferId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransferId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransferId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get chunkIndex => $_getIZ(2);
  @$pb.TagNumber(3)
  set chunkIndex($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasChunkIndex() => $_has(2);
  @$pb.TagNumber(3)
  void clearChunkIndex() => $_clearField(3);
}

class SendRequest extends $pb.GeneratedMessage {
  factory SendRequest({
    $core.String? peerPubkey,
    $core.List<$core.int>? plaintext,
    $fixnum.Int64? clientTimestampMs,
    $core.String? groupId,
  }) {
    final result = create();
    if (peerPubkey != null) result.peerPubkey = peerPubkey;
    if (plaintext != null) result.plaintext = plaintext;
    if (clientTimestampMs != null) result.clientTimestampMs = clientTimestampMs;
    if (groupId != null) result.groupId = groupId;
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
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'clientTimestampMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(4, _omitFieldNames ? '' : 'groupId')
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

  @$pb.TagNumber(3)
  $fixnum.Int64 get clientTimestampMs => $_getI64(2);
  @$pb.TagNumber(3)
  set clientTimestampMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasClientTimestampMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearClientTimestampMs() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get groupId => $_getSZ(3);
  @$pb.TagNumber(4)
  set groupId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasGroupId() => $_has(3);
  @$pb.TagNumber(4)
  void clearGroupId() => $_clearField(4);
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
    $fixnum.Int64? serverTimestampMs,
    $fixnum.Int64? sequenceNumber,
    $core.String? groupId,
  }) {
    final result = create();
    if (fromPeer != null) result.fromPeer = fromPeer;
    if (messageId != null) result.messageId = messageId;
    if (plaintext != null) result.plaintext = plaintext;
    if (timestamp != null) result.timestamp = timestamp;
    if (serverTimestampMs != null) result.serverTimestampMs = serverTimestampMs;
    if (sequenceNumber != null) result.sequenceNumber = sequenceNumber;
    if (groupId != null) result.groupId = groupId;
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
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'serverTimestampMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        6, _omitFieldNames ? '' : 'sequenceNumber', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(7, _omitFieldNames ? '' : 'groupId')
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

  @$pb.TagNumber(5)
  $fixnum.Int64 get serverTimestampMs => $_getI64(4);
  @$pb.TagNumber(5)
  set serverTimestampMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasServerTimestampMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearServerTimestampMs() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get sequenceNumber => $_getI64(5);
  @$pb.TagNumber(6)
  set sequenceNumber($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSequenceNumber() => $_has(5);
  @$pb.TagNumber(6)
  void clearSequenceNumber() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get groupId => $_getSZ(6);
  @$pb.TagNumber(7)
  set groupId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasGroupId() => $_has(6);
  @$pb.TagNumber(7)
  void clearGroupId() => $_clearField(7);
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
    $core.String? nickname,
    $core.String? bio,
  }) {
    final result = create();
    if (pubkey != null) result.pubkey = pubkey;
    if (nickname != null) result.nickname = nickname;
    if (bio != null) result.bio = bio;
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
    ..aOS(2, _omitFieldNames ? '' : 'nickname')
    ..aOS(3, _omitFieldNames ? '' : 'bio')
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

  @$pb.TagNumber(2)
  $core.String get nickname => $_getSZ(1);
  @$pb.TagNumber(2)
  set nickname($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNickname() => $_has(1);
  @$pb.TagNumber(2)
  void clearNickname() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get bio => $_getSZ(2);
  @$pb.TagNumber(3)
  set bio($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBio() => $_has(2);
  @$pb.TagNumber(3)
  void clearBio() => $_clearField(3);
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

class GenerateInviteCodeRequest extends $pb.GeneratedMessage {
  factory GenerateInviteCodeRequest({
    $core.String? nickname,
  }) {
    final result = create();
    if (nickname != null) result.nickname = nickname;
    return result;
  }

  GenerateInviteCodeRequest._();

  factory GenerateInviteCodeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GenerateInviteCodeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateInviteCodeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'nickname')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateInviteCodeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateInviteCodeRequest copyWith(
          void Function(GenerateInviteCodeRequest) updates) =>
      super.copyWith((message) => updates(message as GenerateInviteCodeRequest))
          as GenerateInviteCodeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GenerateInviteCodeRequest create() => GenerateInviteCodeRequest._();
  @$core.override
  GenerateInviteCodeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GenerateInviteCodeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateInviteCodeRequest>(create);
  static GenerateInviteCodeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get nickname => $_getSZ(0);
  @$pb.TagNumber(1)
  set nickname($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNickname() => $_has(0);
  @$pb.TagNumber(1)
  void clearNickname() => $_clearField(1);
}

class GenerateInviteCodeResponse extends $pb.GeneratedMessage {
  factory GenerateInviteCodeResponse({
    $core.String? code,
  }) {
    final result = create();
    if (code != null) result.code = code;
    return result;
  }

  GenerateInviteCodeResponse._();

  factory GenerateInviteCodeResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GenerateInviteCodeResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateInviteCodeResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateInviteCodeResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateInviteCodeResponse copyWith(
          void Function(GenerateInviteCodeResponse) updates) =>
      super.copyWith(
              (message) => updates(message as GenerateInviteCodeResponse))
          as GenerateInviteCodeResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GenerateInviteCodeResponse create() => GenerateInviteCodeResponse._();
  @$core.override
  GenerateInviteCodeResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GenerateInviteCodeResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateInviteCodeResponse>(create);
  static GenerateInviteCodeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);
}

class JoinViaCodeRequest extends $pb.GeneratedMessage {
  factory JoinViaCodeRequest({
    $core.String? code,
  }) {
    final result = create();
    if (code != null) result.code = code;
    return result;
  }

  JoinViaCodeRequest._();

  factory JoinViaCodeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JoinViaCodeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JoinViaCodeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinViaCodeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinViaCodeRequest copyWith(void Function(JoinViaCodeRequest) updates) =>
      super.copyWith((message) => updates(message as JoinViaCodeRequest))
          as JoinViaCodeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinViaCodeRequest create() => JoinViaCodeRequest._();
  @$core.override
  JoinViaCodeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JoinViaCodeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JoinViaCodeRequest>(create);
  static JoinViaCodeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);
}

class JoinViaCodeResponse extends $pb.GeneratedMessage {
  factory JoinViaCodeResponse({
    $core.String? peerNickname,
    $core.String? peerPubkey,
  }) {
    final result = create();
    if (peerNickname != null) result.peerNickname = peerNickname;
    if (peerPubkey != null) result.peerPubkey = peerPubkey;
    return result;
  }

  JoinViaCodeResponse._();

  factory JoinViaCodeResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JoinViaCodeResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JoinViaCodeResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerNickname')
    ..aOS(2, _omitFieldNames ? '' : 'peerPubkey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinViaCodeResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinViaCodeResponse copyWith(void Function(JoinViaCodeResponse) updates) =>
      super.copyWith((message) => updates(message as JoinViaCodeResponse))
          as JoinViaCodeResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinViaCodeResponse create() => JoinViaCodeResponse._();
  @$core.override
  JoinViaCodeResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JoinViaCodeResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JoinViaCodeResponse>(create);
  static JoinViaCodeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerNickname => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerNickname($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerNickname() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerNickname() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get peerPubkey => $_getSZ(1);
  @$pb.TagNumber(2)
  set peerPubkey($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPeerPubkey() => $_has(1);
  @$pb.TagNumber(2)
  void clearPeerPubkey() => $_clearField(2);
}

class ListPeersResponse extends $pb.GeneratedMessage {
  factory ListPeersResponse({
    $core.Iterable<PeerInfo>? peers,
  }) {
    final result = create();
    if (peers != null) result.peers.addAll(peers);
    return result;
  }

  ListPeersResponse._();

  factory ListPeersResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListPeersResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListPeersResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..pPM<PeerInfo>(1, _omitFieldNames ? '' : 'peers',
        subBuilder: PeerInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPeersResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPeersResponse copyWith(void Function(ListPeersResponse) updates) =>
      super.copyWith((message) => updates(message as ListPeersResponse))
          as ListPeersResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListPeersResponse create() => ListPeersResponse._();
  @$core.override
  ListPeersResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListPeersResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListPeersResponse>(create);
  static ListPeersResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<PeerInfo> get peers => $_getList(0);
}

class CreateGroupRequest extends $pb.GeneratedMessage {
  factory CreateGroupRequest({
    $core.String? name,
    $core.Iterable<$core.String>? memberPubkeys,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (memberPubkeys != null) result.memberPubkeys.addAll(memberPubkeys);
    return result;
  }

  CreateGroupRequest._();

  factory CreateGroupRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateGroupRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateGroupRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..pPS(2, _omitFieldNames ? '' : 'memberPubkeys')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateGroupRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateGroupRequest copyWith(void Function(CreateGroupRequest) updates) =>
      super.copyWith((message) => updates(message as CreateGroupRequest))
          as CreateGroupRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateGroupRequest create() => CreateGroupRequest._();
  @$core.override
  CreateGroupRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateGroupRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateGroupRequest>(create);
  static CreateGroupRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get memberPubkeys => $_getList(1);
}

class CreateGroupResponse extends $pb.GeneratedMessage {
  factory CreateGroupResponse({
    $core.String? groupId,
  }) {
    final result = create();
    if (groupId != null) result.groupId = groupId;
    return result;
  }

  CreateGroupResponse._();

  factory CreateGroupResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateGroupResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateGroupResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'groupId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateGroupResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateGroupResponse copyWith(void Function(CreateGroupResponse) updates) =>
      super.copyWith((message) => updates(message as CreateGroupResponse))
          as CreateGroupResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateGroupResponse create() => CreateGroupResponse._();
  @$core.override
  CreateGroupResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateGroupResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateGroupResponse>(create);
  static CreateGroupResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get groupId => $_getSZ(0);
  @$pb.TagNumber(1)
  set groupId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGroupId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGroupId() => $_clearField(1);
}

class LeaveGroupRequest extends $pb.GeneratedMessage {
  factory LeaveGroupRequest({
    $core.String? groupId,
  }) {
    final result = create();
    if (groupId != null) result.groupId = groupId;
    return result;
  }

  LeaveGroupRequest._();

  factory LeaveGroupRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LeaveGroupRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LeaveGroupRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'groupId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaveGroupRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaveGroupRequest copyWith(void Function(LeaveGroupRequest) updates) =>
      super.copyWith((message) => updates(message as LeaveGroupRequest))
          as LeaveGroupRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LeaveGroupRequest create() => LeaveGroupRequest._();
  @$core.override
  LeaveGroupRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LeaveGroupRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LeaveGroupRequest>(create);
  static LeaveGroupRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get groupId => $_getSZ(0);
  @$pb.TagNumber(1)
  set groupId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGroupId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGroupId() => $_clearField(1);
}

class RemoveGroupMemberRequest extends $pb.GeneratedMessage {
  factory RemoveGroupMemberRequest({
    $core.String? groupId,
    $core.String? memberPubkey,
  }) {
    final result = create();
    if (groupId != null) result.groupId = groupId;
    if (memberPubkey != null) result.memberPubkey = memberPubkey;
    return result;
  }

  RemoveGroupMemberRequest._();

  factory RemoveGroupMemberRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RemoveGroupMemberRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveGroupMemberRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'groupId')
    ..aOS(2, _omitFieldNames ? '' : 'memberPubkey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveGroupMemberRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveGroupMemberRequest copyWith(
          void Function(RemoveGroupMemberRequest) updates) =>
      super.copyWith((message) => updates(message as RemoveGroupMemberRequest))
          as RemoveGroupMemberRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemoveGroupMemberRequest create() => RemoveGroupMemberRequest._();
  @$core.override
  RemoveGroupMemberRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RemoveGroupMemberRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveGroupMemberRequest>(create);
  static RemoveGroupMemberRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get groupId => $_getSZ(0);
  @$pb.TagNumber(1)
  set groupId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGroupId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGroupId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get memberPubkey => $_getSZ(1);
  @$pb.TagNumber(2)
  set memberPubkey($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMemberPubkey() => $_has(1);
  @$pb.TagNumber(2)
  void clearMemberPubkey() => $_clearField(2);
}

class ListGroupsResponse extends $pb.GeneratedMessage {
  factory ListGroupsResponse({
    $core.Iterable<GroupInfo>? groups,
  }) {
    final result = create();
    if (groups != null) result.groups.addAll(groups);
    return result;
  }

  ListGroupsResponse._();

  factory ListGroupsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListGroupsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListGroupsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..pPM<GroupInfo>(1, _omitFieldNames ? '' : 'groups',
        subBuilder: GroupInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGroupsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGroupsResponse copyWith(void Function(ListGroupsResponse) updates) =>
      super.copyWith((message) => updates(message as ListGroupsResponse))
          as ListGroupsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListGroupsResponse create() => ListGroupsResponse._();
  @$core.override
  ListGroupsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListGroupsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListGroupsResponse>(create);
  static ListGroupsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<GroupInfo> get groups => $_getList(0);
}

class GroupInfo extends $pb.GeneratedMessage {
  factory GroupInfo({
    $core.String? groupId,
    $core.String? name,
    $core.String? adminPubkey,
    $core.Iterable<GroupMember>? members,
    $fixnum.Int64? keyEpoch,
  }) {
    final result = create();
    if (groupId != null) result.groupId = groupId;
    if (name != null) result.name = name;
    if (adminPubkey != null) result.adminPubkey = adminPubkey;
    if (members != null) result.members.addAll(members);
    if (keyEpoch != null) result.keyEpoch = keyEpoch;
    return result;
  }

  GroupInfo._();

  factory GroupInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GroupInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GroupInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'groupId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'adminPubkey')
    ..pPM<GroupMember>(4, _omitFieldNames ? '' : 'members',
        subBuilder: GroupMember.create)
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'keyEpoch', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GroupInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GroupInfo copyWith(void Function(GroupInfo) updates) =>
      super.copyWith((message) => updates(message as GroupInfo)) as GroupInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GroupInfo create() => GroupInfo._();
  @$core.override
  GroupInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GroupInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GroupInfo>(create);
  static GroupInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get groupId => $_getSZ(0);
  @$pb.TagNumber(1)
  set groupId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGroupId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGroupId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get adminPubkey => $_getSZ(2);
  @$pb.TagNumber(3)
  set adminPubkey($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAdminPubkey() => $_has(2);
  @$pb.TagNumber(3)
  void clearAdminPubkey() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<GroupMember> get members => $_getList(3);

  @$pb.TagNumber(5)
  $fixnum.Int64 get keyEpoch => $_getI64(4);
  @$pb.TagNumber(5)
  set keyEpoch($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasKeyEpoch() => $_has(4);
  @$pb.TagNumber(5)
  void clearKeyEpoch() => $_clearField(5);
}

class GroupMember extends $pb.GeneratedMessage {
  factory GroupMember({
    $core.String? pubkey,
    $core.String? nickname,
    $core.String? role,
  }) {
    final result = create();
    if (pubkey != null) result.pubkey = pubkey;
    if (nickname != null) result.nickname = nickname;
    if (role != null) result.role = role;
    return result;
  }

  GroupMember._();

  factory GroupMember.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GroupMember.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GroupMember',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'pubkey')
    ..aOS(2, _omitFieldNames ? '' : 'nickname')
    ..aOS(3, _omitFieldNames ? '' : 'role')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GroupMember clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GroupMember copyWith(void Function(GroupMember) updates) =>
      super.copyWith((message) => updates(message as GroupMember))
          as GroupMember;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GroupMember create() => GroupMember._();
  @$core.override
  GroupMember createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GroupMember getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GroupMember>(create);
  static GroupMember? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pubkey => $_getSZ(0);
  @$pb.TagNumber(1)
  set pubkey($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPubkey() => $_has(0);
  @$pb.TagNumber(1)
  void clearPubkey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get nickname => $_getSZ(1);
  @$pb.TagNumber(2)
  set nickname($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNickname() => $_has(1);
  @$pb.TagNumber(2)
  void clearNickname() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get role => $_getSZ(2);
  @$pb.TagNumber(3)
  set role($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRole() => $_has(2);
  @$pb.TagNumber(3)
  void clearRole() => $_clearField(3);
}

class TransportStatusResponse extends $pb.GeneratedMessage {
  factory TransportStatusResponse({
    $core.bool? dhtConnected,
    $core.int? discoveredRelays,
    $core.String? dnsMode,
  }) {
    final result = create();
    if (dhtConnected != null) result.dhtConnected = dhtConnected;
    if (discoveredRelays != null) result.discoveredRelays = discoveredRelays;
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
    ..aOS(5, _omitFieldNames ? '' : 'dnsMode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransportStatusResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransportStatusResponse copyWith(
          void Function(TransportStatusResponse) updates) =>
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

  /// bool libp2p_direct = 3;  — removed, unused
  /// bool libp2p_circuit = 4; — removed, unused
  @$pb.TagNumber(5)
  $core.String get dnsMode => $_getSZ(2);
  @$pb.TagNumber(5)
  set dnsMode($core.String value) => $_setString(2, value);
  @$pb.TagNumber(5)
  $core.bool hasDnsMode() => $_has(2);
  @$pb.TagNumber(5)
  void clearDnsMode() => $_clearField(5);
}

/// Profile messages
class ProfileInfo extends $pb.GeneratedMessage {
  factory ProfileInfo({
    $core.String? nickname,
    $core.String? bio,
  }) {
    final result = create();
    if (nickname != null) result.nickname = nickname;
    if (bio != null) result.bio = bio;
    return result;
  }

  ProfileInfo._();

  factory ProfileInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProfileInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProfileInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'nickname')
    ..aOS(2, _omitFieldNames ? '' : 'bio')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProfileInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProfileInfo copyWith(void Function(ProfileInfo) updates) =>
      super.copyWith((message) => updates(message as ProfileInfo))
          as ProfileInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProfileInfo create() => ProfileInfo._();
  @$core.override
  ProfileInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProfileInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProfileInfo>(create);
  static ProfileInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get nickname => $_getSZ(0);
  @$pb.TagNumber(1)
  set nickname($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNickname() => $_has(0);
  @$pb.TagNumber(1)
  void clearNickname() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get bio => $_getSZ(1);
  @$pb.TagNumber(2)
  set bio($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBio() => $_has(1);
  @$pb.TagNumber(2)
  void clearBio() => $_clearField(2);
}

class SetProfilePicRequest extends $pb.GeneratedMessage {
  factory SetProfilePicRequest({
    $core.List<$core.int>? imageData,
    $core.String? mimeType,
  }) {
    final result = create();
    if (imageData != null) result.imageData = imageData;
    if (mimeType != null) result.mimeType = mimeType;
    return result;
  }

  SetProfilePicRequest._();

  factory SetProfilePicRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetProfilePicRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetProfilePicRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'imageData', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'mimeType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetProfilePicRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetProfilePicRequest copyWith(void Function(SetProfilePicRequest) updates) =>
      super.copyWith((message) => updates(message as SetProfilePicRequest))
          as SetProfilePicRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetProfilePicRequest create() => SetProfilePicRequest._();
  @$core.override
  SetProfilePicRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetProfilePicRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetProfilePicRequest>(create);
  static SetProfilePicRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get imageData => $_getN(0);
  @$pb.TagNumber(1)
  set imageData($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasImageData() => $_has(0);
  @$pb.TagNumber(1)
  void clearImageData() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get mimeType => $_getSZ(1);
  @$pb.TagNumber(2)
  set mimeType($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMimeType() => $_has(1);
  @$pb.TagNumber(2)
  void clearMimeType() => $_clearField(2);
}

class ProfilePicResponse extends $pb.GeneratedMessage {
  factory ProfilePicResponse({
    $core.List<$core.int>? imageData,
    $core.String? mimeType,
  }) {
    final result = create();
    if (imageData != null) result.imageData = imageData;
    if (mimeType != null) result.mimeType = mimeType;
    return result;
  }

  ProfilePicResponse._();

  factory ProfilePicResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProfilePicResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProfilePicResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'imageData', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'mimeType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProfilePicResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProfilePicResponse copyWith(void Function(ProfilePicResponse) updates) =>
      super.copyWith((message) => updates(message as ProfilePicResponse))
          as ProfilePicResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProfilePicResponse create() => ProfilePicResponse._();
  @$core.override
  ProfilePicResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProfilePicResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProfilePicResponse>(create);
  static ProfilePicResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get imageData => $_getN(0);
  @$pb.TagNumber(1)
  set imageData($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasImageData() => $_has(0);
  @$pb.TagNumber(1)
  void clearImageData() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get mimeType => $_getSZ(1);
  @$pb.TagNumber(2)
  set mimeType($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMimeType() => $_has(1);
  @$pb.TagNumber(2)
  void clearMimeType() => $_clearField(2);
}

class SetTransportModeRequest extends $pb.GeneratedMessage {
  factory SetTransportModeRequest({
    SetTransportModeRequest_Mode? mode,
  }) {
    final result = create();
    if (mode != null) result.mode = mode;
    return result;
  }

  SetTransportModeRequest._();

  factory SetTransportModeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetTransportModeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetTransportModeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aE<SetTransportModeRequest_Mode>(1, _omitFieldNames ? '' : 'mode',
        enumValues: SetTransportModeRequest_Mode.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetTransportModeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetTransportModeRequest copyWith(
          void Function(SetTransportModeRequest) updates) =>
      super.copyWith((message) => updates(message as SetTransportModeRequest))
          as SetTransportModeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetTransportModeRequest create() => SetTransportModeRequest._();
  @$core.override
  SetTransportModeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetTransportModeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetTransportModeRequest>(create);
  static SetTransportModeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  SetTransportModeRequest_Mode get mode => $_getN(0);
  @$pb.TagNumber(1)
  set mode(SetTransportModeRequest_Mode value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMode() => $_has(0);
  @$pb.TagNumber(1)
  void clearMode() => $_clearField(1);
}

class SetChunkSizeRequest extends $pb.GeneratedMessage {
  factory SetChunkSizeRequest({
    $core.int? size,
  }) {
    final result = create();
    if (size != null) result.size = size;
    return result;
  }

  SetChunkSizeRequest._();

  factory SetChunkSizeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetChunkSizeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetChunkSizeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'relaypb'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'size')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetChunkSizeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetChunkSizeRequest copyWith(void Function(SetChunkSizeRequest) updates) =>
      super.copyWith((message) => updates(message as SetChunkSizeRequest))
          as SetChunkSizeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetChunkSizeRequest create() => SetChunkSizeRequest._();
  @$core.override
  SetChunkSizeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetChunkSizeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetChunkSizeRequest>(create);
  static SetChunkSizeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get size => $_getIZ(0);
  @$pb.TagNumber(1)
  set size($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSize() => $_has(0);
  @$pb.TagNumber(1)
  void clearSize() => $_clearField(1);
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
      _client.invoke<TransportStatusResponse>(ctx, 'RelayClient',
          'GetTransportStatus', request, TransportStatusResponse());

  /// New media RPCs
  $async.Future<SendMediaResponse> sendMedia(
          $pb.ClientContext? ctx, SendMediaRequest request) =>
      _client.invoke<SendMediaResponse>(
          ctx, 'RelayClient', 'SendMedia', request, SendMediaResponse());
  $async.Future<MediaStatusResponse> getMediaStatus(
          $pb.ClientContext? ctx, GetMediaStatusRequest request) =>
      _client.invoke<MediaStatusResponse>(
          ctx, 'RelayClient', 'GetMediaStatus', request, MediaStatusResponse());
  $async.Future<Empty> cancelSend(
          $pb.ClientContext? ctx, CancelSendRequest request) =>
      _client.invoke<Empty>(ctx, 'RelayClient', 'CancelSend', request, Empty());
  $async.Future<SendMediaResponse> sendMediaStream(
          $pb.ClientContext? ctx, MediaUploadChunk request) =>
      _client.invoke<SendMediaResponse>(
          ctx, 'RelayClient', 'SendMediaStream', request, SendMediaResponse());
  $async.Future<GenerateInviteCodeResponse> generateInviteCode(
          $pb.ClientContext? ctx, GenerateInviteCodeRequest request) =>
      _client.invoke<GenerateInviteCodeResponse>(ctx, 'RelayClient',
          'GenerateInviteCode', request, GenerateInviteCodeResponse());
  $async.Future<JoinViaCodeResponse> joinViaCode(
          $pb.ClientContext? ctx, JoinViaCodeRequest request) =>
      _client.invoke<JoinViaCodeResponse>(
          ctx, 'RelayClient', 'JoinViaCode', request, JoinViaCodeResponse());
  $async.Future<Empty> removePeer($pb.ClientContext? ctx, PeerInfo request) =>
      _client.invoke<Empty>(ctx, 'RelayClient', 'RemovePeer', request, Empty());
  $async.Future<ListPeersResponse> listPeers(
          $pb.ClientContext? ctx, Empty request) =>
      _client.invoke<ListPeersResponse>(
          ctx, 'RelayClient', 'ListPeers', request, ListPeersResponse());
  $async.Future<CreateGroupResponse> createGroup(
          $pb.ClientContext? ctx, CreateGroupRequest request) =>
      _client.invoke<CreateGroupResponse>(
          ctx, 'RelayClient', 'CreateGroup', request, CreateGroupResponse());
  $async.Future<ListGroupsResponse> listGroups(
          $pb.ClientContext? ctx, Empty request) =>
      _client.invoke<ListGroupsResponse>(
          ctx, 'RelayClient', 'ListGroups', request, ListGroupsResponse());
  $async.Future<Empty> leaveGroup(
          $pb.ClientContext? ctx, LeaveGroupRequest request) =>
      _client.invoke<Empty>(ctx, 'RelayClient', 'LeaveGroup', request, Empty());
  $async.Future<Empty> removeGroupMember(
          $pb.ClientContext? ctx, RemoveGroupMemberRequest request) =>
      _client.invoke<Empty>(
          ctx, 'RelayClient', 'RemoveGroupMember', request, Empty());

  /// Profile RPCs
  $async.Future<Empty> updateProfile(
          $pb.ClientContext? ctx, ProfileInfo request) =>
      _client.invoke<Empty>(
          ctx, 'RelayClient', 'UpdateProfile', request, Empty());
  $async.Future<ProfilePicResponse> getProfilePic(
          $pb.ClientContext? ctx, Empty request) =>
      _client.invoke<ProfilePicResponse>(
          ctx, 'RelayClient', 'GetProfilePic', request, ProfilePicResponse());
  $async.Future<Empty> setProfilePic(
          $pb.ClientContext? ctx, SetProfilePicRequest request) =>
      _client.invoke<Empty>(
          ctx, 'RelayClient', 'SetProfilePic', request, Empty());

  /// Config RPCs (replaces file-watchers)
  $async.Future<Empty> setTransportMode(
          $pb.ClientContext? ctx, SetTransportModeRequest request) =>
      _client.invoke<Empty>(
          ctx, 'RelayClient', 'SetTransportMode', request, Empty());
  $async.Future<Empty> setChunkSize(
          $pb.ClientContext? ctx, SetChunkSizeRequest request) =>
      _client.invoke<Empty>(
          ctx, 'RelayClient', 'SetChunkSize', request, Empty());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
