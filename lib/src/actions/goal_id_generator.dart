import '../dartros.dart';
import '../utils/time_utils.dart';

const int int64MaxValue = identical(0, 0.0) ? 9007199254740991 : 9223372036854775807;

class GoalIDGenerator {
  static int GOAL_COUNT = 0;
  static String generateGoalID([RosTime now]) {
    now ??= RosTime.now();
    GOAL_COUNT++;
    if (GOAL_COUNT > int64MaxValue) {
      GOAL_COUNT = 0;
    }
    return '${nh.nodeName}-$GOAL_COUNT-${now.secs}.${now.nsecs}';
  }
}
