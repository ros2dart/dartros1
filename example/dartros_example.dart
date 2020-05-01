import 'package:dartros/dartros.dart';

void main() async {
  final server = ROSXMLRPCServer();
  server.printRosServerInfo();
  print(await server.getParam('/foo'));
  print(await server.setParam('/foo', 'value'));
  print((await server.getStringParam('/foo')).value);
}
