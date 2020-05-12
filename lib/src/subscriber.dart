import 'dart:async';

import 'impl/subscriber_impl.dart';

class Subscriber<T> {
  SubscriberImpl<T> impl;
  String _topic;
  String _type;
  Subscriber(this.impl) {
    _topic = impl.topic;
    _type = impl.type;
    impl.registerSubscriber();
  }

  String get topic => _topic;
  String get type => _type;
  int get numPublishers => impl?.numPublishers ?? 0;
  void shutdown() {
    impl.registerSubscriber();
    impl = null;
  }

  bool get isShutdown => impl == null;

  Stream<T> get messageStream => impl.stream;
}
