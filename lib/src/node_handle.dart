import 'names.dart';
import 'node.dart';
import 'ros_xmlrpc_client.dart';
import 'service_client.dart';
import 'service_server.dart';
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

  bool get isShutdown => node.isShutdown;
  String get nodeName => node.nodeName;

  // Server API stuff
  Future<String> getMasterUri() => node.getMasterUri();
  Future<List<TopicInfo>> getPublishedTopics(String subgraph) =>
      node.getPublishedTopics(subgraph);
  Future<List<TopicInfo>> getTopicTypes() => node.getTopicTypes();
  Future<SystemState> getSystemState() => node.getSystemState();

  // Param stuff
  Future<bool> hasParam(String param) => node.hasParam(param);
  Future<T> getParam<T>(String param, {T defaultValue}) =>
      node.getParam<T>(param, defaultValue: defaultValue);
  Future<bool> setParam(String param, Object value) =>
      node.setParam(param, value);
  Future<bool> deleteParam(String param) => node.deleteParam(param);
  Future<String> searchParam(String param) => node.searchParam(param);

  // Client API stuff

  /// Advertises [topic] with message type [typeClass]
  ///
  /// [typeClass] must be a [RosMessage]
  Publisher advertise<T extends RosMessage<T>>(String topic, T typeClass,
      {latching = false, tcpNoDelay = false, queueSize = 1, throttleMs = 0}) {
    return node.advertise<T>(_resolveName(topic), typeClass, latching,
        tcpNoDelay, queueSize, throttleMs);
  }

  /// Subscribes to [topic] with message type [typeClass]
  ///
  /// [typeClass] must be a [RosMessage]
  Subscriber subscribe<T extends RosMessage<T>>(
      String topic, T typeClass, void Function(T) callback,
      {queueSize = 1, throttleMs = 1, tcpNoDelay = false}) {
    return node.subscribe<T>(_resolveName(topic), typeClass, callback,
        queueSize, throttleMs, tcpNoDelay);
  }

  /// Advertises service server with type [typeClass]
  ///
  /// [typeClass] must be a [RosServiceMessage]
  ServiceServer<C, R, T> advertiseService<C extends RosMessage<C>,
          R extends RosMessage<R>, T extends RosServiceMessage<C, R>>(
      String service, T messageClass, R Function(C) callback) {
    return node.advertiseService(_resolveName(service), messageClass, callback);
  }

  ServiceClient<C, R, T> serviceClient<
          C extends RosMessage<C>,
          R extends RosMessage<R>,
          T extends RosServiceMessage<C, R>>(String service, T messageClass,
      {bool persist = true, maxQueueSize = -1}) {
    return node.serviceClient(_resolveName(service), messageClass,
        persist: persist, maxQueueSize: maxQueueSize);
  }

  void unadvertise(String topic) {
    node.unadvertise(_resolveName(topic));
  }

  void unsubscribe(String topic) {
    node.unsubscribe(_resolveName(topic));
  }

  void unadvertiseService(String topic) {
    node.unadvertiseService(_resolveName(topic));
  }

  /// A helper function to resolve the name within the handle's namespace
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

  /// A helper function to remap a name to the node handle's namespace
  ///
  /// Should not be needed by users' code probably
  String remapName(String name) {
    return _remapName(_resolveName(name));
  }

  // A helper function to remap the name
  String _remapName(String name) {
    return names.remap(name);
  }
}
