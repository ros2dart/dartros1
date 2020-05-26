import 'dart:io';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:dartros/src/utils/tcpros_utils.dart';

import '../../msg_utils.dart';
import '../node.dart';
import '../utils/client_states.dart';
import '../utils/log/logger.dart';

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

  Future<void> unregisterPublisher() async {
    count--;
    if (count <= 0) {
      await node.unadvertise<T>(topic);
    }
  }

  void publish(T message, [int ms]) {
    if (isShutdown) {
      log.dartros.debug('Shutdown, not sending any more messages');
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
      log.dartros.debugThrottled(
          2000, 'Publishing message on $topic with no subscribers');
      return;
    }
    try {
      messages.forEach((msg) {
        final writer = ByteDataWriter(endian: Endian.little);

        serializeMessage(writer, msg);
        for (final client in subClients.values) {
          client.add(writer.toBytes());
        }
        if (latching) {
          lastSentMsg = msg;
        }
      });
    } catch (e) {
      log.dartros.error('Error when publishing message on topic $topic: $e');
    }
  }

  Future<void> shutdown() async {
    _state = State.SHUTDOWN;
    log.dartros.debug('Shutting down publisher $topic');
    await Future.wait(subClients.values.map((c) async => await c.close()));
    subClients.clear();
  }

  Future<void> _register() async {
    try {
      final resp = await node.registerPublisher(topic, type);
      // if we were shutdown between the starting the registration and now, bail
      if (isShutdown) {
        return;
      }
      log.dartros.debug('Registered $topic as a publisher: $resp');
      // registration worked
      _state = State.REGISTERED;
    } catch (err, trace) {
      log.dartros
          .error('Error while registering publisher $topic: $err\n$trace');
    }
  }

  bool get isShutdown => _state == State.SHUTDOWN;

  Future<void> handleSubscriberConnection(
      Socket connection, Stream listener, TCPRosHeader header) async {
    final writer = ByteDataWriter(endian: Endian.little);
    final validated =
        validateSubHeader(writer, header, topic, type, messageClass.md5sum);

    if (!validated) {
      connection.add(writer.toBytes());
      await connection.flush();
      await connection.close();
      return;
    }
    createPubHeader(writer, node.nodeName, messageClass.md5sum, type, latching,
        messageClass.messageDefinition);
    connection.add(writer.toBytes());
    if (tcpNoDelay || header.tcpNoDelay) {
      connection.setOption(SocketOption.tcpNoDelay, true);
    }
    listener.listen((_) {}, onError: (e) {
      log.dartros.warn('Error on publisher listener $e');
    }, onDone: () {
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
