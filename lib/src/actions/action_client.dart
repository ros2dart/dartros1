import 'package:actionlib_msgs/src/msgs/GoalStatusArray.dart';

import '../../msg_utils.dart';
import '../actionlib_client.dart';
import '../node_handle.dart';

class ActionClient<G extends RosMessage<G>, F extends RosMessage<F>,
    R extends RosMessage<R>> extends ActionLibClient<G, F, R> {
  bool _shutdown = false;
  ActionClient(
    String actionServer,
    NodeHandle node,
    G goalClass,
    F feedbackClass,
    R resultClass,
  ) : super(actionServer, node, goalClass, feedbackClass, resultClass);

  @override
  void handleFeedback(F feedback) {}

  @override
  void handleResult(R feedback) {}

  @override
  void handleStatus(GoalStatusArray feedback) {}

  @override
  Future<void> shutdown() async {
    if (_shutdown) {
      return;
    }
    _shutdown = true;
    await super.shutdown();
  }

  // void sendGoal(G goal, void Function(F)) {}
}
