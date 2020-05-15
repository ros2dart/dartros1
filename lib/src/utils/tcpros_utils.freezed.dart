// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named

part of 'tcpros_utils.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

class _$TCPRosChunkTearOff {
  const _$TCPRosChunkTearOff();

  _TcpRosChunk call(Uint8List buffer,
      {bool serviceResponse = false, bool serviceResponseSuccess}) {
    return _TcpRosChunk(
      buffer,
      serviceResponse: serviceResponse,
      serviceResponseSuccess: serviceResponseSuccess,
    );
  }
}

// ignore: unused_element
const $TCPRosChunk = _$TCPRosChunkTearOff();

mixin _$TCPRosChunk {
  Uint8List get buffer;
  bool get serviceResponse;
  bool get serviceResponseSuccess;

  $TCPRosChunkCopyWith<TCPRosChunk> get copyWith;
}

abstract class $TCPRosChunkCopyWith<$Res> {
  factory $TCPRosChunkCopyWith(
          TCPRosChunk value, $Res Function(TCPRosChunk) then) =
      _$TCPRosChunkCopyWithImpl<$Res>;
  $Res call(
      {Uint8List buffer, bool serviceResponse, bool serviceResponseSuccess});
}

class _$TCPRosChunkCopyWithImpl<$Res> implements $TCPRosChunkCopyWith<$Res> {
  _$TCPRosChunkCopyWithImpl(this._value, this._then);

  final TCPRosChunk _value;
  // ignore: unused_field
  final $Res Function(TCPRosChunk) _then;

  @override
  $Res call({
    Object buffer = freezed,
    Object serviceResponse = freezed,
    Object serviceResponseSuccess = freezed,
  }) {
    return _then(_value.copyWith(
      buffer: buffer == freezed ? _value.buffer : buffer as Uint8List,
      serviceResponse: serviceResponse == freezed
          ? _value.serviceResponse
          : serviceResponse as bool,
      serviceResponseSuccess: serviceResponseSuccess == freezed
          ? _value.serviceResponseSuccess
          : serviceResponseSuccess as bool,
    ));
  }
}

abstract class _$TcpRosChunkCopyWith<$Res>
    implements $TCPRosChunkCopyWith<$Res> {
  factory _$TcpRosChunkCopyWith(
          _TcpRosChunk value, $Res Function(_TcpRosChunk) then) =
      __$TcpRosChunkCopyWithImpl<$Res>;
  @override
  $Res call(
      {Uint8List buffer, bool serviceResponse, bool serviceResponseSuccess});
}

class __$TcpRosChunkCopyWithImpl<$Res> extends _$TCPRosChunkCopyWithImpl<$Res>
    implements _$TcpRosChunkCopyWith<$Res> {
  __$TcpRosChunkCopyWithImpl(
      _TcpRosChunk _value, $Res Function(_TcpRosChunk) _then)
      : super(_value, (v) => _then(v as _TcpRosChunk));

  @override
  _TcpRosChunk get _value => super._value as _TcpRosChunk;

  @override
  $Res call({
    Object buffer = freezed,
    Object serviceResponse = freezed,
    Object serviceResponseSuccess = freezed,
  }) {
    return _then(_TcpRosChunk(
      buffer == freezed ? _value.buffer : buffer as Uint8List,
      serviceResponse: serviceResponse == freezed
          ? _value.serviceResponse
          : serviceResponse as bool,
      serviceResponseSuccess: serviceResponseSuccess == freezed
          ? _value.serviceResponseSuccess
          : serviceResponseSuccess as bool,
    ));
  }
}

class _$_TcpRosChunk implements _TcpRosChunk {
  _$_TcpRosChunk(this.buffer,
      {this.serviceResponse = false, this.serviceResponseSuccess})
      : assert(buffer != null),
        assert(serviceResponse != null);

  @override
  final Uint8List buffer;
  @JsonKey(defaultValue: false)
  @override
  final bool serviceResponse;
  @override
  final bool serviceResponseSuccess;

  @override
  String toString() {
    return 'TCPRosChunk(buffer: $buffer, serviceResponse: $serviceResponse, serviceResponseSuccess: $serviceResponseSuccess)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is _TcpRosChunk &&
            (identical(other.buffer, buffer) ||
                const DeepCollectionEquality().equals(other.buffer, buffer)) &&
            (identical(other.serviceResponse, serviceResponse) ||
                const DeepCollectionEquality()
                    .equals(other.serviceResponse, serviceResponse)) &&
            (identical(other.serviceResponseSuccess, serviceResponseSuccess) ||
                const DeepCollectionEquality().equals(
                    other.serviceResponseSuccess, serviceResponseSuccess)));
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      const DeepCollectionEquality().hash(buffer) ^
      const DeepCollectionEquality().hash(serviceResponse) ^
      const DeepCollectionEquality().hash(serviceResponseSuccess);

  @override
  _$TcpRosChunkCopyWith<_TcpRosChunk> get copyWith =>
      __$TcpRosChunkCopyWithImpl<_TcpRosChunk>(this, _$identity);
}

abstract class _TcpRosChunk implements TCPRosChunk {
  factory _TcpRosChunk(Uint8List buffer,
      {bool serviceResponse, bool serviceResponseSuccess}) = _$_TcpRosChunk;

  @override
  Uint8List get buffer;
  @override
  bool get serviceResponse;
  @override
  bool get serviceResponseSuccess;
  @override
  _$TcpRosChunkCopyWith<_TcpRosChunk> get copyWith;
}
