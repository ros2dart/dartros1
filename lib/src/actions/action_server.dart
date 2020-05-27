import 'package:actionlib_msgs/src/msgs/GoalID.dart';
import 'package:actionlib_msgs/src/msgs/GoalStatus.dart';
import 'package:actionlib_msgs/src/msgs/GoalStatusArray.dart';

import '../../msg_utils.dart';
import '../actionlib_client.dart';
import '../actionlib_server.dart';
import '../node_handle.dart';
import 'goal_id_generator.dart';

class ActionServer<
        G extends RosMessage<G>,
        AG extends RosActionGoal<G, AG>,
        F extends RosMessage<F>,
        AF extends RosActionFeedback<F, AF>,
        R extends RosMessage<R>,
        AR extends RosActionResult<R, AR>,
        A extends RosActionMessage<G, AG, F, AF, R, AR>>
    extends ActionLibServer<G, AG, F, AF, R, AR, A> {
  ActionServer(String actionServer, NodeHandle node, A actionClass)
      : super(actionServer, node, actionClass);

  @override
  void handleCancel(GoalID id) {
    // TODO: implement handleCancel
  }

  @override
  void handleGoal(AG goal) {
    // TODO: implement handleGoal
  }

  void publishFeedback(GoalStatus status, feedback) {}

  void publishStatus() {}

  void publishResult(GoalStatus status, result) {}
}
