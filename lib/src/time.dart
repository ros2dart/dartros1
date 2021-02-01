import 'package:rosgraph_msgs/msgs.dart';
import '../dartros.dart';
import 'utils/log/logger.dart';
import 'utils/time_utils.dart';
export 'utils/time_utils.dart';

class Time {
  static RosTime simTime = const RosTime(secs: 0, nsecs: 0);
  static bool useSimTime = false;
  static Future<void> initializeRosTime() async {
    try {
      useSimTime =
          await nh.getParam<bool>('/use_sim_time', defaultValue: false);
      log.dartros.info('Sim time: $useSimTime');
      if (useSimTime) {
        nh.subscribe<Clock>(
          '/clock',
          Clock.$prototype,
          (msg) {
            simTime = msg.clock;
          },
          throttleMs: -1,
        );
      }
    } on Exception catch (e) {
      rethrow;
    }
  }

  static RosTime now() {
    if (useSimTime) {
      return simTime;
    } else {
      return RosTime.now();
    }
  }
}
