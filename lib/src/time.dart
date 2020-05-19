export 'utils/time_utils.dart';
import 'utils/time_utils.dart';
import '../dartros.dart';

class Time {
  static RosTime simTime = RosTime(secs: 0, nsecs: 0);
  static bool useSimTime = false;
  static Future<void> initializeRosTime() async {
    try {
      useSimTime = await nh.getParam('/use_sim_time');
      if (useSimTime) {
        // nh.subscribe('/clock', rosgraph_msgs.Clock, (msg) {}, throttleMs: -1);
      }
    } catch (e) {
      rethrow;
    }
  }
}
