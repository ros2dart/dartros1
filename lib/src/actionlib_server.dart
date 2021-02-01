import 'package:actionlib_msgs/msgs.dart';
import '../dartros.dart';
import 'node_handle.dart';
import 'utils/msg_utils.dart';

abstract class ActionLibServer<
    G extends RosMessage<G>,
    AG extends RosActionGoal<G, AG>,
    F extends RosMessage<F>,
    AF extends RosActionFeedback<F, AF>,
    R extends RosMessage<R>,
    AR extends RosActionResult<R, AR>> {
  ActionLibServer(this.actionServer, this.node, this.actionClass) {
    _goalSub = node.subscribe(
        '$actionServer/goal', actionClass.actionGoal, handleGoal,
        queueSize: 50);
    _cancelSub = node.subscribe(
        '$actionServer/cancel', GoalID.$prototype, handleCancel,
        queueSize: 50);
    _statusPub = node.advertise(
        '$actionServer/status', GoalStatusArray.$prototype,
        queueSize: 50);
    _feedbackPub = node.advertise(
        '$actionServer/feedback', actionClass.actionFeedback,
        queueSize: 50);
    _resultPub = node.advertise(
        '$actionServer/result', actionClass.actionResult,
        queueSize: 50);
  }
  final NodeHandle node;
  final RosActionMessage<G, AG, F, AF, R, AR> actionClass;
  late Subscriber<AG> _goalSub;
  late Subscriber<GoalID> _cancelSub;
  late Publisher<GoalStatusArray> _statusPub;
  late Publisher<AF> _feedbackPub;
  late Publisher<AR> _resultPub;
  int _goalCount = 0;
  final String actionServer;

  bool handleGoal(AG goal);
  void handleCancel(GoalID goalID);
  void publishActionResult(AR result) {
    _resultPub.publish(result);
  }

  void publishActionFeedback(AF feedback) {
    _feedbackPub.publish(feedback);
  }

  void publishActionStatus(GoalStatusArray status) {
    _statusPub.publish(status);
  }

  String get type => actionClass.fullType;
  GoalID generateGoalID() {
    final now = RosTime.now();
    return GoalID(
        id: '${nh.nodeName}-${_goalCount++}-${now.secs}.${now.nsecs}',
        stamp: now);
  }

  Future<void> shutdown() => Future.wait([
        _goalSub.shutdown(),
        _cancelSub.shutdown(),
        _statusPub.shutdown(),
        _feedbackPub.shutdown(),
        _resultPub.shutdown()
      ]);
}
