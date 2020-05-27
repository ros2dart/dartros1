import 'package:actionlib_msgs/msgs.dart';
import '../utils/log/logger.dart';

import '../../msg_utils.dart';
import 'action_server.dart';

class GoalHandle<
    G extends RosMessage<G>,
    AG extends RosActionGoal<G, AG>,
    F extends RosMessage<F>,
    AF extends RosActionFeedback<F, AF>,
    R extends RosMessage<R>,
    AR extends RosActionResult<R, AR>,
    A extends RosActionMessage<G, AG, F, AF, R, AR>> {
  final GoalID id;
  final G goal;
  GoalStatus _status;
  GoalStatus get status => _status;
  final ActionServer server;
  RosTime _destructionTime = RosTime.epoch();
  GoalHandle(GoalID id, this.server, int status, this.goal)
      : id = id ?? server.generateGoalID,
        _status = GoalStatus(status: status ?? GoalStatus.PENDING, goal_id: id);
  int get statusId => status.status;
  GoalID get goalId => status.goal_id;
  void publishFeedback(F feedback) {
    server.publishFeedback(status, feedback);
  }

  _setStatus(int s, [String text]) {
    _status.status = s;
    if (text != null) {
      _status.text = text;
    }
    if (_isTerminalState()) {
      _destructionTime = RosTime.now();
    }
    server.publishStatus();
  }

  void _publishResult(R result) {
    server.publishResult(status, result);
  }

  void setCanceled(R result, {String text = ''}) {
    switch (statusId) {
      case GoalStatus.PENDING:
      case GoalStatus.RECALLING:
        _setStatus(GoalStatus.RECALLED, text);
        _publishResult(result);
        break;
      case GoalStatus.ACTIVE:
      case GoalStatus.PREEMPTING:
        _setStatus(GoalStatus.PREEMPTED, text);
        _publishResult(result);
        break;
      default:
        _logInvalidTransition('setCancelled', statusId);
        break;
    }
  }

  void setRejected(R result, {String text = ''}) {
    switch (statusId) {
      case GoalStatus.PENDING:
      case GoalStatus.RECALLING:
        _setStatus(GoalStatus.REJECTED, text);
        _publishResult(result);
        break;
      default:
        _logInvalidTransition('setRejected', statusId);
        break;
    }
  }

  void setAccepted({String text = ''}) {
    switch (statusId) {
      case GoalStatus.PENDING:
        _setStatus(GoalStatus.ACTIVE, text);
        break;
      case GoalStatus.RECALLING:
        _setStatus(GoalStatus.PREEMPTING, text);
        break;
      default:
        _logInvalidTransition('setAccepted', statusId);
        break;
    }
  }

  void setAborted(R result, {String text = ''}) {
    switch (statusId) {
      case GoalStatus.PREEMPTING:
      case GoalStatus.ACTIVE:
        _setStatus(GoalStatus.ABORTED, text);
        _publishResult(result);
        break;
      default:
        _logInvalidTransition('setAborted', statusId);
        break;
    }
  }

  void setSucceeded(R result, {String text = ''}) {
    switch (statusId) {
      case GoalStatus.PREEMPTING:
      case GoalStatus.ACTIVE:
        _setStatus(GoalStatus.SUCCEEDED, text);
        _publishResult(result);
        break;
      default:
        _logInvalidTransition('setSucceeded', statusId);
        break;
    }
  }

  bool setCancelRequested() {
    switch (statusId) {
      case GoalStatus.PENDING:
        _setStatus(GoalStatus.RECALLING);
        return true;
      case GoalStatus.ACTIVE:
        _setStatus(GoalStatus.PREEMPTING);
        return true;
      default:
        _logInvalidTransition('setCancelRequested', statusId);
        return false;
    }
  }

  bool _isTerminalState() {
    return [
      GoalStatus.REJECTED,
      GoalStatus.RECALLED,
      GoalStatus.PREEMPTED,
      GoalStatus.ABORTED,
      GoalStatus.SUCCEEDED
    ].contains(statusId);
  }

  void _logInvalidTransition(String s, int status) {
    log.dartros.warn('Unable to $s from status $status for goal $id');
  }
}
