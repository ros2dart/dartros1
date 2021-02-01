import 'package:dartros/dartros.dart';
import 'package:std_msgs/msgs.dart';
import 'package:dartx/dartx.dart';

Future<void> main(List<String> args) async {
  final node = await initNode('test_node', args, anonymize: true);
  // ignore: unused_local_variable
  final sub = node.subscribe<StringMessage>(
      '/chatter', StringMessage.$prototype, (message) {
    print('Got ${message.data}');
  });
  for (;;) {
    await Future.delayed(2.seconds);
  }
}
