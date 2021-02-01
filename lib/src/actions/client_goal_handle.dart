import 'package:actionlib_msgs/msgs.dart';
import '../../msg_utils.dart';
import '../utils/log/logger.dart';

import 'action_client.dart';
import 'client_states.dart';

class ClientGoalHandle<
    G extends RosMessage<G>,
    AG extends RosActionGoal<G, AG>,
    F extends RosMessage<F>,
    AF extends RosActionFeedback<F, AF>,
    R extends RosMessage<R /*!*/ > /*!*/,
    AR extends RosActionResult<R, AR>> {
  ClientGoalHandle(
      this._goal, this._actionClient, this.feedback, this.transition)
      : _state = CommState.WAITING_FOR_GOAL_ACK {
    _goalStatus = null;
    _result = null;
  }

  CommState _state;
  bool _active = true;
  AR _result;
  final AG _goal;
  GoalStatus _goalStatus;
  GoalStatus get goalStatus => _goalStatus;
  final ActionClient _actionClient;
  void Function(AF) feedback;
  void Function() transition;

  void reset() {
    _active = false;
  }

  void resend() {
    if (!_active) {
      log.dartros.error('Trying to resend on an inactive ClientGoalHandle!');
    }

    _actionClient.sendActionGoal(_goal);
  }

  void cancel() {
    if (!_active) {
      log.dartros.error('Trying to cancel on an inactive ClientGoalHandle!');
    }

    switch (_state) {
      case CommState.WAITING_FOR_GOAL_ACK:
      case CommState.PENDING:
      case CommState.ACTIVE:
      case CommState.WAITING_FOR_CANCEL_ACK:
        break;
      case CommState.WAITING_FOR_RESULT:
      case CommState.RECALLING:
      case CommState.PREEMPTING:
      case CommState.DONE:
        log.dartros.debug(
            'Got a cancel request while in state [$_state], ignoring it');
        return;
      default:
        log.dartros.error('BUG: Unhandled CommState: $_state');
        return;
    }

    _actionClient.cancel(_goal.goal_id.id, RosTime.epoch());
    _transition(CommState.WAITING_FOR_CANCEL_ACK);
  }

  R getResult() {
    if (!_active) {
      log.dartros.error('Trying to getResult on an inactive ClientGoalHandle!');
    }
    return _result?.result;
  }

  int getTerminalState() {
    if (!_active) {
      log.dartros
          .error('Trying to getTerminalState on an inactive ClientGoalHandle!');
    }

    if (_state != CommState.DONE) {
      log.dartros.warn('Asking for terminal state when we\'re in $_state');
    }
    final gs = _goalStatus;

    if (gs != null) {
      switch (gs.status) {
        case GoalStatus.PENDING:
        case GoalStatus.ACTIVE:
        case GoalStatus.PREEMPTING:
        case GoalStatus.RECALLING:
          log.dartros.error(
              'Asking for terminal state, but latest goal status is ${gs.status}');
          return GoalStatus.LOST;
        case GoalStatus.PREEMPTED:
        case GoalStatus.SUCCEEDED:
        case GoalStatus.ABORTED:
        case GoalStatus.REJECTED:
        case GoalStatus.RECALLED:
        case GoalStatus.LOST:
          return gs.status;
        default:
          log.dartros.error('Unknown goal status: ${gs.status}');
          throw Exception('Unknown goal status: ${gs.status}');
      }
    }
    throw Exception('Goal status is null: $gs');
  }

  CommState getCommState() => _state;

  bool isExpired() => !_active;

  void updateResult(AR ar) {
    _goalStatus = ar.status;
    _result = ar;

    switch (_state) {
      case CommState.WAITING_FOR_GOAL_ACK:
      case CommState.PENDING:
      case CommState.ACTIVE:
      case CommState.WAITING_FOR_RESULT:
      case CommState.WAITING_FOR_CANCEL_ACK:
      case CommState.RECALLING:
      case CommState.PREEMPTING:
        updateStatus(ar.status);
        _transition(CommState.DONE);
        break;
      case CommState.DONE:
        log.dartros
            .error('Got a result when we were already in the DONE state');
        break;
      default:
        log.dartros.error('In a funny comm state: $_state');
    }
  }

  void updateStatus(GoalStatus/*?*/ status) {
    // it's apparently possible to receive old GoalStatus messages, even after
    // transitioning to a terminal state.
    if (_state == CommState.DONE) {
      return;
    }
    // else
    if (status != null) {
      _goalStatus = status;
    } else {
      // this goal wasn't included in the latest status message!
      // it may have been lost
      if (_state != CommState.WAITING_FOR_GOAL_ACK &&
          _state != CommState.WAITING_FOR_RESULT &&
          _state != CommState.DONE) {
        log.dartros.warn('Transitioning goal to LOST');
        _goalStatus.status = GoalStatus.LOST;
        _transition(CommState.DONE);
      }
      return;
    }

    switch (_state) {
      case CommState.WAITING_FOR_GOAL_ACK:
        switch (status.status) {
          case GoalStatus.PENDING:
            _transition(CommState.PENDING);
            break;
          case GoalStatus.ACTIVE:
            _transition(CommState.ACTIVE);
            break;
          case GoalStatus.PREEMPTED:
            _transition(CommState.ACTIVE);
            _transition(CommState.PREEMPTING);
            _transition(CommState.WAITING_FOR_RESULT);
            break;
          case GoalStatus.SUCCEEDED:
            _transition(CommState.ACTIVE);
            _transition(CommState.WAITING_FOR_RESULT);
            break;
          case GoalStatus.ABORTED:
            _transition(CommState.ACTIVE);
            _transition(CommState.WAITING_FOR_RESULT);
            break;
          case GoalStatus.REJECTED:
            _transition(CommState.PENDING);
            _transition(CommState.WAITING_FOR_RESULT);
            break;
          case GoalStatus.RECALLED:
            _transition(CommState.PENDING);
            _transition(CommState.WAITING_FOR_RESULT);
            break;
          case GoalStatus.PREEMPTING:
            _transition(CommState.ACTIVE);
            _transition(CommState.PREEMPTING);
            break;
          case GoalStatus.RECALLING:
            _transition(CommState.PENDING);
            _transition(CommState.RECALLING);
            break;
          default:
            log.dartros.error(
                'BUG: Got an unknown status from the ActionServer: status = ${status.status}');
            break;
        }
        break;
      case CommState.PENDING:
        switch (status.status) {
          case GoalStatus.PENDING:
            break;
          case GoalStatus.ACTIVE:
            _transition(CommState.ACTIVE);
            break;
          case GoalStatus.PREEMPTED:
            _transition(CommState.ACTIVE);
            _transition(CommState.PREEMPTING);
            _transition(CommState.WAITING_FOR_RESULT);
            break;
          case GoalStatus.SUCCEEDED:
            _transition(CommState.ACTIVE);
            _transition(CommState.WAITING_FOR_RESULT);
            break;
          case GoalStatus.ABORTED:
            _transition(CommState.ACTIVE);
            _transition(CommState.WAITING_FOR_RESULT);
            break;
          case GoalStatus.REJECTED:
            _transition(CommState.WAITING_FOR_RESULT);
            break;
          case GoalStatus.RECALLED:
            _transition(CommState.RECALLING);
            _transition(CommState.WAITING_FOR_RESULT);
            break;
          case GoalStatus.PREEMPTING:
            _transition(CommState.ACTIVE);
            _transition(CommState.PREEMPTING);
            break;
          case GoalStatus.RECALLING:
            _transition(CommState.RECALLING);
            break;
          default:
            log.dartros.error(
                'BUG: Got an unknown status from the ActionServer: status = ${status.status}');
            break;
        }
        break;
      case CommState.ACTIVE:
        switch (status.status) {
          case GoalStatus.PENDING:
            log.dartros.error('Invalid transition from ACTIVE to PENDING');
            break;
          case GoalStatus.REJECTED:
            log.dartros.error('Invalid transition from ACTIVE to REJECTED');
            break;
          case GoalStatus.RECALLED:
            log.dartros.error('Invalid transition from ACTIVE to RECALLED');
            break;
          case GoalStatus.RECALLING:
            log.dartros.error('Invalid transition from ACTIVE to RECALLING');
            break;
          case GoalStatus.ACTIVE:
            break;
          case GoalStatus.PREEMPTED:
            _transition(CommState.PREEMPTING);
            _transition(CommState.WAITING_FOR_RESULT);
            break;
          case GoalStatus.SUCCEEDED:
            _transition(CommState.WAITING_FOR_RESULT);
            break;
          case GoalStatus.ABORTED:
            _transition(CommState.WAITING_FOR_RESULT);
            break;
          case GoalStatus.PREEMPTING:
            _transition(CommState.PREEMPTING);
            break;
          default:
            log.dartros.error(
                'BUG: Got an unknown status from the ActionServer: status = ${status.status}');
            break;
        }
        break;
      case CommState.WAITING_FOR_RESULT:
        switch (status.status) {
          case GoalStatus.PENDING:
            log.dartros
                .error('Invalid transition from WAITING_FOR_RESULT to PENDING');
            break;
          case GoalStatus.PREEMPTING:
            log.dartros.error(
                'Invalid transition from WAITING_FOR_RESULT to PREEMPTING');
            break;
          case GoalStatus.RECALLING:
            log.dartros.error(
                'Invalid transition from WAITING_FOR_RESULT to RECALLING');
            break;
          case GoalStatus.ACTIVE:
          case GoalStatus.PREEMPTED:
          case GoalStatus.SUCCEEDED:
          case GoalStatus.ABORTED:
          case GoalStatus.REJECTED:
          case GoalStatus.RECALLED:
            break;
          default:
            log.dartros.error(
                'BUG: Got an unknown status from the ActionServer: status = ${status.status}');
            break;
        }
        break;
      case CommState.WAITING_FOR_CANCEL_ACK:
        switch (status.status) {
          case GoalStatus.PENDING:
          case GoalStatus.ACTIVE:
            break;
          case GoalStatus.PREEMPTED:
          case GoalStatus.SUCCEEDED:
          case GoalStatus.ABORTED:
            _transition(CommState.PREEMPTING);
            _transition(CommState.WAITING_FOR_RESULT);
            break;
          case GoalStatus.RECALLED:
            _transition(CommState.RECALLING);
            _transition(CommState.WAITING_FOR_RESULT);
            break;
          case GoalStatus.REJECTED:
            _transition(CommState.WAITING_FOR_RESULT);
            break;
          case GoalStatus.PREEMPTING:
            _transition(CommState.PREEMPTING);
            break;
          case GoalStatus.RECALLING:
            _transition(CommState.RECALLING);
            break;
          default:
            log.dartros.error(
                'BUG: Got an unknown status from the ActionServer: status = ${status.status}');
            break;
        }
        break;
      case CommState.RECALLING:
        switch (status.status) {
          case GoalStatus.PENDING:
            log.dartros.error('Invalid transition from RECALLING to PENDING');
            break;
          case GoalStatus.ACTIVE:
            log.dartros.error('Invalid transition from RECALLING to ACTIVE');
            break;
          case GoalStatus.PREEMPTED:
          case GoalStatus.SUCCEEDED:
          case GoalStatus.ABORTED:
            _transition(CommState.PREEMPTING);
            _transition(CommState.WAITING_FOR_RESULT);
            break;
          case GoalStatus.RECALLED:
            _transition(CommState.WAITING_FOR_RESULT);
            break;
          case GoalStatus.REJECTED:
            _transition(CommState.WAITING_FOR_RESULT);
            break;
          case GoalStatus.PREEMPTING:
            _transition(CommState.PREEMPTING);
            break;
          case GoalStatus.RECALLING:
            break;
          default:
            log.dartros.error(
                'BUG: Got an unknown status from the ActionServer: status = ${status.status}');
            break;
        }
        break;
      case CommState.PREEMPTING:
        switch (status.status) {
          case GoalStatus.PENDING:
            log.dartros.error('Invalid transition from PREEMPTING to PENDING');
            break;
          case GoalStatus.ACTIVE:
            log.dartros.error('Invalid transition from PREEMPTING to ACTIVE');
            break;
          case GoalStatus.REJECTED:
            log.dartros.error('Invalid transition from PREEMPTING to REJECTED');
            break;
          case GoalStatus.RECALLING:
            log.dartros
                .error('Invalid transition from PREEMPTING to RECALLING');
            break;
          case GoalStatus.RECALLED:
            log.dartros.error('Invalid transition from PREEMPTING to RECALLED');
            break;
          case GoalStatus.PREEMPTED:
          case GoalStatus.SUCCEEDED:
          case GoalStatus.ABORTED:
            _transition(CommState.WAITING_FOR_RESULT);
            break;
          case GoalStatus.PREEMPTING:
            break;
          default:
            log.dartros.error(
                'BUG: Got an unknown status from the ActionServer: status = ${status.status}');
            break;
        }
        break;
      case CommState.DONE:
        // I'm pretty sure we can never get here... but actionlib has it so I'm going to
        // follow suit.
        switch (status.status) {
          case GoalStatus.PENDING:
            log.dartros.error('Invalid transition from DONE to PENDING');
            break;
          case GoalStatus.ACTIVE:
            log.dartros.error('Invalid transition from DONE to ACTIVE');
            break;
          case GoalStatus.RECALLING:
            log.dartros.error('Invalid transition from DONE to RECALLING');
            break;
          case GoalStatus.PREEMPTING:
            log.dartros.error('Invalid transition from DONE to PREEMPTING');
            break;
          case GoalStatus.RECALLED:
          case GoalStatus.REJECTED:
          case GoalStatus.PREEMPTED:
          case GoalStatus.SUCCEEDED:
          case GoalStatus.ABORTED:
            break;
          default:
            log.dartros.error(
                'BUG: Got an unknown status from the ActionServer: status = ${status.status}');
            break;
        }
        break;
      default:
        log.dartros.error('In a funny comm state: $_state');
    }
  }

  void _transition(newState) {
    log.dartros.debug('Trying to transition to $newState');
    _state = newState;
    transition();
  }

  void updateFeedback(AF f) {
    feedback(f);
  }
}
