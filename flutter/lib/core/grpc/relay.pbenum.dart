// This is a generated file - do not edit.
//
// Generated from relay.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class MediaStatusResponse_Status extends $pb.ProtobufEnum {
  static const MediaStatusResponse_Status QUEUED =
      MediaStatusResponse_Status._(0, _omitEnumNames ? '' : 'QUEUED');
  static const MediaStatusResponse_Status SENDING =
      MediaStatusResponse_Status._(1, _omitEnumNames ? '' : 'SENDING');
  static const MediaStatusResponse_Status ARRIVING =
      MediaStatusResponse_Status._(2, _omitEnumNames ? '' : 'ARRIVING');
  static const MediaStatusResponse_Status COMPLETE =
      MediaStatusResponse_Status._(3, _omitEnumNames ? '' : 'COMPLETE');
  static const MediaStatusResponse_Status FAILED =
      MediaStatusResponse_Status._(4, _omitEnumNames ? '' : 'FAILED');

  static const $core.List<MediaStatusResponse_Status> values =
      <MediaStatusResponse_Status>[
    QUEUED,
    SENDING,
    ARRIVING,
    COMPLETE,
    FAILED,
  ];

  static final $core.List<MediaStatusResponse_Status?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static MediaStatusResponse_Status? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MediaStatusResponse_Status._(super.value, super.name);
}

class SetTransportModeRequest_Mode extends $pb.ProtobufEnum {
  static const SetTransportModeRequest_Mode AUTO =
      SetTransportModeRequest_Mode._(0, _omitEnumNames ? '' : 'AUTO');
  static const SetTransportModeRequest_Mode TCP =
      SetTransportModeRequest_Mode._(1, _omitEnumNames ? '' : 'TCP');
  static const SetTransportModeRequest_Mode UDP =
      SetTransportModeRequest_Mode._(2, _omitEnumNames ? '' : 'UDP');

  static const $core.List<SetTransportModeRequest_Mode> values =
      <SetTransportModeRequest_Mode>[
    AUTO,
    TCP,
    UDP,
  ];

  static final $core.List<SetTransportModeRequest_Mode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static SetTransportModeRequest_Mode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SetTransportModeRequest_Mode._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
