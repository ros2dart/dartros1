import 'dart:convert';
import 'dart:io';
import 'package:dartros/dartros.dart';
import 'package:test/test.dart';
import 'package:dartx/dartx.dart';

import 'package:std_msgs/msgs.dart' hide Duration;
import 'helpers/messages.dart';
import 'helpers/python_runner.dart';

void main() {
  Process roscore;
  setUpAll(() async {
    roscore = await startRosCore();
    await Future.delayed(2.seconds);
  });
  tearDownAll(() async {
    roscore.kill();
  });
  group('Publisher Tests', () {
    test('Publisher Works', () async {
      final sub = await Process.start('rostopic', ['echo', 'chatter'],
          runInShell: true);
      final subStream = sub.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();
      final nh = await initNode('my_node', []);
      final chatter =
          nh.advertise<StringMessage>('chatter', std_msgs.StringMessage);
      await Future.delayed(2.seconds);
      chatter.publish(StringMessage(data: 'message'), 1);
      await expectLater(subStream, emits('data: "message"'));
      sub.kill();
    });
  });

  group('Subscriber Tests', () {
    test('Subscriber Works', () async {
      final pub = await Process.start(
          'rostopic', ['pub', '/hello', 'std_msgs/String', "data: 'hi'"],
          runInShell: true);
      final nh = await initNode('my_node', []);
      final chatter =
          nh.subscribe<StringMessage>('hello', std_msgs.StringMessage, (_) {});
      final subStream =
          chatter.messageStream.asBroadcastStream().map((s) => s.data);
      await expectLater(subStream, emits('hi'));
      pub.kill();
    });
  });

  group('Service Tests', () {
    test('ServerClient Works', () async {
      final nh = await initNode('my_node', []);
      var first = true;
      final server = nh.advertiseService('/move_bloc', MoveBlock.empty$,
          (MoveBlockRequest req) {
        if (first) {
          expect(req.color, 0);
          expect(req.shape, 1);
          first = false;
          return MoveBlockResponse(wasSuccessful: false, outOfReach: true);
        }

        expect(req.color, 1);
        expect(req.shape, 2);
        return MoveBlockResponse(wasSuccessful: true, outOfReach: false);
      });
      final request = MoveBlockRequest(color: 0, shape: 1);
      final moveBloc =
          nh.serviceClient<MoveBlockRequest, MoveBlockResponse, MoveBlock>(
              '/move_bloc', MoveBlock.empty$,
              persist: true);

      var response = await moveBloc(request);
      expect(response.wasSuccessful, false);
      expect(response.outOfReach, true);
      response = await moveBloc(request
        ..color = 1
        ..shape = 2);
      expect(response.wasSuccessful, true);
      expect(response.outOfReach, false);
    });
  });
}
