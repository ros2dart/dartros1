import 'package:dartros_msgutils/msg_utils.dart';

import 'impl/publisher_impl.dart';
import 'utils/client_states.dart';

class Publisher<T extends RosMessage<T>> {
  Publisher(this.impl)
      : topic = impl.topic,
        type = impl.type {
    impl.registerPublisher();
    _state = State.REGISTERED;
  }
  State _state = State.REGISTERING;
  final PublisherImpl<T> impl;
  final String topic;
  final String type;

  bool get latching => impl.latching;
  int get numSubscribers => impl.numSubscribers;
  Future<void> shutdown() async {
    await impl.unregisterPublisher();
    _state = State.SHUTDOWN;
  }

  bool get isShutdown => _state == State.SHUTDOWN;
  void publish(T message, [int throttleMs = 0]) =>
      impl.publish(message, throttleMs);
}
