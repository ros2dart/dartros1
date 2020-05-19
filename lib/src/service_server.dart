import 'dart:io';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';

import '../dartros.dart';
import '../msg_utils.dart';
import 'utils/client_states.dart';
import 'utils/log/logger.dart';
import 'utils/network_utils.dart';
import 'utils/tcpros_utils.dart';

class ServiceServer<C extends RosMessage<C>, R extends RosMessage<R>,
    T extends RosServiceMessage<C, R>> {
  final String service;
  final T messageClass;
  String get type => messageClass.fullType;
  final Node node;
  Map<String, Socket> _clients = {};
  final bool persist;
  final int port = 0;
  final R Function(C) requestCallback;
  State _state = State.REGISTERING;
  List<String> get clientUris => _clients.keys.toList();
  String get serviceUri => NetworkUtils.formatServiceUri(port);
  ServiceServer(this.service, this.messageClass, this.node, this.persist,
      this.requestCallback) {
    _register();
  }
  void shutdown() {
    node.unregisterService(service);
  }

  bool get isShutdown => _state == State.SHUTDOWN;
  void disconnect() {
    _state = State.SHUTDOWN;
    for (final client in _clients.values) {
      client.close();
    }
    _clients = {};
  }

  Future<void> handleClientConnection(
      Socket connection, Stream listener, TCPRosHeader header) async {
    if (isShutdown) {
      return;
    }
    log.dartros.debug('Service $service handling new client connection');
    final writer = ByteDataWriter(endian: Endian.little);
    final validated = validateServiceClientHeader(
        writer, header, service, messageClass.md5sum);
    if (!validated) {
      log.dartros.error(
          'Error while validating service $service connection header: ${writer.toBytes()}');
      await connection.close();
      return;
    }
    createServiceServerHeader(writer, node.nodeName, messageClass.md5sum, type);
    connection.add(writer.toBytes());
    _clients[connection.name] = connection;
    await for (final data in listener) {
      log.dartros.trace('Service $service got message! $data');
      final reader = ByteDataReader(endian: Endian.little)..add(data);
      final req = messageClass.request.deserialize(reader);
      final result = requestCallback(req);
      if (isShutdown) {
        return;
      }
      final writer = ByteDataWriter(endian: Endian.little);
      serializeServiceResponse(writer, result, true);
      connection.add(writer.toBytes());
      if (!header.persistent) {
        log.dartros.debug('Closing non-persistent service client');
        await connection.close();
        _clients.remove(connection.name);
        return;
      }
    }
    _clients.remove(connection.name);
    log.dartros.debug('Service client ${connection.name} disconnected!');
  }

  Future<void> _register() async {
    try {
      await node.registerService(service);
      if (isShutdown) {
        return;
      }
      _state = State.REGISTERED;
    } catch (e) {
      log.dartros.error('Error while registering service $service: error: $e');
    }
  }
}
