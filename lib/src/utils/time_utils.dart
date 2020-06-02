import 'package:dartx/dartx.dart';

const NSEC_TO_SEC = 1e-9;
const USEC_TO_SEC = 1e-6;
const MSEC_TO_SEC = 1e-3;

class RosTime {
  const RosTime({this.secs = 0, this.nsecs = 0});
  factory RosTime.epoch() => const RosTime();
  factory RosTime.now() => RosTime.fromDateTime(DateTime.now());
  factory RosTime.fromDateTime(DateTime dateTime) => RosTime(
      secs: (dateTime.millisecondsSinceEpoch * MSEC_TO_SEC).toInt(),
      nsecs: dateTime.microsecondsSinceEpoch % 1000000 * 1000);

  final int secs;
  final int nsecs;

  DateTime toDateTime() => DateTime.fromMillisecondsSinceEpoch(
      secs * 1000 + (nsecs * USEC_TO_SEC).floor());

  bool isZeroTime() => secs == 0 && nsecs == 0;

  int toSeconds() => secs + (nsecs * NSEC_TO_SEC).toInt();

  bool operator <(RosTime other) => toDateTime() < other.toDateTime();

  bool operator <=(RosTime other) => toDateTime() <= other.toDateTime();

  bool operator >(RosTime other) => toDateTime() > other.toDateTime();

  bool operator >=(RosTime other) => toDateTime() >= other.toDateTime();

  RosTime operator +(RosTime other) => RosTime.fromDateTime(toDateTime() +
      Duration(seconds: other.secs, microseconds: other.nsecs ~/ 1000));
}
