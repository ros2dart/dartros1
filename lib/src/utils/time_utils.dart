import 'dart:math';
import 'package:dartx/dartx.dart';

const NSEC_TO_SEC = 1e-9;
const USEC_TO_SEC = 1e-6;
const MSEC_TO_SEC = 1e-3;

DateTime rosTimeToDate(Map<String, int> rosTime) {
  return DateTime.fromMillisecondsSinceEpoch(
      rosTime['secs'] * 1000 + (rosTime['nsecs'] * USEC_TO_SEC).floor());
}

Map<String, num> dateToRosTime(DateTime date) {
  return {
    'secs': date.millisecondsSinceEpoch * MSEC_TO_SEC,
    'nsecs': date.microsecondsSinceEpoch % 1000000 * 1000
  };
}
