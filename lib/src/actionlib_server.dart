import 'package:actionlib_msgs/msgs.dart';
import '../dartros.dart';
import 'node_handle.dart';
import 'utils/msg_utils.dart';

abstract class ActionLibServer<G extends RosMessage<G>, F extends RosMessage<F>,
    R extends RosMessage<R>> {
  final NodeHandle node;
  final G goalClass;
  final F feedbackClass;
  final R resultClass;
  Subscriber<G> _goalSub;
  Subscriber<GoalID> _cancelSub;
  Publisher<GoalStatusArray> _statusPub;
  Publisher<F> _feedbackPub;
  Publisher<R> _resultPub;
  int _goalCount = 0;
  final String actionServer;
  ActionLibServer(this.actionServer, this.node, this.goalClass,
      this.feedbackClass, this.resultClass) {
    _goalSub = node.subscribe(actionServer + '/goal', goalClass, _handleGoal,
        queueSize: 50);
    _cancelSub = node.subscribe(
        actionServer + '/cancel', actionlib_msgs.GoalID, _handleCancel,
        queueSize: 50);
    _statusPub = node.advertise(
        actionServer + '/status', actionlib_msgs.GoalStatusArray,
        queueSize: 50);
    _feedbackPub = node.advertise(actionServer + '/feedback', feedbackClass,
        queueSize: 50);
    _resultPub =
        node.advertise(actionServer + '/result', resultClass, queueSize: 50);
  }

  void _handleGoal(G goal);
  void _handleCancel(GoalID id);
  void publishResult(R result) {
    _resultPub.publish(result);
  }

  void publisherFeedback(F feedback) {
    _feedbackPub.publish(feedback);
  }

  void publishStatus(GoalStatusArray status) {
    _statusPub.publish(status);
  }

  String get type => goalClass.fullType;
  GoalID generateGoalID() {
    final now = RosTime.now();
    return GoalID(
        id: '${nh.nodeName}-${_goalCount++}-${now.secs}-${now.nsecs}',
        stamp: now);
  }

  Future<void> shutdown() {
    return Future.wait([
      _goalSub.shutdown(),
      _cancelSub.shutdown(),
      _statusPub.shutdown(),
      _feedbackPub.shutdown(),
      _resultPub.shutdown()
    ]);
  }
}
