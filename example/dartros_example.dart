import 'package:dartros/dartros.dart';

void main(List<String> args) async {
  final server = initNode('ros_node_1', args);
  await server.printRosServerInfo();
  print(await server.getParam('/foo'));
  print(await server.setParam('/foo', 'value'));
  print(await server.getParam('/foo'));
}
