import 'package:dartros/dartros.dart';
import 'package:dartx/dartx.dart';

import 'service_message_example.dart';

Future<void> main(List<String> args) async {
  final node = await initNode('test_node', args, anonymize: true);
  // ignore: unused_local_variable
  final sub = node.advertiseService<MoveBlockRequest, MoveBlockResponse>(
      '/move_bloc', MoveBlock.$prototype, (message) {
    print('Moved ${message.color} ${message.shape}');
    return MoveBlockResponse(wasSuccessful: false, outOfReach: true);
  });
  for (;;) {
    await Future.delayed(2.seconds);
  }
}
