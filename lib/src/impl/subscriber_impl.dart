import 'dart:async';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:dartros/src/ros_xmlrpc_client.dart';
import 'package:rxdart/rxdart.dart';

import '../utils/network_utils.dart';
import '../utils/tcpros_utils.dart';

import '../../msg_utils.dart';
import '../utils/client_states.dart';

import '../node.dart';
import 'dart:io';

const protocols = [
  ['TCPROS']
];

class SubscriberImpl<T extends RosMessage<T>> {
  final Node node;
  final String topic;
  int _count = 0;
  final T messageClass;
  final int queueSize;
  final int throttleMs;
  final bool tcpNoDelay;
  // TODO: Logger
  final Map<String, Socket> pubClients = {};
  final Map<String, Socket> pendingClients = {};
  State _state = State.REGISTERING;
  SubscriberImpl(
    this.node,
    this.topic,
    this.messageClass,
    this.queueSize,
    this.throttleMs,
    this.tcpNoDelay,
  ) {
    _register();
  }

  String get spinnerId => 'Subscriber://$topic';

  final BehaviorSubject<T> _streamController = BehaviorSubject();
  Stream<T> get stream => _streamController.stream;

  String get type => messageClass.fullType;

  int get numPublishers => pubClients.length;
  bool get isShutdown => _state == State.SHUTDOWN;
  List<String> get clientUris => pubClients.keys;

  void shutdown() {
    _state = State.SHUTDOWN;
    //TODO: log some things
    for (final client in pubClients.keys) {
      _disconnectClient(client);
    }
    pubClients.clear();
    for (final client in pendingClients.keys) {
      _disconnectClient(client);
    }
    pendingClients.clear();
    // TODO: spinner thing
  }

  void requestTopicFromPubs(List<String> pubs) {
    pubs.forEach((uri) => _requestTopicFromPublisher(uri.trim()));
  }

  void handlePublisherUpdate(List<dynamic> pubs) {
    final missing = Set.of(pubClients.keys);
    for (final pub in pubs) {
      final uri = pub.trim();
      if (!pubClients.containsKey(uri)) {
        _requestTopicFromPublisher(uri);
      } else {
        missing.remove(uri);
      }
    }
    for (final pub in missing) {
      _disconnectClient(pub);
    }
  }

  Future<void> _requestTopicFromPublisher(String uri) async {
    final info = NetworkUtils.getAddressAndPortFromUri(uri);
    //TODO: log
    try {
      print('Requesting topic from uri ${info.host}:${info.port}');
      final resp = await node.requestTopic(
          'http://' + info.host, info.port, topic, protocols);
      await _handleTopicRequestResponse(resp, uri);
    } catch (e) {
      //TODO: Log
    }
  }

  void _disconnectClient(String id) {
    final client = pubClients[id] ?? pendingClients[id];
    if (client != null) {
      client.close();
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
    } catch (e, trace) {
      print(e);
      print(trace);
    }
  }

  Future<void> _handleTopicRequestResponse(
      ProtocolParams parms, String uri) async {
    if (isShutdown) {
      return;
    }
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
      _handleConnectionHeader(socket, listener, uri);
    } catch (e) {
      print(
          'Subscriber client socket ${socket.name} on topic ${topic} had error: $e');
    }
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
        _disconnectClient(uri);
        return;
      }
      if (first) {
        final header = parseTcpRosHeader(chunk);
        if (header.error != null) {
          print(header.error);
          _disconnectClient(uri);
          return;
        }
        final writer = ByteDataWriter(endian: Endian.little);
        final validated =
            validatePubHeader(writer, header, type, messageClass.md5sum);

        if (!validated) {
          print(
              'Unable to validate subscriber ${topic} connection header $header');
          socket.add(writer.toBytes());
          await socket.flush();
          await socket.close();
          _disconnectClient(uri);
          return;
        }
        print('Pub header validated');
        pubClients[uri] = socket;
        pendingClients.remove(uri);
        first = false;
      } else {
        _handleMessage(chunk);
      }
    }
    print(
        'Subscriber client socket ${socket.name} on topic $topic disconnected');
    _disconnectClient(uri);
  }

  void _handleMessage(TCPRosChunk message) {
    print('Handling message');
    _handleMsgQueue([message]);
  }

  void _handleMsgQueue(List<TCPRosChunk> messages) {
    try {
      for (final message in messages) {
        final reader = ByteDataReader(endian: Endian.little);
        reader.add(message.buffer);
        _streamController.add(messageClass.deserialize(reader));
      }
    } catch (e) {
      print('Error while deserializing message on topic $topic, $e');
    }
  }

  void registerSubscriber() {
    _count++;
  }

  void unregisterSubscriber() {
    _count--;
    if (_count <= 0) {
      node.unsubscribe(topic);
    }
  }
}
