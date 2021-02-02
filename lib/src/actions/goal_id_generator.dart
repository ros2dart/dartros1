import 'package:dartros_msgutils/msg_utils.dart';

import '../dartros.dart';

const int int64MaxValue = 9223372036854775807;

class GoalIDGenerator {
  static int GOAL_COUNT = 0;
  static String generateGoalID([RosTime? now]) {
    now ??= RosTime.now();
    GOAL_COUNT++;
    if (GOAL_COUNT > int64MaxValue) {
      GOAL_COUNT = 0;
    }
    return '${nh.nodeName}-$GOAL_COUNT-${now.secs}.${now.nsecs}';
  }
}
