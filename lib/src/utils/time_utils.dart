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

Map<String, num> now() {
  return dateToRosTime(DateTime.now());
}

Map<String, num> epoch() {
  return {'secs': 0, 'nsecs': 0};
}

bool isZeroTime(Map<String, num> t) {
  return t['secs'] == 0 && t['nsecs'] == 0;
}

int toSeconds(Map<String, num> t) {
  return t['secs'] + t['nsecs'] * NSEC_TO_SEC;
}
