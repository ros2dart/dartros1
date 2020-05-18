import 'dart:convert';

import 'package:buffer/buffer.dart';
import 'time_utils.dart';
export 'time_utils.dart';

abstract class RosMessage<T> implements Function {
  String get fullType;
  String get messageDefinition;
  String get md5sum;
  T deserialize(ByteDataReader reader);
}

abstract class RosServiceMessage<C extends RosMessage<C>,
    R extends RosMessage<R>> {
  C get request;
  R get response;
  String get md5sum;
  String get fullType;
}

extension LenInBytes on String {
  int get lenInBytes => utf8.encode(this).length;
}

extension ByteDataReaderRosDeserializers on ByteDataReader {
  String readString() {
    final len = readUint32();
    return utf8.decode(read(len));
  }

  RosTime readTime() {
    final secs = readUint32();
    final nsecs = readUint32();
    return RosTime(secs: secs, nsecs: nsecs);
  }

  List<T> readArray<T>(T Function() func, {int arrayLen}) {
    if (arrayLen == null || arrayLen < 0) {
      arrayLen = readUint32();
    }
    return List.generate(arrayLen, (_) => func());
  }
}

extension ByteDataReaderRosSerializers on ByteDataWriter {
  void writeString(String value) {
    final list = utf8.encode(value);
    writeUint32(list.length);
    write(list);
  }

  void writeTime(RosTime time) {
    writeUint32(time.secs);
    writeUint32(time.nsecs);
  }

  void writeArray<T>(List<T> array, void Function(T) func, {int specArrayLen}) {
    final arrayLen = array.length;
    if (specArrayLen == null || specArrayLen < 0) {
      writeUint32(arrayLen);
    }
    for (final elem in array) {
      func(elem);
    }
  }
}
