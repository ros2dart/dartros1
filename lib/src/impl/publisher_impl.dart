import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:dartros/src/utils/tcpros_utils.dart';
import 'package:dartros/src/utils/udpros_utils.dart' as udp;

import '../../msg_utils.dart';
import '../node.dart';
import '../utils/client_states.dart';
import '../utils/log/logger.dart';

int msgCount = 0;

class PublisherImpl<T extends RosMessage> {
  PublisherImpl(
    this.node,
    this.topic,
    this.messageClass,
    // ignore: avoid_positional_boolean_parameters
    this.latching,
    this.tcpNoDelay,
    this.queueSize,
    this.throttleMs,
  ) {
    _register();
  }
  final Node node;
  final String/*!*/ topic;
  final bool latching;
  final int queueSize;
  final bool tcpNoDelay;
  final int throttleMs;
  int count = 0;
  T lastSentMsg;
  final T messageClass;
  State _state = State.REGISTERING;
  final Map<String, TcpConnection> subClients = {};
  final Map<String, UdpSocketOptions> udpSubClients = {};

  String get type => messageClass.fullType;
  String get spinnerId => 'Publisher://$topic';
  int get numSubscribers => subClients.keys.length + udpSubClients.length;
  List<String> get clientUris => [...subClients.keys, ...udpSubClients.keys];

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
      for (final msg in messages) {
        final writer = ByteDataWriter(endian: Endian.little);

        serializeMessage(writer, msg);
        final serialized = writer.toBytes();
        for (final client in subClients.values) {
          client.socket.add(serialized);
        }
        sendMsgToUdpClients(serialized);
        if (latching) {
          lastSentMsg = msg;
        }
        msgCount++;
      }
    } on Exception catch (e) {
      log.dartros.error('Error when publishing message on topic $topic: $e');
    }
  }

  Future<void> shutdown() async {
    _state = State.SHUTDOWN;
    log.dartros.debug('Shutting down publisher $topic');
    await Future.wait(subClients.values.map((c) => c.socket.close()));
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
    } on Exception catch (err, trace) {
      log.dartros
          .error('Error while registering publisher $topic: $err\n$trace');
    }
  }

  bool get isShutdown => _state == State.SHUTDOWN;

  Future<void> handleSubscriberConnection(
      TcpConnection connection, Stream listener, TCPRosHeader header) async {
    final socket = connection.socket;
    final writer = ByteDataWriter(endian: Endian.little);
    final validated =
        validateSubHeader(writer, header, topic, type, messageClass.md5sum);

    if (!validated) {
      socket.add(writer.toBytes());
      await socket.flush();
      await socket.close();
      return;
    }
    createPubHeader(writer, node.nodeName, messageClass.md5sum, type, latching,
        messageClass.messageDefinition);
    socket.add(writer.toBytes());
    if (tcpNoDelay || header.tcpNoDelay) {
      socket.setOption(SocketOption.tcpNoDelay, true);
    }
    listener.listen((_) {}, onError: (e) {
      log.dartros.warn('Error on publisher listener $e');
    }, onDone: () {
      subClients.remove(connection.name);
      socket.close();
    });
    if (lastSentMsg != null) {
      serializeMessage(writer, lastSentMsg);
      socket.add(writer.toBytes());
    }
    subClients[connection.name] = connection;
  }

  void addUdpSubscriber(int client, UdpSocketOptions options) {
    udpSubClients[client.toString()] = options;
  }

  bool isUdpSubscriber(String client) => udpSubClients.keys.contains(client);

  Future<void> sendMsgToUdpClients(Uint8List serialized) async {
    for (final client in udpSubClients.values) {
      final header =
          udp.UDPRosHeader(client.connId, 0, msgCount, 1, '', '', '', '', '');
      var w = ByteDataWriter(endian: Endian.little);
      header.serialize(w);
      final payloadSize = client.dgramSize - 8;
      if (serialized.length > payloadSize) {
        var offset = payloadSize;
        final chunk = serialized.sublist(0, payloadSize);
        final sock = await RawSocket.connect(client.host, client.port);
        w.write(chunk);
        sock.write(w.toBytes());
        while (offset < serialized.length) {
          offset += payloadSize;
          final chunk = serialized.sublist(
              offset, min(serialized.length, offset + payloadSize));
          w = ByteDataWriter(endian: Endian.little);
          header.serialize(w);
          w.write(chunk);
          sock.write(w.toBytes());
        }
      } else {
        final sock = await RawSocket.connect(client.host, client.port);
        w.write(serialized);
        sock.write(w.toBytes());
        await sock.close();
      }
    }
  }
}

class UdpSocketOptions {
  const UdpSocketOptions(this.port, this.host, this.dgramSize, this.connId);
  final int port;
  final String host;
  final int dgramSize;
  final int connId;
}
