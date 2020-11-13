import 'package:dartros/dartros.dart';
import 'package:dartx/dartx.dart';
import 'package:sensor_msgs/msgs.dart';

Future<void> main(List<String> args) async {
  //TODO: Change to node handle
  final node = await initNode('test_node', args);
  final img_msg = Image(
      header: null,
      height: 600,
      width: 1024,
      encoding: 'rgba8',
      is_bigendian: 0,
      step: 1024 * 4,
      data: List.generate(600 * 1024 * 4, (_) => 255));
  final pub = node.advertise<Image>('/robot/head_display', Image.$prototype);
  await Future.delayed(2.seconds);
  for (;;) {
    pub.publish(img_msg, 1);
    await Future.delayed(2.seconds);
  }
}
