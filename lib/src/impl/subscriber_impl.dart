import '../../msg_utils.dart';
import '../utils/client_states.dart';

import '../node.dart';
import 'dart:io';

class SubscriberImpl<T extends RosMessage> {
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

  Stream<T> get stream => null;

  String get type => messageClass.fullType;

  int get numPublishers => pubClients.length;
  bool get isShutdown => _state == State.SHUTDOWN;
  List<String> get clientUris => pubClients.keys;

  void shutdown() {
    _state = State.SHUTDOWN;
    //TODO: log some things
    for (final client in pubClients.values) {
      disconnectClient(client);
    }
    pubClients.clear();
    for (final client in pendingClients.values) {
      disconnectClient(client);
    }
    pendingClients.clear();
    // TODO: spinner thing
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

  void _register() {}

  void disconnectClient(Socket client) {}
}
