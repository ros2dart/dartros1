import '../node.dart';

class PublisherImpl<T> {
  final Node node;
  int count = 0;

  PublisherImpl(this.node);
  String get topic => null;

  String get type => null;

  bool get latching => null;

  int get numSubscribers => null;

  void registerPublisher() {
    count++;
  }

  void unregisterPublisher() {
    count--;
    if (count <= 0) {
      node.unadvertise<T>(topic);
    }
  }

  void publish(message, int throttleMs) {}
}
