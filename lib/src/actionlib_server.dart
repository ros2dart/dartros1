// import 'package:actionlib_msgs/actionlib_msgs.dart';
import '../dartros.dart';
import 'node_handle.dart';
import 'utils/msg_utils.dart';

class ActionLibServer<G extends RosMessage<G>, F extends RosMessage<F>,
    R extends RosMessage<R>> {
  final NodeHandle node;
  final G goalClass;
  final F feedbackClass;
  final R resultClass;
  Subscriber<G> _goalSub;
  // Subscriber<Cancel> _cancelSub;
  ActionLibServer(
      this.node, this.goalClass, this.feedbackClass, this.resultClass) {}
}
