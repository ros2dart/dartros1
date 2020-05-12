import '../node.dart';

class SubscriberImpl<T> {
  final Node node;
  int _count = 0;

  SubscriberImpl(this.node);
  Stream<T> get stream => null;

  String get type => null;

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
