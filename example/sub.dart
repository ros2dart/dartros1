import 'package:dartros/dartros.dart';
import 'string_message.dart';
import 'package:dartx/dartx.dart';

void main(List<String> args) async {
  //TODO: Change to node handle
  final node = await initNode('test_node', args, anonymize: true);
  final sub = node.subscribe<StringMessage>('/chatter', StringMessage.empty$,
      (message) {
    print('Got ${message.data}');
  });
  while (true) {
    await Future.delayed(2.seconds);
  }
}
