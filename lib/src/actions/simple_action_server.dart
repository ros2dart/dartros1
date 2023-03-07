import 'dart:async';

import 'package:actionlib_msgs/msgs.dart';
import 'package:dartros_msgutils/msg_utils.dart';

import 'package:dartx/dartx.dart';

import '../node_handle.dart';
import '../utils/log/logger.dart';
import 'action_server.dart';
import 'goal_handle.dart';

class SimpleActionServer<
        G extends RosMessage<G>,
        AG extends RosActionGoal<G, AG>,
        F extends RosMessage<F>,
        AF extends RosActionFeedback<F, AF>,
        R extends RosMessage<R>,
        AR extends RosActionResult<R, AR>>
    extends ActionServer<G, AG, F, AF, R, AR> {
  SimpleActionServer(
    String actionServer,
    NodeHandle node,
    RosActionMessage<G, AG, F, AF, R, AR> actionClass,
    this._executeCallback,
  ) : super(actionServer, node, actionClass);

  final Future<void> Function(G?) _executeCallback;
  GoalHandle? _currentGoal;
  GoalHandle? _nextGoal;
  bool _preemptRequested = false;
  bool _newGoalPreemptRequest = false;
  Timer? _executeLoopTimer;
  bool _shutdown = false;

  @override
  void start() {
    super.start();
    _runExecuteLoop();
  }

  bool get isActive {
    if (_currentGoal != null) {
      final status = _currentGoal!.statusId;
      return status == GoalStatus.ACTIVE || status == GoalStatus.PREEMPTING;
    }
    return false;
  }

  bool get isNewGoalAvailable => _nextGoal != null;

  bool get isPreemptRequested => _preemptRequested;

  @override
  Future<void> shutdown() async {
    _shutdown = true;
    _currentGoal = null;
    _nextGoal = null;
    _executeLoopTimer?.cancel();
    await super.shutdown();
  }

  G? acceptNewGoal() {
    if (_nextGoal == null) {
      log.dartros.error(
          'Attempting to accept the next goal when a new goal is not available');
      return null;
    }

    if (isActive) {
      final result = actionClass.result();

      _currentGoal!.setCanceled(result,
          text:
              'This goal was canceled because another goal was received by the simple action server');
    }

    _currentGoal = _nextGoal;
    _nextGoal = null;

    _preemptRequested = _newGoalPreemptRequest;
    _newGoalPreemptRequest = false;

    _currentGoal!.setAccepted(
        text: 'This goal has been accepted by the simple action server');

    return _currentGoal!.goal as G?;
  }

  void publishFeedbackForGoal(F feedback) {
    _currentGoal?.publishFeedback(feedback);
  }

  void setAborted(R? result, String text) {
    _currentGoal?.setAborted(result ?? actionClass.result(), text: text);
  }

  void setPreempted(R? result, String text) {
    _currentGoal?.setCanceled(result ?? actionClass.result(), text: text);
  }

  void setSucceeded(R result, String text) {
    _currentGoal!.setSucceeded(result, text: text);
  }

  @override
  void goalHandle(GoalHandle gh) {
    final hasGoal = isActive;
    var acceptGoal = false;
    if (!hasGoal) {
      acceptGoal = true;
    } else {
      final stamp = _nextGoal != null
          ? _nextGoal!.goalId.stamp
          : _currentGoal!.goalId.stamp;
      final newStamp = gh.goalId.stamp;
      acceptGoal = stamp < newStamp;
    }

    if (acceptGoal) {
      if (_nextGoal != null) {
        final result = actionClass.result();
        _nextGoal!.setCanceled(result,
            text:
                'This goal was canceled because another goal was received by the simple action server');
      }

      _nextGoal = gh;
      _newGoalPreemptRequest = false;

      if (hasGoal) {
        _preemptRequested = true;
        // emit('preempt');
      }

      // emit('goal');
    } else {
      log.dartros.debug('Not accepting new goal');
    }
  }

  @override
  void cancelHandle(GoalHandle gh) {
    if (_currentGoal != null && _currentGoal!.id == gh.id) {
      _preemptRequested = true;
      // emit('preempt');
    } else if (_nextGoal != null && _nextGoal!.id == gh.id) {
      _newGoalPreemptRequest = true;
    }
  }

  void _runExecuteLoop([int timeoutMs = 100]) {
    _executeLoopTimer = Timer.periodic(timeoutMs.milliseconds, (t) async {
      if (_shutdown) {
        t.cancel();
        return;
      }
      log.dartros.infoThrottled(1000, 'execute loop');
      if (isActive) {
        return;
        // log.dartros.error('Should never reach this code with an active goal!');
      } else if (isNewGoalAvailable) {
        final goal = acceptNewGoal();
        await _executeCallback(goal);
        if (isActive) {
          // TODO: Fix this
          log.dartros.warn(
              '''Your executeCallback did not set the goal to a terminate status,
              This is a bug in your ActionServer implementation. Fix your code!,
              For now, the ActionServer will set this goal to aborted''');

          setAborted(actionClass.result(),
              'This goal was aborted by the simple action server. The user should have set a terminal status on this goal and did not');
        }
      }
    });
  }
}
