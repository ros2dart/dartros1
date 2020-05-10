import 'dart:convert';

import 'package:buffer/buffer.dart';
import 'src/utils/time_utils.dart';
export 'src/utils/time_utils.dart';

extension ByteDataReaderRosDeserializers on ByteDataReader {
  String readString() {
    final len = readInt32();
    return utf8.decode(read(len));
  }

  RosTime readTime() {
    final secs = readInt32();
    final nsecs = readInt32();
    return RosTime(secs: secs, nsecs: nsecs);
  }

  List<T> readArray<T>(T Function() func, {int arrayLen}) {
    if (arrayLen == null || arrayLen < 0) {
      arrayLen = readInt32();
    }
    return List.generate(arrayLen, (_) => func());
  }
}

extension ByteDataReaderRosSerializers on ByteDataWriter {
  void writeString(String value) {
    final list = utf8.encode(value);
    writeInt32(list.length);
    write(list);
  }

  void writeTime(RosTime time) {
    writeInt32(time.secs);
    writeInt32(time.nsecs);
  }

  void writeArray<T>(List<T> array, void Function(T) func, {int specArrayLen}) {
    final arrayLen = array.length;
    if (specArrayLen == null || specArrayLen < 0) {
      writeInt32(arrayLen);
    }
    for (final elem in array) {
      func(elem);
    }
  }
}
