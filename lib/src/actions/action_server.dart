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
        R extends RosMessage<R /*!*/ > /*!*/,
        AR extends RosActionResult<R, AR>>
    extends ActionLibServer<G, AG, F, AF, R, AR> {
  ActionServer(
    String actionServer,
    NodeHandle node,
    RosActionMessage<G, AG, F, AF, R, AR> actionClass,
  ) : super(actionServer, node, actionClass);
  final List<GoalHandle<G, F, R>> _goalHandleList = [];
  final Map<String, GoalHandle<G, F, R>> _goalHandleCache = {};
  RosTime _lastCancelStamp = RosTime.epoch();
  final _statusListTimeout = const RosTime(secs: 5, nsecs: 0);
  bool _started = false;
  Timer _statusFreqTimer;
  void goalHandle(GoalHandle gh) {
    log.dartros.debug('Goal Handler is empty!');
    throw UnimplementedError('Goal Handler is empty!');
  }

  void cancelHandle(GoalHandle gh) {
    log.dartros.debug('Cancel Requested, but no cancel handle to call');
    throw UnimplementedError('Cancel Requested, but no cancel handle to call');
  }

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

  GoalHandle<G, F, R> getGoalHandle(String id) => _goalHandleCache[id];

  @override
  void handleCancel(GoalID goalID) {
    if (!_started) {
      return;
    }
    final id = goalID.id;
    final stamp = goalID.stamp;
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
          cancelHandle(handle);
        }
      }
    }
    if (id != '' && !idFound) {
      final handle =
          GoalHandle<G, F, R>(goalID, this, GoalStatus.RECALLING, null);
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
    final handle = getGoalHandle(id);
    if (handle != null) {
      if (handle.statusId == GoalStatus.RECALLING) {
        handle.setCanceled(actionClass.result());
      }
      handle.destructionTime = goal.goal_id.stamp;
      return false;
    }
    final newHandle =
        GoalHandle<G, F, R>(goal.goal_id, this, GoalStatus.PENDING, goal.goal);
    _goalHandleList.add(newHandle);
    _goalHandleCache[newHandle.id] = newHandle;
    final goalStamp = goal.goal_id.stamp;
    if (goalStamp.isZeroTime() && goalStamp < _lastCancelStamp) {
      newHandle.setCanceled(actionClass.result());
      return false;
    } else {
      goalHandle(newHandle);
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
