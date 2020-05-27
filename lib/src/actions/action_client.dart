import 'package:actionlib_msgs/src/msgs/GoalStatusArray.dart';

import '../../msg_utils.dart';
import '../actionlib_client.dart';
import '../node_handle.dart';
import 'goal_id_generator.dart';

class ActionClient<
        G extends RosMessage<G>,
        AG extends RosActionGoal<G, AG>,
        F extends RosMessage<F>,
        AF extends RosActionFeedback<F, AF>,
        R extends RosMessage<R>,
        AR extends RosActionResult<R, AR>,
        A extends RosActionMessage<G, AG, F, AF, R, AR>>
    extends ActionLibClient<G, AG, F, AF, R, AR, A> {
  bool _shutdown = false;
  ActionClient(
    String actionServer,
    NodeHandle node,
    A actionClass,
  ) : super(actionServer, node, actionClass);

  @override
  void handleFeedback(AF feedback) {}

  @override
  void handleResult(AR result) {}

  @override
  void handleStatus(GoalStatusArray status) {}

  @override
  Future<void> shutdown() async {
    if (_shutdown) {
      return;
    }
    _shutdown = true;
    await super.shutdown();
  }

  void sendGoal(G goal) {
    final ag = actionClass.actionGoal();
    final now = RosTime.now();
    ag.header.stamp = now;
    ag.goal_id.stamp = now;
    ag.goal_id.id = GoalIDGenerator.generateGoalID(now);
    ag.goal = goal;
    sendActionGoal(ag);
    // TODO more stuff here
  }

  void cancelAllGoals() {
    cancel(null, RosTime.epoch());
  }

  void cancelGoalsAtAndBeforeTime(RosTime stamp) {
    cancel(null, stamp);
  }
}
