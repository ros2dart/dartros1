import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:dartx/dartx.dart';

import 'node.dart';
import 'utils/client_states.dart';
import 'utils/log/logger.dart';
import 'utils/msg_utils.dart';
import 'utils/network_utils.dart';
import 'utils/tcpros_utils.dart';

class ServiceCall<C extends RosMessage<C>, R extends RosMessage<R>,
    T extends RosServiceMessage<C, R>> {
  ServiceCall(this.request, this.completer);
  final C request;
  final Completer<R> completer;
  Socket? _client;
  Stream<TCPRosChunk>? _clientStream;
}

class ServiceClient<C extends RosMessage<C>, R extends RosMessage<R>> {
  ServiceClient(this.service, this.serviceClass, this.persist,
      this.maxQueueSize, this.node);
  final String service;
  final RosServiceMessage<C, R> serviceClass;
  final bool persist;
  final int maxQueueSize;
  final Node node;
  final List<ServiceCall> _callQueue = [];
  ServiceCall? _currentCall;
  bool _callInProgress = false;
  bool get callInProgress => _callInProgress;
  Socket? _client;
  Stream? _clientStream;
  State _state = State.REGISTERED;

  String get type => serviceClass.fullType;
  void close() {
    if (!_callInProgress) {
      _client = null;
    }
  }

  void shutdown() {
    _state = State.SHUTDOWN;
    if (_currentCall != null) {
      _currentCall!.completer.completeError('SHUTDOWN');
    }
  }

  bool get isShutdown => _state == State.SHUTDOWN;
  Future<R> call(C request) {
    final call = ServiceCall(request, Completer<R>());
    _callQueue.add(call);
    if (maxQueueSize > 0 && _callQueue.length > maxQueueSize) {
      final call = _callQueue.removeAt(0);
      call.completer.completeError(
          'Unable to complete service call because of queue limitations');
    }
    if (_callQueue.length == 1 && _currentCall == null) {
      _executeCall();
    }
    return call.completer.future;
  }

  Future<void> _executeCall() async {
    if (isShutdown) {
      return;
    } else if (_callQueue.isEmpty) {
      log.dartros.warn('Tried executing service call on empty queue');
    }
    final _call = _callQueue.removeAt(0);
    _callInProgress = true;
    _currentCall = _call;
    try {
      await _initiateServiceConnection(_call);
      _throwIfShutdown();
      final resp = await _sendRequest(_call);
      _throwIfShutdown();
      _callInProgress = false;
      _currentCall = null;
      _scheduleNextCall();
      _call.completer.complete(resp);
    } on Exception catch (e, stack) {
      if (!isShutdown) {
        log.dartros.error('Error during service $service call $e\n$stack');
      }
      _callInProgress = false;
      _call?.completer?.completeError('$e');
      _currentCall = null;
      _scheduleNextCall();
    }
  }

  void _scheduleNextCall() {
    if (_callQueue.isNotEmpty && !isShutdown) {
      scheduleMicrotask(_executeCall);
    }
  }

  Future<void> _initiateServiceConnection(ServiceCall _call) async {
    if (!persist || _client == null) {
      try {
        final serv = await node.lookupService(service);
        _throwIfShutdown();
        final serviceHost = NetworkUtils.getAddressAndPortFromUri(serv);
        await _connectToService(serviceHost, _call);
      } on Exception catch (e) {
        log.dartros.error('Failure in service lookup $e');
        rethrow;
      }
    } else {
      _call._client = _client;
      _call._clientStream = _clientStream as Stream<TCPRosChunk>?;
    }
  }

  Future<R> _sendRequest(ServiceCall _call) async {
    final writer = ByteDataWriter(endian: Endian.little);
    final serializedRequest = serializeMessage(writer, _call.request);
    _call._client!.add(serializedRequest);
    try {
      final result = await _call._clientStream!.first;
      if (result.serviceResponseSuccess!) {
        final reader = ByteDataReader()..add(result.buffer);

        return serviceClass.response.deserialize(reader);
      } else {
        throw Exception('$result');
      }
    } on Exception catch (e) {
      log.dartros.error('Error in sending service request');
      rethrow;
    }
  }

  Future<void> _connectToService(Uri uri, ServiceCall _call) async {
    log.dartros
        .debug('Service client $service connection to ${uri.host}:${uri.port}');
    try {
      _call._client = await Socket.connect(uri.host, uri.port);
      final transformer = TCPRosChunkTransformer();
      _call._clientStream =
          _call._client!.transform(transformer.transformer).asBroadcastStream();
      if (persist) {
        _clientStream = _call._clientStream;
      }
      log.dartros.debug('Sending service client $service connection header');
      final writer = ByteDataWriter(endian: Endian.little);
      createServiceClientHeader(
          writer, node.nodeName, service, serviceClass.md5sum, type, persist);
      _call._client!.add(writer.toBytes());
      if (persist) {
        _client = _call._client;
      }
      _call._clientStream!.listen((_) {}, onDone: () {
        _call._client = null;
        _call._clientStream = null;
        if (persist) {
          _client = null;
          _clientStream = null;
        }
      });
      final msg = await _call._clientStream!.first;
      if (!transformer.deserializeServiceResponse) {
        final header = parseTcpRosHeader(msg);
        if (header.error!.isNotNullOrEmpty) {
          _call.completer.completeError(header.error!);
        }
        transformer.deserializeServiceResponse = true;
      }
    } on Exception catch (e) {
      log.dartros.error('Error connecting to service $service at $uri');
      rethrow;
    }
  }

  void _throwIfShutdown() {
    if (isShutdown) {
      // TODO: Reject things gracefully?
      throw Exception('SHUTDOWN');
    }
  }
}
