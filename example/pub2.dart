import 'package:dartros/dartros.dart';
import 'package:dartx/dartx.dart';
import 'package:std_msgs/msgs.dart';

Future<void> main(List<String> args) async {
  final nh =
      await initNode('test_node', args, rosMasterUri: 'http://localhost:6001');
  final str_msg = StringMessage(data: 'hello');
  final pub = nh.advertise<StringMessage>('/chatter', StringMessage.$prototype);
  for (;;) {
    pub.publish(str_msg, 1);
    await Future.delayed(2.seconds);
  }
}
