import 'package:dartros/dartros.dart';
import 'package:dartx/dartx.dart';

import 'service_message_example.dart';

Future<void> main(List<String> args) async {
  //TODO: Change to node handle
  final node = await initNode('test_node', args);
  final request = MoveBlockRequest(color: 0, shape: 1);
  final moveBloc =
      node.serviceClient('/move_bloc', MoveBlock.$prototype, persist: true);
  for (;;) {
    final response = await moveBloc(request);
    print(
        'Moving block ${request.color} ${request.shape} was successful: ${response.wasSuccessful}');
    await Future.delayed(2.seconds);
  }
}
