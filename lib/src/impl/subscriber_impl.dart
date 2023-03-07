import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:dartros/src/ros_xmlrpc_client.dart';
import 'package:dartros/src/utils/log/logger.dart';
import 'package:dartros/src/utils/udpros_utils.dart' as udp;
import 'package:dartros_msgutils/msg_utils.dart';
import 'package:rxdart/rxdart.dart';

import '../node.dart';
import '../utils/client_states.dart';
import '../utils/tcpros_utils.dart';

const protocols = [
  ['TCPROS']
];

class SubscriberImpl<T extends RosMessage<T>> {
  SubscriberImpl(
    this.node,
    this.topic,
    this.messageClass,
    this.queueSize,
    this.throttleMs,
    // ignore: avoid_positional_boolean_parameters
    this.tcpNoDelay, {
    this.udpEnabled = false,
    this.tcpEnabled = true,
    this.port = 0,
    this.udpFirst = false,
    this.dgramSize = 1500,
  }) {
    _register();
  }
  final Node node;
  final String topic;
  final bool udpEnabled;
  final bool tcpEnabled;
  final int port;
  final bool udpFirst;
  int _count = 0;
  final int dgramSize;
  final T messageClass;
  final int queueSize;
  final int throttleMs;
  final bool tcpNoDelay;
  int? _connectionId;
  late UdpMessage _udpMessage;
  final Map<String, TcpConnection> pubClients = {};
  final Map<String, TcpConnection> pendingClients = {};
  State _state = State.REGISTERING;

  final BehaviorSubject<T> _streamController = BehaviorSubject();
  Stream<T> get stream => _streamController.stream;

  String get type => messageClass.fullType;

  int get numPublishers => pubClients.length;
  bool get isShutdown => _state == State.SHUTDOWN;
  List<String> get clientUris => pubClients.keys.toList();

  int? get connectionId => _connectionId;

  String get transport => udpFirst && udpEnabled ? 'UDPROS' : 'TCPROS';

  Future<void> shutdown() async {
    _state = State.SHUTDOWN;
    log.dartros.info('Subscriber $topic with type $type is shutting down');
    // Iterate on copy of keys so we can remove items during the iteration
    for (final client in [...pubClients.keys, ...pendingClients.keys]) {
      await _disconnectClient(client);
    }
  }

  void requestTopicFromPubs(List<String> pubs) {
    for (final uri in pubs) {
      _requestTopicFromPublisher(uri.trim());
    }
  }

  Future<void> handlePublisherUpdate(List<dynamic> pubs) async {
    final missing = Set.of(pubClients.keys);
    for (final pub in pubs) {
      final uri = pub.trim();
      if (!pubClients.containsKey(uri)) {
        await _requestTopicFromPublisher(uri);
      } else {
        missing.remove(uri);
      }
    }
    for (final pub in missing) {
      await _disconnectClient(pub);
    }
  }

  Future<void> _requestTopicFromPublisher(String uri) async {
    final info = node.netUtils.getAddressAndPortFromUri(uri);
    log.dartros.info(
        'Subscriber $topic with type $type is requesting topic from publisher at $uri');
    try {
      final w = ByteDataWriter(endian: Endian.little);
      udp.createSubHeader(w, node.nodeName, messageClass.md5sum, topic, type);
      log.dartros.debug('Requesting topic from uri ${info.host}:${info.port}');
      var protocols = <List<String>>[
        if (tcpEnabled) ['TCPROS'],
        if (udpEnabled)
          [
            'UDPROS',
            w.toString(),
            info.host,
            port.toString(),
            dgramSize.toString()
          ]
      ];
      if (udpFirst) {
        protocols = [...protocols.reversed];
      }
      final resp = await node.requestTopic(
          'http://${info.host}', info.port, topic, protocols);
      await _handleTopicRequestResponse(resp, uri);
    } on Exception catch (e, st) {
      log.dartros.error(
          'Subscriber $topic with type $type caught error $e during requesting topic from $uri\n$st');
    }
  }

  Future<void> _disconnectClient(String id) async {
    final client = pubClients[id] ?? pendingClients[id];
    if (client != null) {
      await client.socket.close();
      pubClients.remove(id);
      pendingClients.remove(id);
    }
  }

  Future<void> _register() async {
    try {
      final resp = await node.registerSubscriber(topic, type);
      if (isShutdown) {
        return;
      }
      _state = State.REGISTERED;
      if (resp.isNotEmpty) {
        requestTopicFromPubs(resp);
      }
    } on Exception catch (e, st) {
      log.dartros.error(
          'Subscriber $topic with type $type caught error $e while registering with the roscore\n$st');
    }
  }

  Future<void> _handleTopicRequestResponse(
      ProtocolParams parms, String uri) async {
    if (isShutdown) {
      return;
    }
    if (parms.protocol == 'UDPROS' && udpEnabled) {
      log.dartros.warn('Handling UDPROS topic request, this is a new feature');
      await _handleUdpTopicRequestResponse(parms, uri);
    } else if (parms.protocol == 'TCPROS' && tcpEnabled) {
      await _handleTcpTopicRequestResponse(parms, uri);
    } else {
      log.dartros.warn(
          'Publisher supports only ${parms.protocol} but it is not enabled');
    }
  }

  Future<void> _handleTcpTopicRequestResponse(
      ProtocolParams parms, String uri) async {
    final socket = await Socket.connect(parms.address, parms.port);
    final connection = TcpConnection(socket);
    if (isShutdown) {
      await socket.close();
      return;
    }
    final listener = socket.asBroadcastStream();
    final writer = ByteDataWriter(endian: Endian.little);
    createSubHeader(
      writer,
      node.nodeName,
      messageClass.md5sum,
      topic,
      type,
      messageClass.messageDefinition,
      tcpNoDelay,
    );
    socket.add(writer.toBytes());
    // TODO: Some more stuff here, listening for errors and close
    pendingClients[uri] = connection;
    try {
      await _handleConnectionHeader(connection, listener, uri);
    } on Exception catch (e) {
      log.dartros.error(
          'Subscriber client ${connection.name} on topic $topic had error: $e');
    }
  }

  Future<void> _handleUdpTopicRequestResponse(
      ProtocolParams parms, String uri) async {
    _connectionId = parms.connectionId;
  }

  Future<void> _handleConnectionHeader(
    TcpConnection connection,
    Stream<Uint8List> listener,
    String uri,
  ) async {
    var first = true;
    await for (final chunk
        in listener.transform(TCPRosChunkTransformer().transformer)) {
      if (isShutdown) {
        await _disconnectClient(uri);
        return;
      }
      if (first) {
        final header = parseTcpRosHeader(chunk);
        if (header.error != null) {
          log.dartros.debug('TCP ros header not valid ${header.error}');
          await _disconnectClient(uri);
          return;
        }
        final writer = ByteDataWriter(endian: Endian.little);
        final validated =
            validatePubHeader(writer, header, type, messageClass.md5sum);

        if (!validated) {
          log.dartros.debug(
              'Unable to validate subscriber $topic connection header $header');
          final socket = connection.socket;
          socket.add(writer.toBytes());
          await socket.flush();
          await socket.close();
          await _disconnectClient(uri);
          return;
        }
        pubClients[uri] = connection;
        pendingClients.remove(uri);
        first = false;
      } else {
        _handleMessage(chunk);
      }
    }
    log.dartros.debug(
        'Subscriber client ${connection.name} on topic $topic disconnected');
    await _disconnectClient(uri);
  }

  void _handleUdpMessage(ByteDataReader reader) {
    try {
      _streamController.add(messageClass.deserialize(reader));
    } on Exception catch (e) {
      log.dartros
          .error('Error while deserializing udp message on topic $topic, $e');
    }
  }

  void _handleMessage(TCPRosChunk message) {
    log.dartros.debug('Handling message');
    _handleMsgQueue([message]);
  }

  void _handleMsgQueue(List<TCPRosChunk> messages) {
    try {
      for (final message in messages) {
        final reader = ByteDataReader(endian: Endian.little);
        reader.add(message.buffer);
        _streamController.add(messageClass.deserialize(reader));
      }
    } on Exception catch (e) {
      log.dartros
          .error('Error while deserializing message on topic $topic, $e');
    }
  }

  void registerSubscriber() {
    _count++;
  }

  Future<void> unregisterSubscriber() async {
    _count--;
    if (_count <= 0) {
      await node.unsubscribe(topic);
    }
  }

  void handleMessageChunk(udp.UDPRosHeader header, ByteDataReader reader) {
    switch (header.opCode) {
      case 0:
        // No chunking
        if (header.blkN == 1) {
          _handleUdpMessage(reader);
          _udpMessage = UdpMessage(
              header.blkN!, header.msgId!, header.connectionId!, reader);
        }
        break;
      case 1:
        // Mutliple data
        if (header.msgId == _udpMessage.msgId &&
            connectionId == _udpMessage.connectionId) {
          reader.read(8);
          _udpMessage.buffer.add(reader.read(reader.remainingLength));
          if (_udpMessage.blkN - 1 == header.blkN) {
            _handleUdpMessage(_udpMessage.buffer);
          }
        }
        break;
      case 2:
        log.dartros.error('Error udp ping not implemented');
        break;
      case 3:
        log.dartros.error('Error in handling udp message chunk');
        break;
    }
  }
}

class UdpMessage {
  const UdpMessage(this.blkN, this.msgId, this.connectionId, this.buffer);
  final int blkN;
  final int msgId;
  final int connectionId;
  final ByteDataReader buffer;
}
