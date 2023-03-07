import 'dart:async';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';

import '../dartros.dart';
import 'utils/client_states.dart';
import 'utils/tcpros_utils.dart';

class ServiceServer<C extends RosMessage<C>, R extends RosMessage<R>> {
  ServiceServer(this.service, this.messageClass, this.node, this.persist,
      this.requestCallback) {
    _register();
  }
  final String service;
  final RosServiceMessage<C, R> messageClass;
  String get type => messageClass.fullType;
  final Node node;
  Map<String, TcpConnection> _clients = {};
  final bool persist;
  final int port = 0;
  final FutureOr<R> Function(C) requestCallback;
  State _state = State.REGISTERING;
  List<String> get clientUris => _clients.keys.toList();
  String get serviceUri => node.netUtils.formatServiceUri(node.ipAddress, port);

  void shutdown() {
    node.unregisterService(service);
  }

  bool get isShutdown => _state == State.SHUTDOWN;
  void disconnect() {
    _state = State.SHUTDOWN;
    for (final client in _clients.values) {
      client.socket.close();
    }
    _clients = {};
  }

  Future<void> handleClientConnection(
      TcpConnection connection, Stream listener, TCPRosHeader header) async {
    if (isShutdown) {
      return;
    }
    final name = connection.name;
    final socket = connection.socket;
    log.dartros.debug('Service $service handling new client connection');
    final writer = ByteDataWriter(endian: Endian.little);
    final validated = validateServiceClientHeader(
        writer, header, service, messageClass.md5sum);
    if (!validated) {
      log.dartros.error(
          'Error while validating service $service connection header: ${header.toString()}');
      await socket.close();
      return;
    }
    createServiceServerHeader(writer, node.nodeName, messageClass.md5sum, type);
    socket.add(writer.toBytes());
    _clients[name] = connection;
    try {
      await for (final data
          in listener.transform(TCPRosChunkTransformer().transformer)) {
        log.dartros.trace('Service $service got message! $data');
        final reader = ByteDataReader(endian: Endian.little)..add(data.buffer);
        final req = messageClass.request.deserialize(reader);
        final result = await requestCallback(req);
        if (isShutdown) {
          return;
        }
        final writer = ByteDataWriter(endian: Endian.little);
        serializeServiceResponse(writer, result, true);
        log.dartros.debug('Serializing service response ${writer.toBytes()}');
        socket.add(writer.toBytes());
        await socket.flush();
        log.dartros.debug('Flushed service response');
        if (!header.persistent) {
          log.dartros.debug('Closing non-persistent service client');
          await socket.close();
          _clients.remove(name);
          return;
        }
      }
    } on Exception catch (e) {
      _clients.remove(name);
      log.dartros.debug('Service client $name disconnected with error: $e!');
    }
    _clients.remove(name);
    log.dartros.debug('Service client $name disconnected!');
  }

  Future<void> _register() async {
    try {
      await node.registerService(service);
      if (isShutdown) {
        return;
      }
      _state = State.REGISTERED;
    } on Exception catch (e) {
      log.dartros.error('Error while registering service $service: error: $e');
    }
  }
}
