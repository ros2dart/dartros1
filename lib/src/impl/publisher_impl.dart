import 'dart:io';
import 'dart:typed_data';

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
    this.topic,
    this.messageClass,
    this.latching,
    this.tcpNoDelay,
    this.queueSize,
    this.throttleMs,
  ) {
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
      print('Shutdown, not sending any more messages');
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
      print('Publishing message on ${topic} with subscribers');
      messages.forEach((msg) {
        final writer = ByteDataWriter(endian: Endian.little);

        serializeMessage(writer, msg);
        for (final client in subClients.values) {
          print(writer.toBytes());
          client.add(writer.toBytes());
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

    } catch (err, trace) {
      print('Error while registering publisher $topic: $err\n$trace');
    }
  }

  bool get isShutdown => _state == State.SHUTDOWN;

  void handleSubscriberConnection(
      Socket connection, Stream listener, TCPRosHeader header) {
    print('Handling subscriber connection');
    final writer = ByteDataWriter(endian: Endian.little);
    final validated =
        validateSubHeader(writer, header, topic, type, messageClass.md5sum);

    if (!validated) {
      print('Sub header not validated');
      print(writer.toBytes());
      connection.add(writer.toBytes());
      connection.close();
    }
    print('Sub header validated');
    // TODO: Logging
    createPubHeader(writer, node.nodeName, messageClass.md5sum, type, latching,
        messageClass.messageDefinition);
    connection.add(writer.toBytes());
    if (tcpNoDelay || header.tcpNoDelay) {
      connection.setOption(SocketOption.tcpNoDelay, true);
    }
    listener.listen((_) {}, onError: (e) {
      print(e);
    }, onDone: () {
      print('finished');
      subClients.remove(connection.name);
      connection.close();
    });
    if (lastSentMsg != null) {
      serializeMessage(writer, lastSentMsg);
      connection.add(writer.toBytes());
    }
    subClients[connection.name] = connection;
  }
}
