import 'names.dart';
import 'node.dart';
import 'ros_xmlrpc_client.dart';
import 'subscriber.dart';
import 'utils/msg_utils.dart';
import 'publisher.dart';

class NodeHandle {
  String _namespace = '';
  final Node node;
  NodeHandle(this.node, [ns = '']) {
    namespace = ns;
  }
  String get namespace => _namespace;
  set namespace(String ns) {
    if (ns.startsWith('~')) {
      ns = names.resolve([ns]);
    }
    _namespace = _resolveName(namespace, remap: true);
  }

  String get nodeName => node.name;
  Future<String> getMasterUri() => node.getMasterUri();
  Future<List<TopicInfo>> getPublishedTopics(String subgraph) =>
      node.getPublishedTopics(subgraph);
  Future<List<TopicInfo>> getTopicTypes() => node.getTopicTypes();
  Future<SystemState> getSystemState() => node.getSystemState();

  bool get isShutdown => node.isShutdown;
  Publisher advertise<T extends RosMessage<T>>(String topic, T typeClass) {
    return node.advertise(_resolveName(topic), typeClass);
  }

  Subscriber subscribe<T extends RosMessage<T>>(String topic, T typeClass) {
    return node.subscribe(_resolveName(topic), typeClass);
  }

  void unadvertise(String topic) {
    node.unadvertise(_resolveName(topic));
  }

  void unsubscribe(String topic) {
    node.unsubscribe(_resolveName(topic));
  }

  // TODO: Service and action clients

  String _resolveName(String name,
      {bool remap = true, bool noValidate = false}) {
    if (!noValidate) {
      names.validate(name, throwError: true);
    }
    if (name.isEmpty) {
      return namespace;
    }
    if (name.startsWith('~')) {
      throw Exception('Using ~ names with NodeHandle methods is not allowed');
    } else if (!name.startsWith('/') && name.isNotEmpty) {
      name = names.append(namespace, name);
    } else {
      name = names.clean(name);
    }
    if (remap) {
      return _remapName(name);
    } else {
      return names.resolve([name, false]);
    }
  }

  String remapName(String name) {
    return _remapName(_resolveName(name));
  }

  String _remapName(String name) {
    return names.remap(name);
  }
}
