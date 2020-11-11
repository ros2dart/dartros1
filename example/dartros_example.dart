import 'package:dartros/dartros.dart' as dartros;

Future<void> main(List<String> args) async {
  final nh = await dartros.initNode('ros_node_1', args);
  await nh.getMasterUri();
  print(await nh.getParam('/foo'));
  print(await nh.setParam('/foo', 'new value'));
  print(await nh.getParam('/foo'));
}
