import '../dartros.dart';
import '../utils/max_int.dart'
    if (dart.library.io) '../utils/max_int_io.dart'
    if (dart.library.html) '../utils/max_int_web.dart';
import '../utils/time_utils.dart';

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
