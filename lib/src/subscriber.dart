import 'dart:async';

import '../msg_utils.dart';
import 'impl/subscriber_impl.dart';

class Subscriber<T extends RosMessage<T>> {
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
  Future<void> shutdown() async {
    await impl.unregisterSubscriber();
    impl = null;
  }

  bool get isShutdown => impl == null;

  Stream<T> get messageStream => impl.stream;
}
