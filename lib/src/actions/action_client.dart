import 'package:actionlib_msgs/msgs.dart';

import '../../msg_utils.dart';
import '../actionlib_client.dart';
import '../node_handle.dart';
import 'client_goal_handle.dart';
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
  ActionClient(
    String actionServer,
    NodeHandle node,
    A actionClass,
  ) : super(actionServer, node, actionClass);

  bool _shutdown = false;
  final Map<String, ClientGoalHandle<G, AG, F, AF, R, AR, A>> _goalLookup = {};

  @override
  void handleFeedback(AF feedback) {
    _goalLookup[feedback.status.goal_id.id].updateFeedback(feedback);
  }

  @override
  void handleResult(AR result) {
    final id = result.status.goal_id.id;
    final handle = _goalLookup[id];
    _goalLookup.remove(id);
    handle.updateResult(result);
  }

  @override
  void handleStatus(GoalStatusArray status) {
    for (final s in status.status_list) {
      _goalLookup[s.goal_id.id].updateStatus(s);
    }
  }

  @override
  Future<void> shutdown() async {
    if (_shutdown) {
      return;
    }
    _shutdown = true;
    await super.shutdown();
  }

  ClientGoalHandle<G, AG, F, AF, R, AR, A> sendGoal(G goal,
      void Function(AF) feedbackCallback, void Function() transitionCallback) {
    final ag = actionClass.actionGoal();
    final now = RosTime.now();
    final idStr = GoalIDGenerator.generateGoalID(now);
    ag.header.stamp = now;
    ag.goal_id.stamp = now;
    ag.goal_id.id = idStr;
    ag.goal = goal;
    sendActionGoal(ag);
    final handle = ClientGoalHandle<G, AG, F, AF, R, AR, A>(
        ag, this, feedbackCallback, transitionCallback);
    _goalLookup[idStr] = handle;
    return handle;
  }

  void cancelAllGoals() {
    cancel(null, RosTime.epoch());
  }

  void cancelGoalsAtAndBeforeTime(RosTime stamp) {
    cancel(null, stamp);
  }
}
