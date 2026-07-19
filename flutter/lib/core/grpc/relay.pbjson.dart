// This is a generated file - do not edit.
//
// Generated from relay.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use sendMediaRequestDescriptor instead')
const SendMediaRequest$json = {
  '1': 'SendMediaRequest',
  '2': [
    {'1': 'peer_pubkey', '3': 1, '4': 1, '5': 9, '10': 'peerPubkey'},
    {'1': 'media_data', '3': 2, '4': 1, '5': 12, '10': 'mediaData'},
    {'1': 'filename', '3': 3, '4': 1, '5': 9, '10': 'filename'},
    {'1': 'mime_type', '3': 4, '4': 1, '5': 9, '10': 'mimeType'},
  ],
};

/// Descriptor for `SendMediaRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendMediaRequestDescriptor = $convert.base64Decode(
    'ChBTZW5kTWVkaWFSZXF1ZXN0Eh8KC3BlZXJfcHVia2V5GAEgASgJUgpwZWVyUHVia2V5Eh0KCm'
    '1lZGlhX2RhdGEYAiABKAxSCW1lZGlhRGF0YRIaCghmaWxlbmFtZRgDIAEoCVIIZmlsZW5hbWUS'
    'GwoJbWltZV90eXBlGAQgASgJUghtaW1lVHlwZQ==');

@$core.Deprecated('Use sendMediaResponseDescriptor instead')
const SendMediaResponse$json = {
  '1': 'SendMediaResponse',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {
      '1': 'estimated_seconds',
      '3': 2,
      '4': 1,
      '5': 5,
      '10': 'estimatedSeconds'
    },
    {'1': 'transport', '3': 3, '4': 1, '5': 9, '10': 'transport'},
  ],
};

/// Descriptor for `SendMediaResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendMediaResponseDescriptor = $convert.base64Decode(
    'ChFTZW5kTWVkaWFSZXNwb25zZRIdCgptZXNzYWdlX2lkGAEgASgJUgltZXNzYWdlSWQSKwoRZX'
    'N0aW1hdGVkX3NlY29uZHMYAiABKAVSEGVzdGltYXRlZFNlY29uZHMSHAoJdHJhbnNwb3J0GAMg'
    'ASgJUgl0cmFuc3BvcnQ=');

@$core.Deprecated('Use getMediaStatusRequestDescriptor instead')
const GetMediaStatusRequest$json = {
  '1': 'GetMediaStatusRequest',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
  ],
};

/// Descriptor for `GetMediaStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getMediaStatusRequestDescriptor = $convert.base64Decode(
    'ChVHZXRNZWRpYVN0YXR1c1JlcXVlc3QSHQoKbWVzc2FnZV9pZBgBIAEoCVIJbWVzc2FnZUlk');

@$core.Deprecated('Use mediaStatusResponseDescriptor instead')
const MediaStatusResponse$json = {
  '1': 'MediaStatusResponse',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {
      '1': 'status',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.relaypb.MediaStatusResponse.Status',
      '10': 'status'
    },
    {'1': 'progress_pct', '3': 3, '4': 1, '5': 5, '10': 'progressPct'},
    {'1': 'error', '3': 4, '4': 1, '5': 9, '10': 'error'},
  ],
  '4': [MediaStatusResponse_Status$json],
};

@$core.Deprecated('Use mediaStatusResponseDescriptor instead')
const MediaStatusResponse_Status$json = {
  '1': 'Status',
  '2': [
    {'1': 'QUEUED', '2': 0},
    {'1': 'SENDING', '2': 1},
    {'1': 'ARRIVING', '2': 2},
    {'1': 'COMPLETE', '2': 3},
    {'1': 'FAILED', '2': 4},
  ],
};

/// Descriptor for `MediaStatusResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mediaStatusResponseDescriptor = $convert.base64Decode(
    'ChNNZWRpYVN0YXR1c1Jlc3BvbnNlEh0KCm1lc3NhZ2VfaWQYASABKAlSCW1lc3NhZ2VJZBI7Cg'
    'ZzdGF0dXMYAiABKA4yIy5yZWxheXBiLk1lZGlhU3RhdHVzUmVzcG9uc2UuU3RhdHVzUgZzdGF0'
    'dXMSIQoMcHJvZ3Jlc3NfcGN0GAMgASgFUgtwcm9ncmVzc1BjdBIUCgVlcnJvchgEIAEoCVIFZX'
    'Jyb3IiSQoGU3RhdHVzEgoKBlFVRVVFRBAAEgsKB1NFTkRJTkcQARIMCghBUlJJVklORxACEgwK'
    'CENPTVBMRVRFEAMSCgoGRkFJTEVEEAQ=');

@$core.Deprecated('Use cancelSendRequestDescriptor instead')
const CancelSendRequest$json = {
  '1': 'CancelSendRequest',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
  ],
};

/// Descriptor for `CancelSendRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cancelSendRequestDescriptor = $convert.base64Decode(
    'ChFDYW5jZWxTZW5kUmVxdWVzdBIdCgptZXNzYWdlX2lkGAEgASgJUgltZXNzYWdlSWQ=');

@$core.Deprecated('Use mediaUploadChunkDescriptor instead')
const MediaUploadChunk$json = {
  '1': 'MediaUploadChunk',
  '2': [
    {'1': 'transfer_id', '3': 1, '4': 1, '5': 9, '10': 'transferId'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
    {'1': 'chunk_index', '3': 3, '4': 1, '5': 13, '10': 'chunkIndex'},
  ],
};

/// Descriptor for `MediaUploadChunk`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mediaUploadChunkDescriptor = $convert.base64Decode(
    'ChBNZWRpYVVwbG9hZENodW5rEh8KC3RyYW5zZmVyX2lkGAEgASgJUgp0cmFuc2ZlcklkEhIKBG'
    'RhdGEYAiABKAxSBGRhdGESHwoLY2h1bmtfaW5kZXgYAyABKA1SCmNodW5rSW5kZXg=');

@$core.Deprecated('Use sendRequestDescriptor instead')
const SendRequest$json = {
  '1': 'SendRequest',
  '2': [
    {'1': 'peer_pubkey', '3': 1, '4': 1, '5': 9, '10': 'peerPubkey'},
    {'1': 'plaintext', '3': 2, '4': 1, '5': 12, '10': 'plaintext'},
    {
      '1': 'client_timestamp_ms',
      '3': 3,
      '4': 1,
      '5': 4,
      '10': 'clientTimestampMs'
    },
    {'1': 'group_id', '3': 4, '4': 1, '5': 9, '10': 'groupId'},
  ],
};

/// Descriptor for `SendRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendRequestDescriptor = $convert.base64Decode(
    'CgtTZW5kUmVxdWVzdBIfCgtwZWVyX3B1YmtleRgBIAEoCVIKcGVlclB1YmtleRIcCglwbGFpbn'
    'RleHQYAiABKAxSCXBsYWludGV4dBIuChNjbGllbnRfdGltZXN0YW1wX21zGAMgASgEUhFjbGll'
    'bnRUaW1lc3RhbXBNcxIZCghncm91cF9pZBgEIAEoCVIHZ3JvdXBJZA==');

@$core.Deprecated('Use sendResponseDescriptor instead')
const SendResponse$json = {
  '1': 'SendResponse',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'queued', '3': 2, '4': 1, '5': 8, '10': 'queued'},
    {'1': 'chunk_count', '3': 3, '4': 1, '5': 5, '10': 'chunkCount'},
  ],
};

/// Descriptor for `SendResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendResponseDescriptor = $convert.base64Decode(
    'CgxTZW5kUmVzcG9uc2USHQoKbWVzc2FnZV9pZBgBIAEoCVIJbWVzc2FnZUlkEhYKBnF1ZXVlZB'
    'gCIAEoCFIGcXVldWVkEh8KC2NodW5rX2NvdW50GAMgASgFUgpjaHVua0NvdW50');

@$core.Deprecated('Use pollRequestDescriptor instead')
const PollRequest$json = {
  '1': 'PollRequest',
};

/// Descriptor for `PollRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pollRequestDescriptor =
    $convert.base64Decode('CgtQb2xsUmVxdWVzdA==');

@$core.Deprecated('Use pollResponseDescriptor instead')
const PollResponse$json = {
  '1': 'PollResponse',
  '2': [
    {
      '1': 'messages',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.relaypb.ReceivedMessage',
      '10': 'messages'
    },
  ],
};

/// Descriptor for `PollResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pollResponseDescriptor = $convert.base64Decode(
    'CgxQb2xsUmVzcG9uc2USNAoIbWVzc2FnZXMYASADKAsyGC5yZWxheXBiLlJlY2VpdmVkTWVzc2'
    'FnZVIIbWVzc2FnZXM=');

@$core.Deprecated('Use receivedMessageDescriptor instead')
const ReceivedMessage$json = {
  '1': 'ReceivedMessage',
  '2': [
    {'1': 'from_peer', '3': 1, '4': 1, '5': 9, '10': 'fromPeer'},
    {'1': 'message_id', '3': 2, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'plaintext', '3': 3, '4': 1, '5': 12, '10': 'plaintext'},
    {'1': 'timestamp', '3': 4, '4': 1, '5': 3, '10': 'timestamp'},
    {
      '1': 'server_timestamp_ms',
      '3': 5,
      '4': 1,
      '5': 4,
      '10': 'serverTimestampMs'
    },
    {'1': 'sequence_number', '3': 6, '4': 1, '5': 4, '10': 'sequenceNumber'},
    {'1': 'group_id', '3': 7, '4': 1, '5': 9, '10': 'groupId'},
  ],
};

/// Descriptor for `ReceivedMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List receivedMessageDescriptor = $convert.base64Decode(
    'Cg9SZWNlaXZlZE1lc3NhZ2USGwoJZnJvbV9wZWVyGAEgASgJUghmcm9tUGVlchIdCgptZXNzYW'
    'dlX2lkGAIgASgJUgltZXNzYWdlSWQSHAoJcGxhaW50ZXh0GAMgASgMUglwbGFpbnRleHQSHAoJ'
    'dGltZXN0YW1wGAQgASgDUgl0aW1lc3RhbXASLgoTc2VydmVyX3RpbWVzdGFtcF9tcxgFIAEoBF'
    'IRc2VydmVyVGltZXN0YW1wTXMSJwoPc2VxdWVuY2VfbnVtYmVyGAYgASgEUg5zZXF1ZW5jZU51'
    'bWJlchIZCghncm91cF9pZBgHIAEoCVIHZ3JvdXBJZA==');

@$core.Deprecated('Use emptyDescriptor instead')
const Empty$json = {
  '1': 'Empty',
};

/// Descriptor for `Empty`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List emptyDescriptor =
    $convert.base64Decode('CgVFbXB0eQ==');

@$core.Deprecated('Use relayEndpointDescriptor instead')
const RelayEndpoint$json = {
  '1': 'RelayEndpoint',
  '2': [
    {'1': 'address', '3': 1, '4': 1, '5': 9, '10': 'address'},
  ],
};

/// Descriptor for `RelayEndpoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List relayEndpointDescriptor = $convert
    .base64Decode('Cg1SZWxheUVuZHBvaW50EhgKB2FkZHJlc3MYASABKAlSB2FkZHJlc3M=');

@$core.Deprecated('Use relayStatusListDescriptor instead')
const RelayStatusList$json = {
  '1': 'RelayStatusList',
  '2': [
    {
      '1': 'endpoints',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.relaypb.RelayStatus',
      '10': 'endpoints'
    },
  ],
};

/// Descriptor for `RelayStatusList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List relayStatusListDescriptor = $convert.base64Decode(
    'Cg9SZWxheVN0YXR1c0xpc3QSMgoJZW5kcG9pbnRzGAEgAygLMhQucmVsYXlwYi5SZWxheVN0YX'
    'R1c1IJZW5kcG9pbnRz');

@$core.Deprecated('Use relayStatusDescriptor instead')
const RelayStatus$json = {
  '1': 'RelayStatus',
  '2': [
    {'1': 'address', '3': 1, '4': 1, '5': 9, '10': 'address'},
    {'1': 'reachable', '3': 2, '4': 1, '5': 8, '10': 'reachable'},
    {'1': 'latency_ms', '3': 3, '4': 1, '5': 3, '10': 'latencyMs'},
    {'1': 'last_error', '3': 4, '4': 1, '5': 9, '10': 'lastError'},
    {'1': 'blackout_mode', '3': 5, '4': 1, '5': 8, '10': 'blackoutMode'},
  ],
};

/// Descriptor for `RelayStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List relayStatusDescriptor = $convert.base64Decode(
    'CgtSZWxheVN0YXR1cxIYCgdhZGRyZXNzGAEgASgJUgdhZGRyZXNzEhwKCXJlYWNoYWJsZRgCIA'
    'EoCFIJcmVhY2hhYmxlEh0KCmxhdGVuY3lfbXMYAyABKANSCWxhdGVuY3lNcxIdCgpsYXN0X2Vy'
    'cm9yGAQgASgJUglsYXN0RXJyb3ISIwoNYmxhY2tvdXRfbW9kZRgFIAEoCFIMYmxhY2tvdXRNb2'
    'Rl');

@$core.Deprecated('Use identityInfoDescriptor instead')
const IdentityInfo$json = {
  '1': 'IdentityInfo',
  '2': [
    {'1': 'pubkey', '3': 1, '4': 1, '5': 9, '10': 'pubkey'},
    {'1': 'nickname', '3': 2, '4': 1, '5': 9, '10': 'nickname'},
    {'1': 'bio', '3': 3, '4': 1, '5': 9, '10': 'bio'},
  ],
};

/// Descriptor for `IdentityInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List identityInfoDescriptor = $convert.base64Decode(
    'CgxJZGVudGl0eUluZm8SFgoGcHVia2V5GAEgASgJUgZwdWJrZXkSGgoIbmlja25hbWUYAiABKA'
    'lSCG5pY2tuYW1lEhAKA2JpbxgDIAEoCVIDYmlv');

@$core.Deprecated('Use peerInfoDescriptor instead')
const PeerInfo$json = {
  '1': 'PeerInfo',
  '2': [
    {'1': 'nickname', '3': 1, '4': 1, '5': 9, '10': 'nickname'},
    {'1': 'pubkey', '3': 2, '4': 1, '5': 9, '10': 'pubkey'},
  ],
};

/// Descriptor for `PeerInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List peerInfoDescriptor = $convert.base64Decode(
    'CghQZWVySW5mbxIaCghuaWNrbmFtZRgBIAEoCVIIbmlja25hbWUSFgoGcHVia2V5GAIgASgJUg'
    'ZwdWJrZXk=');

@$core.Deprecated('Use generateInviteCodeRequestDescriptor instead')
const GenerateInviteCodeRequest$json = {
  '1': 'GenerateInviteCodeRequest',
  '2': [
    {'1': 'nickname', '3': 1, '4': 1, '5': 9, '10': 'nickname'},
  ],
};

/// Descriptor for `GenerateInviteCodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateInviteCodeRequestDescriptor =
    $convert.base64Decode(
        'ChlHZW5lcmF0ZUludml0ZUNvZGVSZXF1ZXN0EhoKCG5pY2tuYW1lGAEgASgJUghuaWNrbmFtZQ'
        '==');

@$core.Deprecated('Use generateInviteCodeResponseDescriptor instead')
const GenerateInviteCodeResponse$json = {
  '1': 'GenerateInviteCodeResponse',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
  ],
};

/// Descriptor for `GenerateInviteCodeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateInviteCodeResponseDescriptor =
    $convert.base64Decode(
        'ChpHZW5lcmF0ZUludml0ZUNvZGVSZXNwb25zZRISCgRjb2RlGAEgASgJUgRjb2Rl');

@$core.Deprecated('Use joinViaCodeRequestDescriptor instead')
const JoinViaCodeRequest$json = {
  '1': 'JoinViaCodeRequest',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
  ],
};

/// Descriptor for `JoinViaCodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinViaCodeRequestDescriptor = $convert
    .base64Decode('ChJKb2luVmlhQ29kZVJlcXVlc3QSEgoEY29kZRgBIAEoCVIEY29kZQ==');

@$core.Deprecated('Use joinViaCodeResponseDescriptor instead')
const JoinViaCodeResponse$json = {
  '1': 'JoinViaCodeResponse',
  '2': [
    {'1': 'peer_nickname', '3': 1, '4': 1, '5': 9, '10': 'peerNickname'},
    {'1': 'peer_pubkey', '3': 2, '4': 1, '5': 9, '10': 'peerPubkey'},
  ],
};

/// Descriptor for `JoinViaCodeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinViaCodeResponseDescriptor = $convert.base64Decode(
    'ChNKb2luVmlhQ29kZVJlc3BvbnNlEiMKDXBlZXJfbmlja25hbWUYASABKAlSDHBlZXJOaWNrbm'
    'FtZRIfCgtwZWVyX3B1YmtleRgCIAEoCVIKcGVlclB1YmtleQ==');

@$core.Deprecated('Use listPeersResponseDescriptor instead')
const ListPeersResponse$json = {
  '1': 'ListPeersResponse',
  '2': [
    {
      '1': 'peers',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.relaypb.PeerInfo',
      '10': 'peers'
    },
  ],
};

/// Descriptor for `ListPeersResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listPeersResponseDescriptor = $convert.base64Decode(
    'ChFMaXN0UGVlcnNSZXNwb25zZRInCgVwZWVycxgBIAMoCzIRLnJlbGF5cGIuUGVlckluZm9SBX'
    'BlZXJz');

@$core.Deprecated('Use createGroupRequestDescriptor instead')
const CreateGroupRequest$json = {
  '1': 'CreateGroupRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'member_pubkeys', '3': 2, '4': 3, '5': 9, '10': 'memberPubkeys'},
  ],
};

/// Descriptor for `CreateGroupRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createGroupRequestDescriptor = $convert.base64Decode(
    'ChJDcmVhdGVHcm91cFJlcXVlc3QSEgoEbmFtZRgBIAEoCVIEbmFtZRIlCg5tZW1iZXJfcHVia2'
    'V5cxgCIAMoCVINbWVtYmVyUHVia2V5cw==');

@$core.Deprecated('Use createGroupResponseDescriptor instead')
const CreateGroupResponse$json = {
  '1': 'CreateGroupResponse',
  '2': [
    {'1': 'group_id', '3': 1, '4': 1, '5': 9, '10': 'groupId'},
  ],
};

/// Descriptor for `CreateGroupResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createGroupResponseDescriptor =
    $convert.base64Decode(
        'ChNDcmVhdGVHcm91cFJlc3BvbnNlEhkKCGdyb3VwX2lkGAEgASgJUgdncm91cElk');

@$core.Deprecated('Use leaveGroupRequestDescriptor instead')
const LeaveGroupRequest$json = {
  '1': 'LeaveGroupRequest',
  '2': [
    {'1': 'group_id', '3': 1, '4': 1, '5': 9, '10': 'groupId'},
  ],
};

/// Descriptor for `LeaveGroupRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List leaveGroupRequestDescriptor = $convert.base64Decode(
    'ChFMZWF2ZUdyb3VwUmVxdWVzdBIZCghncm91cF9pZBgBIAEoCVIHZ3JvdXBJZA==');

@$core.Deprecated('Use removeGroupMemberRequestDescriptor instead')
const RemoveGroupMemberRequest$json = {
  '1': 'RemoveGroupMemberRequest',
  '2': [
    {'1': 'group_id', '3': 1, '4': 1, '5': 9, '10': 'groupId'},
    {'1': 'member_pubkey', '3': 2, '4': 1, '5': 9, '10': 'memberPubkey'},
  ],
};

/// Descriptor for `RemoveGroupMemberRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeGroupMemberRequestDescriptor =
    $convert.base64Decode(
        'ChhSZW1vdmVHcm91cE1lbWJlclJlcXVlc3QSGQoIZ3JvdXBfaWQYASABKAlSB2dyb3VwSWQSIw'
        'oNbWVtYmVyX3B1YmtleRgCIAEoCVIMbWVtYmVyUHVia2V5');

@$core.Deprecated('Use listGroupsResponseDescriptor instead')
const ListGroupsResponse$json = {
  '1': 'ListGroupsResponse',
  '2': [
    {
      '1': 'groups',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.relaypb.GroupInfo',
      '10': 'groups'
    },
  ],
};

/// Descriptor for `ListGroupsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listGroupsResponseDescriptor = $convert.base64Decode(
    'ChJMaXN0R3JvdXBzUmVzcG9uc2USKgoGZ3JvdXBzGAEgAygLMhIucmVsYXlwYi5Hcm91cEluZm'
    '9SBmdyb3Vwcw==');

@$core.Deprecated('Use groupInfoDescriptor instead')
const GroupInfo$json = {
  '1': 'GroupInfo',
  '2': [
    {'1': 'group_id', '3': 1, '4': 1, '5': 9, '10': 'groupId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'admin_pubkey', '3': 3, '4': 1, '5': 9, '10': 'adminPubkey'},
    {
      '1': 'members',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.relaypb.GroupMember',
      '10': 'members'
    },
    {'1': 'key_epoch', '3': 5, '4': 1, '5': 4, '10': 'keyEpoch'},
  ],
};

/// Descriptor for `GroupInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List groupInfoDescriptor = $convert.base64Decode(
    'CglHcm91cEluZm8SGQoIZ3JvdXBfaWQYASABKAlSB2dyb3VwSWQSEgoEbmFtZRgCIAEoCVIEbm'
    'FtZRIhCgxhZG1pbl9wdWJrZXkYAyABKAlSC2FkbWluUHVia2V5Ei4KB21lbWJlcnMYBCADKAsy'
    'FC5yZWxheXBiLkdyb3VwTWVtYmVyUgdtZW1iZXJzEhsKCWtleV9lcG9jaBgFIAEoBFIIa2V5RX'
    'BvY2g=');

@$core.Deprecated('Use groupMemberDescriptor instead')
const GroupMember$json = {
  '1': 'GroupMember',
  '2': [
    {'1': 'pubkey', '3': 1, '4': 1, '5': 9, '10': 'pubkey'},
    {'1': 'nickname', '3': 2, '4': 1, '5': 9, '10': 'nickname'},
    {'1': 'role', '3': 3, '4': 1, '5': 9, '10': 'role'},
  ],
};

/// Descriptor for `GroupMember`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List groupMemberDescriptor = $convert.base64Decode(
    'CgtHcm91cE1lbWJlchIWCgZwdWJrZXkYASABKAlSBnB1YmtleRIaCghuaWNrbmFtZRgCIAEoCV'
    'IIbmlja25hbWUSEgoEcm9sZRgDIAEoCVIEcm9sZQ==');

@$core.Deprecated('Use transportStatusResponseDescriptor instead')
const TransportStatusResponse$json = {
  '1': 'TransportStatusResponse',
  '2': [
    {'1': 'dht_connected', '3': 1, '4': 1, '5': 8, '10': 'dhtConnected'},
    {
      '1': 'discovered_relays',
      '3': 2,
      '4': 1,
      '5': 5,
      '10': 'discoveredRelays'
    },
    {'1': 'dns_mode', '3': 5, '4': 1, '5': 9, '10': 'dnsMode'},
  ],
};

/// Descriptor for `TransportStatusResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transportStatusResponseDescriptor = $convert.base64Decode(
    'ChdUcmFuc3BvcnRTdGF0dXNSZXNwb25zZRIjCg1kaHRfY29ubmVjdGVkGAEgASgIUgxkaHRDb2'
    '5uZWN0ZWQSKwoRZGlzY292ZXJlZF9yZWxheXMYAiABKAVSEGRpc2NvdmVyZWRSZWxheXMSGQoI'
    'ZG5zX21vZGUYBSABKAlSB2Ruc01vZGU=');

@$core.Deprecated('Use profileInfoDescriptor instead')
const ProfileInfo$json = {
  '1': 'ProfileInfo',
  '2': [
    {'1': 'nickname', '3': 1, '4': 1, '5': 9, '10': 'nickname'},
    {'1': 'bio', '3': 2, '4': 1, '5': 9, '10': 'bio'},
  ],
};

/// Descriptor for `ProfileInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List profileInfoDescriptor = $convert.base64Decode(
    'CgtQcm9maWxlSW5mbxIaCghuaWNrbmFtZRgBIAEoCVIIbmlja25hbWUSEAoDYmlvGAIgASgJUg'
    'NiaW8=');

@$core.Deprecated('Use setProfilePicRequestDescriptor instead')
const SetProfilePicRequest$json = {
  '1': 'SetProfilePicRequest',
  '2': [
    {'1': 'image_data', '3': 1, '4': 1, '5': 12, '10': 'imageData'},
    {'1': 'mime_type', '3': 2, '4': 1, '5': 9, '10': 'mimeType'},
  ],
};

/// Descriptor for `SetProfilePicRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setProfilePicRequestDescriptor = $convert.base64Decode(
    'ChRTZXRQcm9maWxlUGljUmVxdWVzdBIdCgppbWFnZV9kYXRhGAEgASgMUglpbWFnZURhdGESGw'
    'oJbWltZV90eXBlGAIgASgJUghtaW1lVHlwZQ==');

@$core.Deprecated('Use profilePicResponseDescriptor instead')
const ProfilePicResponse$json = {
  '1': 'ProfilePicResponse',
  '2': [
    {'1': 'image_data', '3': 1, '4': 1, '5': 12, '10': 'imageData'},
    {'1': 'mime_type', '3': 2, '4': 1, '5': 9, '10': 'mimeType'},
  ],
};

/// Descriptor for `ProfilePicResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List profilePicResponseDescriptor = $convert.base64Decode(
    'ChJQcm9maWxlUGljUmVzcG9uc2USHQoKaW1hZ2VfZGF0YRgBIAEoDFIJaW1hZ2VEYXRhEhsKCW'
    '1pbWVfdHlwZRgCIAEoCVIIbWltZVR5cGU=');

@$core.Deprecated('Use setTransportModeRequestDescriptor instead')
const SetTransportModeRequest$json = {
  '1': 'SetTransportModeRequest',
  '2': [
    {
      '1': 'mode',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.relaypb.SetTransportModeRequest.Mode',
      '10': 'mode'
    },
  ],
  '4': [SetTransportModeRequest_Mode$json],
};

@$core.Deprecated('Use setTransportModeRequestDescriptor instead')
const SetTransportModeRequest_Mode$json = {
  '1': 'Mode',
  '2': [
    {'1': 'AUTO', '2': 0},
    {'1': 'TCP', '2': 1},
    {'1': 'UDP', '2': 2},
  ],
};

/// Descriptor for `SetTransportModeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setTransportModeRequestDescriptor = $convert.base64Decode(
    'ChdTZXRUcmFuc3BvcnRNb2RlUmVxdWVzdBI5CgRtb2RlGAEgASgOMiUucmVsYXlwYi5TZXRUcm'
    'Fuc3BvcnRNb2RlUmVxdWVzdC5Nb2RlUgRtb2RlIiIKBE1vZGUSCAoEQVVUTxAAEgcKA1RDUBAB'
    'EgcKA1VEUBAC');

@$core.Deprecated('Use setChunkSizeRequestDescriptor instead')
const SetChunkSizeRequest$json = {
  '1': 'SetChunkSizeRequest',
  '2': [
    {'1': 'size', '3': 1, '4': 1, '5': 5, '10': 'size'},
  ],
};

/// Descriptor for `SetChunkSizeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setChunkSizeRequestDescriptor = $convert
    .base64Decode('ChNTZXRDaHVua1NpemVSZXF1ZXN0EhIKBHNpemUYASABKAVSBHNpemU=');

const $core.Map<$core.String, $core.dynamic> RelayClientServiceBase$json = {
  '1': 'RelayClient',
  '2': [
    {
      '1': 'SendMessage',
      '2': '.relaypb.SendRequest',
      '3': '.relaypb.SendResponse'
    },
    {
      '1': 'PollMessages',
      '2': '.relaypb.PollRequest',
      '3': '.relaypb.PollResponse'
    },
    {
      '1': 'GetRelayStatus',
      '2': '.relaypb.Empty',
      '3': '.relaypb.RelayStatusList'
    },
    {'1': 'AddRelay', '2': '.relaypb.RelayEndpoint', '3': '.relaypb.Empty'},
    {'1': 'RemoveRelay', '2': '.relaypb.RelayEndpoint', '3': '.relaypb.Empty'},
    {'1': 'GetIdentity', '2': '.relaypb.Empty', '3': '.relaypb.IdentityInfo'},
    {'1': 'AddPeer', '2': '.relaypb.PeerInfo', '3': '.relaypb.Empty'},
    {
      '1': 'GetTransportStatus',
      '2': '.relaypb.Empty',
      '3': '.relaypb.TransportStatusResponse'
    },
    {
      '1': 'SendMedia',
      '2': '.relaypb.SendMediaRequest',
      '3': '.relaypb.SendMediaResponse'
    },
    {
      '1': 'GetMediaStatus',
      '2': '.relaypb.GetMediaStatusRequest',
      '3': '.relaypb.MediaStatusResponse'
    },
    {
      '1': 'CancelSend',
      '2': '.relaypb.CancelSendRequest',
      '3': '.relaypb.Empty'
    },
    {
      '1': 'SendMediaStream',
      '2': '.relaypb.MediaUploadChunk',
      '3': '.relaypb.SendMediaResponse',
      '5': true
    },
    {
      '1': 'GenerateInviteCode',
      '2': '.relaypb.GenerateInviteCodeRequest',
      '3': '.relaypb.GenerateInviteCodeResponse'
    },
    {
      '1': 'JoinViaCode',
      '2': '.relaypb.JoinViaCodeRequest',
      '3': '.relaypb.JoinViaCodeResponse'
    },
    {'1': 'RemovePeer', '2': '.relaypb.PeerInfo', '3': '.relaypb.Empty'},
    {
      '1': 'ListPeers',
      '2': '.relaypb.Empty',
      '3': '.relaypb.ListPeersResponse'
    },
    {
      '1': 'CreateGroup',
      '2': '.relaypb.CreateGroupRequest',
      '3': '.relaypb.CreateGroupResponse'
    },
    {
      '1': 'ListGroups',
      '2': '.relaypb.Empty',
      '3': '.relaypb.ListGroupsResponse'
    },
    {
      '1': 'LeaveGroup',
      '2': '.relaypb.LeaveGroupRequest',
      '3': '.relaypb.Empty'
    },
    {
      '1': 'RemoveGroupMember',
      '2': '.relaypb.RemoveGroupMemberRequest',
      '3': '.relaypb.Empty'
    },
    {'1': 'UpdateProfile', '2': '.relaypb.ProfileInfo', '3': '.relaypb.Empty'},
    {
      '1': 'GetProfilePic',
      '2': '.relaypb.Empty',
      '3': '.relaypb.ProfilePicResponse'
    },
    {
      '1': 'SetProfilePic',
      '2': '.relaypb.SetProfilePicRequest',
      '3': '.relaypb.Empty'
    },
    {
      '1': 'SetTransportMode',
      '2': '.relaypb.SetTransportModeRequest',
      '3': '.relaypb.Empty'
    },
    {
      '1': 'SetChunkSize',
      '2': '.relaypb.SetChunkSizeRequest',
      '3': '.relaypb.Empty'
    },
  ],
};

@$core.Deprecated('Use relayClientServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    RelayClientServiceBase$messageJson = {
  '.relaypb.SendRequest': SendRequest$json,
  '.relaypb.SendResponse': SendResponse$json,
  '.relaypb.PollRequest': PollRequest$json,
  '.relaypb.PollResponse': PollResponse$json,
  '.relaypb.ReceivedMessage': ReceivedMessage$json,
  '.relaypb.Empty': Empty$json,
  '.relaypb.RelayStatusList': RelayStatusList$json,
  '.relaypb.RelayStatus': RelayStatus$json,
  '.relaypb.RelayEndpoint': RelayEndpoint$json,
  '.relaypb.IdentityInfo': IdentityInfo$json,
  '.relaypb.PeerInfo': PeerInfo$json,
  '.relaypb.TransportStatusResponse': TransportStatusResponse$json,
  '.relaypb.SendMediaRequest': SendMediaRequest$json,
  '.relaypb.SendMediaResponse': SendMediaResponse$json,
  '.relaypb.GetMediaStatusRequest': GetMediaStatusRequest$json,
  '.relaypb.MediaStatusResponse': MediaStatusResponse$json,
  '.relaypb.CancelSendRequest': CancelSendRequest$json,
  '.relaypb.MediaUploadChunk': MediaUploadChunk$json,
  '.relaypb.GenerateInviteCodeRequest': GenerateInviteCodeRequest$json,
  '.relaypb.GenerateInviteCodeResponse': GenerateInviteCodeResponse$json,
  '.relaypb.JoinViaCodeRequest': JoinViaCodeRequest$json,
  '.relaypb.JoinViaCodeResponse': JoinViaCodeResponse$json,
  '.relaypb.ListPeersResponse': ListPeersResponse$json,
  '.relaypb.CreateGroupRequest': CreateGroupRequest$json,
  '.relaypb.CreateGroupResponse': CreateGroupResponse$json,
  '.relaypb.ListGroupsResponse': ListGroupsResponse$json,
  '.relaypb.GroupInfo': GroupInfo$json,
  '.relaypb.GroupMember': GroupMember$json,
  '.relaypb.LeaveGroupRequest': LeaveGroupRequest$json,
  '.relaypb.RemoveGroupMemberRequest': RemoveGroupMemberRequest$json,
  '.relaypb.ProfileInfo': ProfileInfo$json,
  '.relaypb.ProfilePicResponse': ProfilePicResponse$json,
  '.relaypb.SetProfilePicRequest': SetProfilePicRequest$json,
  '.relaypb.SetTransportModeRequest': SetTransportModeRequest$json,
  '.relaypb.SetChunkSizeRequest': SetChunkSizeRequest$json,
};

/// Descriptor for `RelayClient`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List relayClientServiceDescriptor = $convert.base64Decode(
    'CgtSZWxheUNsaWVudBI6CgtTZW5kTWVzc2FnZRIULnJlbGF5cGIuU2VuZFJlcXVlc3QaFS5yZW'
    'xheXBiLlNlbmRSZXNwb25zZRI7CgxQb2xsTWVzc2FnZXMSFC5yZWxheXBiLlBvbGxSZXF1ZXN0'
    'GhUucmVsYXlwYi5Qb2xsUmVzcG9uc2USOgoOR2V0UmVsYXlTdGF0dXMSDi5yZWxheXBiLkVtcH'
    'R5GhgucmVsYXlwYi5SZWxheVN0YXR1c0xpc3QSMgoIQWRkUmVsYXkSFi5yZWxheXBiLlJlbGF5'
    'RW5kcG9pbnQaDi5yZWxheXBiLkVtcHR5EjUKC1JlbW92ZVJlbGF5EhYucmVsYXlwYi5SZWxheU'
    'VuZHBvaW50Gg4ucmVsYXlwYi5FbXB0eRI0CgtHZXRJZGVudGl0eRIOLnJlbGF5cGIuRW1wdHka'
    'FS5yZWxheXBiLklkZW50aXR5SW5mbxIsCgdBZGRQZWVyEhEucmVsYXlwYi5QZWVySW5mbxoOLn'
    'JlbGF5cGIuRW1wdHkSRgoSR2V0VHJhbnNwb3J0U3RhdHVzEg4ucmVsYXlwYi5FbXB0eRogLnJl'
    'bGF5cGIuVHJhbnNwb3J0U3RhdHVzUmVzcG9uc2USQgoJU2VuZE1lZGlhEhkucmVsYXlwYi5TZW'
    '5kTWVkaWFSZXF1ZXN0GhoucmVsYXlwYi5TZW5kTWVkaWFSZXNwb25zZRJOCg5HZXRNZWRpYVN0'
    'YXR1cxIeLnJlbGF5cGIuR2V0TWVkaWFTdGF0dXNSZXF1ZXN0GhwucmVsYXlwYi5NZWRpYVN0YX'
    'R1c1Jlc3BvbnNlEjgKCkNhbmNlbFNlbmQSGi5yZWxheXBiLkNhbmNlbFNlbmRSZXF1ZXN0Gg4u'
    'cmVsYXlwYi5FbXB0eRJKCg9TZW5kTWVkaWFTdHJlYW0SGS5yZWxheXBiLk1lZGlhVXBsb2FkQ2'
    'h1bmsaGi5yZWxheXBiLlNlbmRNZWRpYVJlc3BvbnNlKAESXQoSR2VuZXJhdGVJbnZpdGVDb2Rl'
    'EiIucmVsYXlwYi5HZW5lcmF0ZUludml0ZUNvZGVSZXF1ZXN0GiMucmVsYXlwYi5HZW5lcmF0ZU'
    'ludml0ZUNvZGVSZXNwb25zZRJICgtKb2luVmlhQ29kZRIbLnJlbGF5cGIuSm9pblZpYUNvZGVS'
    'ZXF1ZXN0GhwucmVsYXlwYi5Kb2luVmlhQ29kZVJlc3BvbnNlEi8KClJlbW92ZVBlZXISES5yZW'
    'xheXBiLlBlZXJJbmZvGg4ucmVsYXlwYi5FbXB0eRI3CglMaXN0UGVlcnMSDi5yZWxheXBiLkVt'
    'cHR5GhoucmVsYXlwYi5MaXN0UGVlcnNSZXNwb25zZRJICgtDcmVhdGVHcm91cBIbLnJlbGF5cG'
    'IuQ3JlYXRlR3JvdXBSZXF1ZXN0GhwucmVsYXlwYi5DcmVhdGVHcm91cFJlc3BvbnNlEjkKCkxp'
    'c3RHcm91cHMSDi5yZWxheXBiLkVtcHR5GhsucmVsYXlwYi5MaXN0R3JvdXBzUmVzcG9uc2USOA'
    'oKTGVhdmVHcm91cBIaLnJlbGF5cGIuTGVhdmVHcm91cFJlcXVlc3QaDi5yZWxheXBiLkVtcHR5'
    'EkYKEVJlbW92ZUdyb3VwTWVtYmVyEiEucmVsYXlwYi5SZW1vdmVHcm91cE1lbWJlclJlcXVlc3'
    'QaDi5yZWxheXBiLkVtcHR5EjUKDVVwZGF0ZVByb2ZpbGUSFC5yZWxheXBiLlByb2ZpbGVJbmZv'
    'Gg4ucmVsYXlwYi5FbXB0eRI8Cg1HZXRQcm9maWxlUGljEg4ucmVsYXlwYi5FbXB0eRobLnJlbG'
    'F5cGIuUHJvZmlsZVBpY1Jlc3BvbnNlEj4KDVNldFByb2ZpbGVQaWMSHS5yZWxheXBiLlNldFBy'
    'b2ZpbGVQaWNSZXF1ZXN0Gg4ucmVsYXlwYi5FbXB0eRJEChBTZXRUcmFuc3BvcnRNb2RlEiAucm'
    'VsYXlwYi5TZXRUcmFuc3BvcnRNb2RlUmVxdWVzdBoOLnJlbGF5cGIuRW1wdHkSPAoMU2V0Q2h1'
    'bmtTaXplEhwucmVsYXlwYi5TZXRDaHVua1NpemVSZXF1ZXN0Gg4ucmVsYXlwYi5FbXB0eQ==');
