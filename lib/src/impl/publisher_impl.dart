import 'dart:io';

import 'package:buffer/buffer.dart';
import 'package:dartros/src/utils/tcpros_utils.dart';

import '../../msg_utils.dart';
import '../node.dart';
import '../utils/client_states.dart';

class PublisherImpl<T extends RosMessage> {
  final Node node;
  final String topic;
  final bool latching;
  final int queueSize;
  final bool tcpNoDelay;
  final int throttleMs;
  int count = 0;
  T lastSentMsg;
  final T messageClass;
  State _state = State.REGISTERING;
  //TODO:
  // logger
  // spinner?
  final Map<String, Socket> subClients = {};

  PublisherImpl(
    this.node,
    this.topic, {
    this.latching = false,
    this.tcpNoDelay = false,
    this.queueSize = 1,
    this.throttleMs = 0,
    this.messageClass,
  }) {
    _register();
  }

  String get type => messageClass.fullType;
  String get spinnerId => 'Publisher://$topic';
  int get numSubscribers => subClients.keys.length;
  List<String> get clientUris => subClients.keys;

  void registerPublisher() {
    count++;
  }

  void unregisterPublisher() {
    count--;
    if (count <= 0) {
      node.unadvertise<T>(topic);
    }
  }

  void publish(T message, [int ms]) {
    if (isShutdown) {
      return;
    }
    // final delay = ms ?? throttleMs;
    // if (throttleMs < 0) {
    _handleMsgQueue([message]);
    // }
  }

  void _handleMsgQueue(List<T> messages) {
    if (isShutdown) {
      return;
    }
    if (numSubscribers == 0) {
      // TODO: log
      print('Publishing message on ${topic} with no subscribers');
    }
    try {
      messages.forEach((msg) {
        final writer = ByteDataWriter();
        serializeMessage(writer, msg);
        for (final client in subClients.values) {
          client.write(writer.toString());
        }
        if (latching) {
          lastSentMsg = msg;
        }
      });
    } catch (e) {
      // TODO: log
      print('Error when publishing message on topic $topic: $e');
    }
  }

  void shutdown() {
    _state = State.SHUTDOWN;
    //TODO: Log
    subClients.values.forEach((c) => c.close());
  }

  Future<void> _register() async {
    try {
      final resp = await node.registerPublisher(topic, type);

      // if we were shutdown between the starting the registration and now, bail
      if (isShutdown) {
        return;
      }

      print('Registered $topic as a publisher: $resp');
      // registration worked
      _state = State.REGISTERED;
      // this.emit('registered');

    } catch (err) {
      print('Error while registering publisher $topic: $err');
    }
  }

  bool get isShutdown => _state == State.SHUTDOWN;
}
