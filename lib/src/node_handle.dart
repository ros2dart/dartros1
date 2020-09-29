import 'names.dart';
import 'node.dart';
import 'publisher.dart';
import 'ros_xmlrpc_client.dart';
import 'service_client.dart';
import 'service_server.dart';
import 'subscriber.dart';
import 'utils/msg_utils.dart';

class NodeHandle {
  NodeHandle(this.node, [ns = '']) {
    namespace = ns;
  }
  String _namespace = '';
  final Node node;

  String get namespace => _namespace;
  set namespace(String ns) {
    var newNs = ns;
    if (newNs.startsWith('~')) {
      newNs = names.resolve([ns]);
    }
    _namespace = _resolveName(newNs, remap: true);
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
          {bool latching = false,
          bool tcpNoDelay = false,
          int queueSize = 1,
          int throttleMs = 0}) =>
      node.advertise<T>(_resolveName(topic), typeClass, latching, tcpNoDelay,
          queueSize, throttleMs);

  /// Subscribes to [topic] with message type [typeClass]
  ///
  /// [typeClass] must be a [RosMessage]
  Subscriber<T> subscribe<T extends RosMessage<T>>(
          String topic, T typeClass, void Function(T) callback,
          {int queueSize = 1, int throttleMs = 1, bool tcpNoDelay = false}) =>
      node.subscribe<T>(_resolveName(topic), typeClass, callback, queueSize,
          throttleMs, tcpNoDelay);
  // TODO: Add option to subscribe with UDP

  /// Advertises service server with type [messageClass]
  ///
  /// [messageClass] must be a [RosServiceMessage]
  ServiceServer<C, R, T> advertiseService<C extends RosMessage<C>,
              R extends RosMessage<R>, T extends RosServiceMessage<C, R>>(
          String service, T messageClass, R Function(C) callback) =>
      node.advertiseService(_resolveName(service), messageClass, callback);

  ServiceClient<C, R, T> serviceClient<
              C extends RosMessage<C>,
              R extends RosMessage<R>,
              T extends RosServiceMessage<C, R>>(String service, T messageClass,
          {bool persist = true, int maxQueueSize = -1}) =>
      node.serviceClient(_resolveName(service), messageClass,
          persist: persist, maxQueueSize: maxQueueSize);

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
    var newName = name;
    if (newName.startsWith('~')) {
      throw Exception('Using ~ names with NodeHandle methods is not allowed');
    } else if (!newName.startsWith('/') && newName.isNotEmpty) {
      newName = names.append(namespace, newName);
    } else {
      newName = names.clean(newName);
    }
    if (remap) {
      return _remapName(newName);
    } else {
      return names.resolve([newName, false]);
    }
  }

  /// A helper function to remap a name to the node handle's namespace
  ///
  /// Should not be needed by users' code probably
  String remapName(String name) => _remapName(_resolveName(name));

  // A helper function to remap the name
  String _remapName(String name) => names.remap(name);
}
