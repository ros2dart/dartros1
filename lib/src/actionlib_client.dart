import 'package:actionlib_msgs/msgs.dart';

import '../dartros.dart';
import 'node_handle.dart';
import 'utils/msg_utils.dart';

abstract class ActionLibClient<G extends RosMessage<G>, F extends RosMessage<F>,
    R extends RosMessage<R>> {
  final G goalClass;
  final F feedbackClass;
  final R resultClass;
  Publisher<G> _goalPub;
  Publisher<GoalID> _cancelPub;
  Subscriber<GoalStatusArray> _statusSub;
  Subscriber<F> _feedbackSub;
  Subscriber<R> _resultSub;
  NodeHandle node;
  final String actionServer;
  ActionLibClient(this.actionServer, this.node, this.goalClass,
      this.feedbackClass, this.resultClass) {
    _goalPub = node.advertise(actionServer + '/goal', goalClass,
        queueSize: 10, latching: false);
    _cancelPub = node.advertise(actionServer + '/cancel', actionlib_msgs.GoalID,
        queueSize: 10, latching: false);
    _statusSub = node.subscribe(
        actionServer + '/status', actionlib_msgs.GoalStatusArray, _handleStatus,
        queueSize: 1);
    _feedbackSub = node.subscribe(
        actionServer + '/feedback', feedbackClass, _handleFeedback,
        queueSize: 1);
    _resultSub = node.subscribe(
        actionServer + '/result', resultClass, _handleResult,
        queueSize: 1);
  }
  String get type => goalClass.fullType;
  void cancel(String id, [RosTime stamp]) {
    stamp ??= RosTime.now();
    final cancelGoal = GoalID(stamp: stamp);
    cancelGoal.id = id ?? cancelGoal.id;
    _cancelPub.publish(cancelGoal);
  }

  void sendGoal(G goal) {
    _goalPub.publish(goal);
  }

  void _handleStatus(GoalStatusArray status);
  void _handleResult(R result);
  void _handleFeedback(F feedback);

  Future<void> waitForActionServerToStart(int timeoutMs) {}
}
