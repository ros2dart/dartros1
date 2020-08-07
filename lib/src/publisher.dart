import '../msg_utils.dart';
import 'impl/publisher_impl.dart';

class Publisher<T extends RosMessage<T>> {
  Publisher(this.impl) {
    _topic = impl.topic;
    _type = impl.type;
    impl.registerPublisher();
  }

  PublisherImpl<T> impl;
  String _topic;
  String _type;

  String get topic => _topic;
  String get type => _type;
  bool get latching => impl?.latching ?? false;
  int get numSubscribers => impl?.numSubscribers ?? 0;
  Future<void> shutdown() async {
    await impl.unregisterPublisher();
    impl = null;
  }

  bool get isShutdown => impl == null;
  void publish(T message, [int throttleMs = 0]) =>
      impl?.publish(message, throttleMs);
}
