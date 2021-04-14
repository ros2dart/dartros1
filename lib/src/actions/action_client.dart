import 'package:actionlib_msgs/msgs.dart';
import 'package:dartros/src/utils/log/logger.dart';
import 'package:dartros_msgutils/msg_utils.dart';

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
        AR extends RosActionResult<R, AR>>
    extends ActionLibClient<G, AG, F, AF, R, AR> {
  ActionClient(
    String actionServer,
    NodeHandle node,
    RosActionMessage<G, AG, F, AF, R, AR> actionClass,
  ) : super(actionServer, node, actionClass);

  bool _shutdown = false;
  final Map<String, ClientGoalHandle<G, AG, F, AF, R, AR>> _goalLookup = {};

  @override
  void handleFeedback(AF feedback) {
    // Call updateFeedback if goal still registered (feedback might be received
    // just after the result, in which case the goal is already deregistered).
    _goalLookup[feedback.status.goal_id.id]?.updateFeedback(feedback);
  }

  @override
  void handleResult(AR result) {
    final id = result.status.goal_id.id;
    final handle = _goalLookup[id];
    if (handle == null) {
      log.dartros.warn(
          'Received result for unknown goal. Do you have several action servers accepting the same goal?');
      return;
    }
    _goalLookup.remove(id);
    handle.updateResult(result);
  }

  @override
  void handleStatus(GoalStatusArray status) {
    for (final s in status.status_list) {
      // Call updateStatus if goal still registered (the goal is deregistered
      // when the result is received).
      _goalLookup[s.goal_id.id]?.updateStatus(s);
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

  ClientGoalHandle<G, AG, F, AF, R, AR> sendGoal(G goal,
      void Function(AF) feedbackCallback, void Function() transitionCallback) {
    final AG ag = actionClass.actionGoal();
    final now = RosTime.now();
    final idStr = GoalIDGenerator.generateGoalID(now);
    ag.header.stamp = now;
    ag.goal_id.stamp = now;
    ag.goal_id.id = idStr;
    ag.goal = goal;
    sendActionGoal(ag);
    final handle = ClientGoalHandle<G, AG, F, AF, R, AR>(
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
