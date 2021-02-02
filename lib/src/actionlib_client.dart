import 'package:actionlib_msgs/msgs.dart';
import 'package:dartros_msgutils/msg_utils.dart';
import 'package:dartx/dartx.dart';
import '../dartros.dart';
import 'actions/goal_id_generator.dart';
import 'node_handle.dart';

abstract class ActionLibClient<
    G extends RosMessage<G>,
    AG extends RosActionGoal<G, AG>,
    F extends RosMessage<F>,
    AF extends RosActionFeedback<F, AF>,
    R extends RosMessage<R>,
    AR extends RosActionResult<R, AR>> {
  ActionLibClient(this.actionServer, this.node, this.actionClass) {
    _goalPub = node.advertise<AG>('$actionServer/goal', actionClass.actionGoal,
        queueSize: 10, latching: false);
    _cancelPub = node.advertise<GoalID>(
        '$actionServer/cancel', GoalID.$prototype,
        queueSize: 10, latching: false);
    _statusSub = node.subscribe(
        '$actionServer/status', GoalStatusArray.$prototype, _handleStatus,
        queueSize: 1);
    _feedbackSub = node.subscribe(
        '$actionServer/feedback', actionClass.actionFeedback, handleFeedback,
        queueSize: 1);
    _resultSub = node.subscribe(
        '$actionServer/result', actionClass.actionResult, handleResult,
        queueSize: 1);
  }
  final RosActionMessage<G, AG, F, AF, R, AR> actionClass;
  late final Publisher<AG> _goalPub;
  late final Publisher<GoalID> _cancelPub;
  late final Subscriber<GoalStatusArray> _statusSub;
  late final Subscriber<AF> _feedbackSub;
  late final Subscriber<AR> _resultSub;
  NodeHandle node;
  final String actionServer;
  bool hasStatus = false;

  String get type => actionClass.fullType;
  void cancel(String? id, [RosTime? stamp]) {
    stamp ??= RosTime.now();
    final cancelGoal = GoalID(stamp: stamp);
    cancelGoal.id = id ?? cancelGoal.id;
    _cancelPub.publish(cancelGoal);
  }

  void sendActionGoal(AG goal) {
    _goalPub.publish(goal);
  }

  void _handleStatus(GoalStatusArray status) {
    hasStatus = true;
    handleStatus(status);
  }

  void handleStatus(GoalStatusArray status);
  void handleResult(AR result);
  void handleFeedback(AF feedback);

  Future<void> shutdown() => Future.wait([
        _goalPub.shutdown(),
        _cancelPub.shutdown(),
        _statusSub.shutdown(),
        _feedbackSub.shutdown(),
        _resultSub.shutdown()
      ]);

  bool get isServerConnected =>
      hasStatus &&
      _goalPub.numSubscribers > 0 &&
      _cancelPub.numSubscribers > 0 &&
      _statusSub.numPublishers > 0 &&
      _feedbackSub.numPublishers > 0 &&
      _resultSub.numPublishers > 0;

  Future<bool> waitForActionServerToStart([int timeoutMs = 0]) async {
    if (isServerConnected) {
      return Future.value(true);
    } else {
      return _waitForActionServerToStart(timeoutMs, DateTime.now());
    }
  }

  Future<bool> _waitForActionServerToStart(
      int timeoutMs, DateTime start) async {
    while (timeoutMs > 0 && start + timeoutMs.milliseconds > DateTime.now()) {
      await Future.delayed(100.milliseconds);
      if (isServerConnected) {
        return true;
      }
    }
    return false;
  }

  String generateGoalID([RosTime? now]) => GoalIDGenerator.generateGoalID(now);
}
