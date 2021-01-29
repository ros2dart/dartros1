import 'package:actionlib_msgs/msgs.dart';
import 'package:dartros/src/utils/log/logger.dart';
import 'package:dartx/dartx.dart';
import '../node_handle.dart';
import '../utils/msg_utils.dart';
import 'action_client.dart';
import 'client_goal_handle.dart';
import 'client_states.dart';

class SimpleActionClient<
        G extends RosMessage<G>,
        AG extends RosActionGoal<G, AG>,
        F extends RosMessage<F>,
        AF extends RosActionFeedback<F, AF>,
        R extends RosMessage<R>,
        AR extends RosActionResult<R, AR>>
    extends ActionClient<G, AG, F, AF, R, AR> {
  SimpleActionClient(String actionServer, NodeHandle node,
      RosActionMessage<G, AG, F, AF, R, AR> actionClass)
      : super(actionServer, node, actionClass);
  SimpleGoalState _state = SimpleGoalState.PENDING;
  ClientGoalHandle<G, AG, F, AF, R, AR> _handle;
  void Function(AF) _feedbackCallback;
  void Function() _activeCallback;
  void Function(SimpleGoalState, R) _doneCallback;

  Future<bool> waitForServer([int timeoutMs = 0]) =>
      waitForActionServerToStart(timeoutMs);

  void sendSimpleGoal(
      G goal,
      void Function(AF) feedbackCallback,
      void Function() activeCallback,
      void Function(SimpleGoalState, R) doneCallback) {
    if (_handle != null) {
      _handle.reset();
    }
    _state = SimpleGoalState.PENDING;
    _feedbackCallback = feedbackCallback;
    _activeCallback = activeCallback;
    _doneCallback = doneCallback;
    _handle = sendGoal(goal, _handleFeedback, _handleTransition);
  }

  Future<void> sendGoalAndWait(
      G goal,
      RosTime execTimeout,
      RosTime preemptTimeout,
      void Function(AF) feedbackCallback,
      void Function() activeCallback,
      void Function(SimpleGoalState, R) doneCallback) async {
    sendSimpleGoal(goal, feedbackCallback, activeCallback, doneCallback);

    final finished = await waitForResult(execTimeout);

    if (finished) {
      log.dartros.debug('Goal finished within specified timeout');
    } else {
      log.dartros.debug('Goal didn\'t finish within specified timeout');
      // it didn't finish in time, so we need to cancel it
      cancelGoal();

      // wait again and see if it finishes
      final finishSecondChance = await waitForResult(preemptTimeout);

      if (finishSecondChance) {
        log.dartros.debug('Preempt finished within specified timeout');
      } else {
        log.dartros.debug('Preempt didn\'t finish within specified timeout');
      }

      return state;
    }

    return state;
  }

  Future<bool> waitForResult(RosTime timeout) async {
    if (_handle == null || _handle.isExpired()) {
      log.dartros.error('Trying to waitForResult() when no goal is running');
      return false;
    }

    if (timeout < const RosTime(secs: 0, nsecs: 0)) {
      log.dartros
          .warn('Timeout [$timeout] is invalid - timeouts can\'t be negative');
    }

    if (timeout.isZeroTime()) {
      return _waitForResult(0);
    }
    // else
    return _waitForResult(timeout + RosTime.now());
  }

  Future<bool> _waitForResult(timeoutTime) async {
    const WAIT_TIME_MS = 10;

    final now = RosTime.now();
    if (timeoutTime < now) {
      return _state == SimpleGoalState.DONE;
    } else if (_state == SimpleGoalState.DONE) {
      return true;
    }
    // else
    return Future.delayed(
        WAIT_TIME_MS.milliseconds, () => _waitForResult(timeoutTime));
  }

  R getResult() {
    if (_handle == null || _handle.isExpired()) {
      log.dartros.error('Trying to getResult() when no goal is running.');
      return null;
    } else {
      return _handle.getResult();
    }
  }

  SimpleClientGoalState get state {
    if (_handle == null || _handle.isExpired()) {
      log.dartros.error(
          'Trying to getState() when no goal is running. You are incorrectly using SimpleActionClient');
      return SimpleClientGoalState.LOST;
    }

    final commState = _handle.getCommState();

    switch (commState) {
      case CommState.WAITING_FOR_GOAL_ACK:
      case CommState.PENDING:
      case CommState.RECALLING:
        return SimpleClientGoalState.PENDING;
      case CommState.ACTIVE:
      case CommState.PREEMPTING:
        return SimpleClientGoalState.ACTIVE;
      case CommState.DONE:
        final termState = _handle.getTerminalState();
        switch (termState) {
          case GoalStatus.RECALLED:
            return SimpleClientGoalState.RECALLED;
          case GoalStatus.REJECTED:
            return SimpleClientGoalState.REJECTED;
          case GoalStatus.PREEMPTED:
            return SimpleClientGoalState.PREEMPTED;
          case GoalStatus.ABORTED:
            return SimpleClientGoalState.ABORTED;
          case GoalStatus.SUCCEEDED:
            return SimpleClientGoalState.SUCCEEDED;
          case GoalStatus.LOST:
            return SimpleClientGoalState.LOST;
          default:
            break;
        }
        log.dartros.error('Unknown terminal state $termState');
        return SimpleClientGoalState.LOST;
      case CommState.WAITING_FOR_RESULT:
      case CommState.WAITING_FOR_CANCEL_ACK:
        switch (_state) {
          case SimpleGoalState.PENDING:
            return SimpleClientGoalState.PENDING;
          case SimpleGoalState.ACTIVE:
            return SimpleClientGoalState.ACTIVE;
          default:
            break;
        }
        log.dartros.error(
            'BUG: In WAITING_FOR_RESULT or WAITING_FOR_CANCEL_ACK, yet we are in SimpleGoalState DONE.');
        return SimpleClientGoalState.LOST;
      default:
        log.dartros.error('Error trying to interpret CommState - $commState');
        return SimpleClientGoalState.LOST;
    }
  }

  void cancelGoal() {
    if (_handle != null || _handle.isExpired()) {
      log.dartros.error('Trying to cancelGoal() when no goal is running');
    } else {
      _handle.cancel();
    }
  }

  void stopTrackingGoal() {
    if (_handle == null || _handle.isExpired()) {
      log.dartros.error('Trying to stopTrackingGoal() when no goal is running');
    } else {
      _handle.reset();
    }
  }

  void _handleTransition() {
    final commState = _handle.getCommState();

    switch (commState) {
      case CommState.WAITING_FOR_GOAL_ACK:
        log.dartros.error(
            'BUG: shouldn\'t ever get a transition callback for WAITING_FOR_GOAL_ACK');
        break;
      case CommState.PENDING:
        if (_state != SimpleGoalState.PENDING) {
          log.dartros.error(
              'BUG: Got a transition to CommState [$commState] when our SimpleGoalState is [$_state]');
        }
        break;
      case CommState.ACTIVE:
        switch (_state) {
          case SimpleGoalState.PENDING:
            _setSimpleState(SimpleGoalState.ACTIVE);

            if (_activeCallback != null) {
              _activeCallback();
            }
            break;
          case SimpleGoalState.ACTIVE:
            break;
          case SimpleGoalState.DONE:
            log.dartros.error(
                'BUG: Got a transition to CommState [$commState] when in SimpleGoalState [$_state]');
            break;
          default:
            log.dartros.error('Unknown SimpleGoalState $_state');
            break;
        }
        break;
      case CommState.WAITING_FOR_RESULT:
        break;
      case CommState.WAITING_FOR_CANCEL_ACK:
        break;
      case CommState.RECALLING:
        if (_state != SimpleGoalState.PENDING) {
          log.dartros.error(
              'BUG: Got a transition to CommState [$commState] when in SimpleGoalState [$_state]');
        }
        break;
      case CommState.PREEMPTING:
        switch (_state) {
          case SimpleGoalState.PENDING:
            _setSimpleState(SimpleGoalState.ACTIVE);
            if (_activeCallback != null) {
              _activeCallback();
            }
            break;
          case SimpleGoalState.ACTIVE:
            break;
          case SimpleGoalState.DONE:
            log.dartros.error(
              'BUG: Got a transition to CommState [$commState] when in SimpleGoalState [$_state]',
            );
            break;
          default:
            log.dartros.error('Unknown SimpleGoalState $_state');
            break;
        }
        break;
      case CommState.DONE:
        switch (_state) {
          case SimpleGoalState.PENDING:
          case SimpleGoalState.ACTIVE:
            _setSimpleState(SimpleGoalState.DONE);
            if (_doneCallback != null) {
              _doneCallback(_state, _handle.getResult());
            }
            break;
          case SimpleGoalState.DONE:
            log.dartros.error('BUG: Got a second transition to DONE');
            break;
          default:
            log.dartros.error('Unknown SimpleGoalState $_state');
            break;
        }
        break;
      default:
        log.dartros.error('Unknown CommState received $commState');
    }
  }

  void _handleFeedback(AF feedback) {
    if (_feedbackCallback != null) {
      _feedbackCallback(feedback);
    }
  }

  void _setSimpleState(SimpleGoalState newState) {
    log.dartros
        .debug('Transitioning SimpleState from [$_state] to [$newState]');
    _state = newState;
  }
}
