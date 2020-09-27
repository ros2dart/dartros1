import 'dart:async';

import '../msg_utils.dart';
import 'impl/subscriber_impl.dart';
import 'utils/client_states.dart';

class Subscriber<T extends RosMessage<T>> {
  Subscriber(this.impl)
      : topic = impl.topic,
        type = impl.type {
    impl.registerSubscriber();
    _state = State.REGISTERED;
  }
  State _state = State.REGISTERING;
  final SubscriberImpl<T> impl;
  final String topic;
  final String type;

  int get numPublishers => impl?.numPublishers ?? 0;
  Future<void> shutdown() async {
    _state = State.SHUTDOWN;
    await impl.unregisterSubscriber();
  }

  bool get isShutdown => _state == State.SHUTDOWN;

  Stream<T> get messageStream => impl.stream;
}
