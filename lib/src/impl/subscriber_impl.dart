import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:dartros/src/ros_xmlrpc_client.dart';
import 'package:dartros/src/utils/log/logger.dart';
import 'package:dartros/src/utils/udpros_utils.dart' as udp;
import 'package:rxdart/rxdart.dart';

import '../../msg_utils.dart';
import '../node.dart';
import '../utils/client_states.dart';
import '../utils/network_utils.dart';
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
  int _connectionId;
  final Map<String, Socket> pubClients = {};
  final Map<String, Socket> pendingClients = {};
  State _state = State.REGISTERING;

  String get spinnerId => 'Subscriber://$topic';

  final BehaviorSubject<T> _streamController = BehaviorSubject();
  Stream<T> get stream => _streamController.stream;

  String get type => messageClass.fullType;

  int get numPublishers => pubClients.length;
  bool get isShutdown => _state == State.SHUTDOWN;
  List<String> get clientUris => pubClients.keys.toList();

  int get connectionId => _connectionId;

  String get transport => udpFirst && udpEnabled ? 'UDPROS' : 'TCPROS';

  Future<void> shutdown() async {
    _state = State.SHUTDOWN;
    //TODO: log some things
    for (final client in pubClients.keys) {
      await _disconnectClient(client);
    }
    pubClients.clear();
    for (final client in pendingClients.keys) {
      await _disconnectClient(client);
    }
    pendingClients.clear();
    // TODO: spinner thing
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
    final info = NetworkUtils.getAddressAndPortFromUri(uri);
    //TODO: log
    try {
      final w = ByteDataWriter(endian: Endian.little);
      udp.createSubHeader(w, node.nodeName, messageClass.md5sum, topic, type);
      log.dartros.debug('Requesting topic from uri ${info.host}:${info.port}');
      var protocols = [
        if (tcpEnabled) ['TCPROS'],
        if (udpEnabled)
          ['UDPROS', w.toString(), info.host, port, dgramSize ?? 1500]
      ];
      if (udpFirst) {
        protocols = [...protocols.reversed];
      }
      final resp = await node.requestTopic(
          'http://${info.host}', info.port, topic, protocols);
      await _handleTopicRequestResponse(resp, uri);
    } on Exception catch (e) {
      //TODO: Log
    }
  }

  Future<void> _disconnectClient(String id) async {
    final client = pubClients[id] ?? pendingClients[id];
    if (client != null) {
      await client.close();
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
    } on Exception catch (e, trace) {
      print(e);
      print(trace);
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
    pendingClients[uri] = socket;
    try {
      await _handleConnectionHeader(socket, listener, uri);
    } on Exception catch (e) {
      log.dartros.error(
          'Subscriber client socket ${socket.name} on topic $topic had error: $e');
    }
  }

  Future<void> _handleUdpTopicRequestResponse(
      ProtocolParams parms, String uri) async {
    _connectionId = parms.connectionId;
  }

  Future<void> _handleConnectionHeader(
    Socket socket,
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
          socket.add(writer.toBytes());
          await socket.flush();
          await socket.close();
          await _disconnectClient(uri);
          return;
        }
        pubClients[uri] = socket;
        pendingClients.remove(uri);
        first = false;
      } else {
        _handleMessage(chunk);
      }
    }
    log.dartros.debug(
        'Subscriber client socket ${socket.name} on topic $topic disconnected');
    await _disconnectClient(uri);
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
          // _handleMessage(reader);
        }
        break;
      case 1:
        // Mutliple data
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
