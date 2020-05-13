import '../../msg_utils.dart';
import '../node.dart';

class SubscriberImpl<T extends RosMessage> {
  final Node node;
  int _count = 0;
  final T messageClass;

  SubscriberImpl(this.node, this.messageClass);
  Stream<T> get stream => null;

  String get type => messageClass.fullType;

  String get topic => null;

  int get numPublishers => null;

  void registerSubscriber() {
    _count++;
  }

  void unregisterSubscriber() {
    _count--;
    if (_count <= 0) {
      node.unsubscribe(topic);
    }
  }
}
