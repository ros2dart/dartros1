import 'dart:async';
import 'package:actionlib_msgs/msgs.dart';
import 'package:dartx/dartx.dart';
import '../../msg_utils.dart';
import '../actionlib_server.dart';
import '../node_handle.dart';
import '../utils/log/logger.dart';
import 'goal_handle.dart';

class ActionServer<
        G extends RosMessage<G>,
        AG extends RosActionGoal<G, AG>,
        F extends RosMessage<F>,
        AF extends RosActionFeedback<F, AF>,
        R extends RosMessage<R>,
        AR extends RosActionResult<R, AR>>
    extends ActionLibServer<G, AG, F, AF, R, AR> {
  ActionServer(String actionServer, NodeHandle node,
      RosActionMessage<G, AG, F, AF, R, AR> actionClass)
      : super(actionServer, node, actionClass);
  final List<GoalHandle> _goalHandleList = [];
  final Map<String, GoalHandle> _goalHandleCache = {};
  RosTime _lastCancelStamp = RosTime.epoch();
  final _statusListTimeout = const RosTime(secs: 5, nsecs: 0);
  bool _started = false;
  Timer _statusFreqTimer;
  void Function(GoalHandle) goalHandle;
  void Function(GoalHandle) cancelHandle;
  final Map<String, int> _pubSeqs = {'result': 0, 'feedback': 0, 'status': 0};

  void start() {
    _started = true;
    publishStatus();
    const statusFreq = 5;
    if (statusFreq > 0) {
      _statusFreqTimer?.cancel();
      _statusFreqTimer = Timer.periodic(
        (1000 / statusFreq).milliseconds,
        (timer) {
          publishStatus();
        },
      );
    }
  }

  @override
  Future<void> shutdown() async {
    _statusFreqTimer?.cancel();
    _statusFreqTimer = null;
    await super.shutdown();
  }

  GoalHandle getGoalHandle(String id) => _goalHandleCache[id];

  @override
  void handleCancel(GoalID msg) {
    if (!_started) {
      return;
    }
    final id = msg.id;
    final stamp = msg.stamp;
    final isZero = stamp.isZeroTime();
    final shouldCancelEverything = id == '' && isZero;
    var idFound = false;
    for (final handle in _goalHandleList) {
      final handleStamp = handle.status.goal_id.stamp;
      if (shouldCancelEverything ||
          handle.id == id ||
          (!handleStamp.isZeroTime() && handleStamp < stamp)) {
        if (handle.id == id) {
          idFound = true;
        }
        if (handle.setCancelRequested()) {
          cancelHandle != null
              ? cancelHandle(handle)
              : log.dartros
                  .debug('Cancel Requested, but no cancel handle to call');
        }
      }
    }
    if (id != '' && !idFound) {
      final handle = GoalHandle<G, F, R>(msg, this, GoalStatus.RECALLING, null);
      _goalHandleList.add(handle);
      _goalHandleCache[handle.id] = handle;
    }
    if (stamp > _lastCancelStamp) {
      _lastCancelStamp = stamp;
    }
  }

  @override
  bool handleGoal(AG goal) {
    if (!_started) {
      return false;
    }
    final id = goal.goal_id.id;
    var handle = getGoalHandle(id);
    if (handle != null) {
      if (handle.statusId == GoalStatus.RECALLING) {
        handle.setCanceled(actionClass.actionResult());
      }
      handle.destructionTime = goal.goal_id.stamp;
      return false;
    }
    handle =
        GoalHandle<G, F, R>(goal.goal_id, this, GoalStatus.PENDING, goal.goal);
    _goalHandleList.add(handle);
    _goalHandleCache[handle.id] = handle;
    final goalStamp = goal.goal_id.stamp;
    if (goalStamp.isZeroTime() && goalStamp < _lastCancelStamp) {
      handle.setCanceled(actionClass.actionResult());
      return false;
    } else {
      goalHandle != null
          ? goalHandle(handle)
          : log.dartros.debug('Goal Handler is empty!');
    }
    return true;
  }

  void publishFeedback(GoalStatus status, F feedback) {
    final msg = actionClass.actionFeedback();
    msg.feedback = feedback;
    msg.status = status;
    msg.header.stamp = RosTime.now();
    msg.header.seq = _getAndIncrementSeq('feedback');
    publishActionFeedback(msg);
    publishStatus();
  }

  void publishStatus() {
    final msg = GoalStatusArray();
    msg.header.stamp = RosTime.now();
    msg.header.seq = _getAndIncrementSeq('status');
    final goalsToRemove = <GoalHandle>{};
    final now = RosTime.now();
    for (final handle in _goalHandleList) {
      msg.status_list.add(handle.status);
      final t = handle.destructionTime;
      if (!t.isZeroTime() && (t + _statusListTimeout) < now) {
        goalsToRemove.add(handle);
      }
    }
    for (final handle in goalsToRemove) {
      _goalHandleList.remove(handle);
      _goalHandleCache.remove(handle);
    }
    publishActionStatus(msg);
  }

  void publishResult(GoalStatus status, R result) {
    final msg = actionClass.actionResult();
    msg.status = status;
    msg.result = result;
    msg.header.stamp = RosTime.now();
    msg.header.seq = _getAndIncrementSeq('result');
    publishActionResult(msg);
    publishStatus();
  }

  int _getAndIncrementSeq(String type) => _pubSeqs[type]++;
}
