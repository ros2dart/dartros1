import 'dart:convert';
import 'dart:io';
import 'package:async/async.dart';
import 'package:dartros/dartros.dart';
import 'package:test/test.dart';
import 'package:dartx/dartx.dart';

import 'package:std_msgs/msgs.dart' hide Duration;
import 'helpers/python_runner.dart';

void main() {
  Process roscore;
  setUpAll(() async {
    roscore = await startRosCore();
    await Future.delayed(const Duration(seconds: 2));
  });
  tearDownAll(() async {
    roscore.kill();
  });
  group('Publisher Tests', () {
    test('Publisher Works', () async {
      final sub = await startPythonNode('sub.py');

      await Future.delayed(2.seconds);
      final subStream = sub.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();
      subStream.listen((m) => print(m));
      final nh = await initNode('my_node', []);
      final chatter =
          nh.advertise<StringMessage>('chatter', std_msgs.StringMessage);
      chatter.publish(StringMessage(data: 'message'));

      await Future.delayed(4.seconds);
      await expectLater(StreamQueue(subStream), emits('message'));
    });
  });
}
