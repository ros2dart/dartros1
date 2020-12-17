import 'dart:convert';

import 'package:actionlib_msgs/msgs.dart';
import 'package:buffer/buffer.dart';
import 'package:std_msgs/msgs.dart';
import 'time_utils.dart';
export 'time_utils.dart';

abstract class RosMessage<T> implements Function {
  String get fullType;
  String get messageDefinition;
  String get md5sum;
  T deserialize(ByteDataReader reader);
  T call();
}

abstract class RosServiceMessage<C extends RosMessage<C>,
    R extends RosMessage<R>> {
  C get request;
  R get response;
  String get md5sum;
  String get fullType;
}

abstract class RosActionGoal<G extends RosMessage<G>,
    AG extends RosActionGoal<G, AG>> extends RosMessage<AG> {
  Header header;
  GoalID goal_id;
  G goal;
}

abstract class RosActionFeedback<F extends RosMessage<F>,
    AF extends RosActionFeedback<F, AF>> extends RosMessage<AF> {
  Header header;
  GoalStatus status;
  F feedback;
}

abstract class RosActionResult<R extends RosMessage<R>,
    AR extends RosActionResult<R, AR>> extends RosMessage<AR> {
  Header header;
  GoalStatus status;
  R result;
}

abstract class RosActionMessage<
    G extends RosMessage<G>,
    AG extends RosActionGoal<G, AG>,
    F extends RosMessage<F>,
    AF extends RosActionFeedback<F, AF>,
    R extends RosMessage<R>,
    AR extends RosActionResult<R, AR>> {
  AG get actionGoal;
  AF get actionFeedback;
  AR get actionResult;
  G get goal;
  F get feedback;
  R get result;
  String get md5sum;
  String get fullType;
}

extension LenInBytes on String {
  int get lenInBytes => utf8.encode(this).length;
}

extension ByteDataReaderRosDeserializers on ByteDataReader {
  String readString() {
    final len = readUint32();
    // ByteDataReader.read(0) throws if there is no byte to read
    return len > 0 ? utf8.decode(read(len)) : '';
  }

  RosTime readTime() {
    final secs = readUint32();
    final nsecs = readUint32();
    return RosTime(secs: secs, nsecs: nsecs);
  }

  List<T> readArray<T>(T Function() func, {int arrayLen}) {
    var len = arrayLen;
    if (len == null || len < 0) {
      len = readUint32();
    }
    return List.generate(len, (_) => func());
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
    array.forEach(func);
  }
}
