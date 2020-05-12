import 'impl/publisher_impl.dart';

class Publisher<T> {
  PublisherImpl<T> impl;
  String _topic;
  String _type;
  Publisher(this.impl) {
    _topic = impl.topic;
    _type = impl.type;
    impl.registerPublisher();
  }

  String get topic => _topic;
  String get type => _type;
  bool get latching => impl?.latching ?? false;
  int get numSubscribers => impl?.numSubscribers ?? 0;
  void shutdown() {
    impl.unregisterPublisher();
    impl = null;
  }

  bool get isShutdown => impl == null;
  void publish(T message, int throttleMs) => impl?.publish(message, throttleMs);
}
