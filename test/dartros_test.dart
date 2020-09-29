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
      final sub = await Process.start('rostopic', ['echo', 'chatter']);
      final subStream = sub.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();
      final nh = await initNode('my_node', []);
      final chatter =
          nh.advertise<StringMessage>('chatter', std_msgs.StringMessage);
      await Future.delayed(const Duration(seconds: 1));
      chatter.publish(StringMessage(data: 'message'), 1);
      await expectLater(subStream, emits('data: "message"'));
      sub.kill();
    });
  });

  group('Subscriber Tests', () {
    test('Subscriber Works', () async {
      final pub = await Process.start(
          'rostopic', ['pub', '/hello', 'std_msgs/String', "data: 'hi'"]);
      final nh = await initNode('my_node', []);
      final chatter =
          nh.subscribe<StringMessage>('hello', std_msgs.StringMessage, (_) {});
      final subStream =
          chatter.messageStream.asBroadcastStream().map((s) => s.data);
      await expectLater(subStream, emits('hi'));
      pub.kill();
    });
  });
}
