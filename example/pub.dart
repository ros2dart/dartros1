import 'package:dartros/dartros.dart';
import 'package:dartx/dartx.dart';
import 'package:std_msgs/msgs.dart';

Future<void> main(List<String> args) async {
  final node = await initNode('test_node', args);
  final str_msg = StringMessage(data: 'hello');
  final pub =
      node.advertise<StringMessage>('/chatter', StringMessage.$prototype);
  for (;;) {
    pub.publish(str_msg, 1);
    await Future.delayed(2.seconds);
  }
}
