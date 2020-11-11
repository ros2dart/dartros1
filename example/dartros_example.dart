import 'package:dartros/dartros.dart' as dartros;

Future<void> main(List<String> args) async {
  final nh = await dartros.initNode('ros_node_1', args);
  await nh.getMasterUri();
  await nh.setParam('/foo', 'value');
  var value = await nh.getParam('/foo');
  assert(value == 'value');
  print(value);

  print(await nh.setParam('/foo', 'new value'));
  value = await nh.getParam('/foo');
  assert(value == 'new value');
  print(value);
}
