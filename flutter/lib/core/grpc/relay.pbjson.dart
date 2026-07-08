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

@$core.Deprecated('Use sendRequestDescriptor instead')
const SendRequest$json = {
  '1': 'SendRequest',
  '2': [
    {'1': 'peer_pubkey', '3': 1, '4': 1, '5': 9, '10': 'peerPubkey'},
    {'1': 'plaintext', '3': 2, '4': 1, '5': 12, '10': 'plaintext'},
  ],
};

/// Descriptor for `SendRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendRequestDescriptor = $convert.base64Decode(
    'CgtTZW5kUmVxdWVzdBIfCgtwZWVyX3B1YmtleRgBIAEoCVIKcGVlclB1YmtleRIcCglwbGFpbn'
    'RleHQYAiABKAxSCXBsYWludGV4dA==');

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
  ],
};

/// Descriptor for `ReceivedMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List receivedMessageDescriptor = $convert.base64Decode(
    'Cg9SZWNlaXZlZE1lc3NhZ2USGwoJZnJvbV9wZWVyGAEgASgJUghmcm9tUGVlchIdCgptZXNzYW'
    'dlX2lkGAIgASgJUgltZXNzYWdlSWQSHAoJcGxhaW50ZXh0GAMgASgMUglwbGFpbnRleHQSHAoJ'
    'dGltZXN0YW1wGAQgASgDUgl0aW1lc3RhbXA=');

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
  ],
};

/// Descriptor for `IdentityInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List identityInfoDescriptor = $convert
    .base64Decode('CgxJZGVudGl0eUluZm8SFgoGcHVia2V5GAEgASgJUgZwdWJrZXk=');

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
    'JlbGF5cGIuRW1wdHk=');
