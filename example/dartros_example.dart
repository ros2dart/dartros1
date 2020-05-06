import 'package:dartros/dartros.dart';

void main() async {
  final server = Node('ros_node_1');
  await server.printRosServerInfo();
  print(await server.getParam('/foo'));
  print(await server.setParam('/foo', 'value'));
  print(await server.getParam('/foo'));
}
