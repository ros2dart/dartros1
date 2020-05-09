import 'dart:math';
import 'package:dartx/dartx.dart';

const NSEC_TO_SEC = 1e-9;
const USEC_TO_SEC = 1e-6;
const MSEC_TO_SEC = 1e-3;

class RosTime {
  final int secs;
  final int nsecs;
  const RosTime({this.secs = 0, this.nsecs = 0});

  factory RosTime.epoch() {
    return RosTime();
  }
  factory RosTime.now() {
    return RosTime.fromDateTime(DateTime.now());
  }
  factory RosTime.fromDateTime(DateTime dateTime) {
    return RosTime(
        secs: (dateTime.millisecondsSinceEpoch * MSEC_TO_SEC).toInt(),
        nsecs: dateTime.microsecondsSinceEpoch % 1000000 * 1000);
  }

  DateTime toDateTime() {
    return DateTime.fromMillisecondsSinceEpoch(
        secs * 1000 + (nsecs * USEC_TO_SEC).floor());
  }

  bool isZeroTime() {
    return secs == 0 && nsecs == 0;
  }

  int toSeconds() {
    return secs + (nsecs * NSEC_TO_SEC).toInt();
  }
}
