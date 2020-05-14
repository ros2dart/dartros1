import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:http/http.dart' as http;
import 'package:xml_rpc/client.dart' as rpc;

import 'ros_xmlrpc_common.dart';
import 'utils/network_utils.dart';
part 'ros_paramserver_client.dart';
part 'ros_xmlrpc_client.freezed.dart';

Future<T> _rpcCall<T>(
  String methodName,
  List<dynamic> params,
  String rosMasterUri,
  rpc.HttpPost post, {
  Map<String, String> headers,
  T Function() onError,
}) async {
  final result = await rpc.call(
    rosMasterUri,
    methodName,
    params,
    headers: headers,
    encoding: utf8,
    httpPost: post,
    encodeCodecs: [...rpc.standardCodecs, rpc.faultCodec],
    decodeCodecs: [...rpc.standardCodecs, rpc.faultCodec],
  ) as List<dynamic>;
  final resp =
      XMLRPCResponse<T>(result[0] as int, result[1] as String, result[2]);

  if (resp.success) {
    return resp.value;
  } else {
    if (onError == null) {
      throw Exception(
          'Failed to execute RPC call $methodName, args: $params, result: $result');
    }
    return onError();
  }
}

Future<StatusCode> _rpcCallStatus<T>(
  String methodName,
  List<dynamic> params,
  String rosMasterUri,
  rpc.HttpPost post, {
  Map<String, String> headers,
  T Function() onError,
}) async {
  final result = await rpc.call(
    rosMasterUri,
    methodName,
    params,
    headers: headers,
    encoding: utf8,
    httpPost: post,
    encodeCodecs: [...rpc.standardCodecs, rpc.faultCodec],
    decodeCodecs: [...rpc.standardCodecs, rpc.faultCodec],
  ) as List<dynamic>;
  final resp =
      XMLRPCResponse<T>(result[0] as int, result[1] as String, result[2]);

  return resp.statusCode;
}

mixin XmlRpcClient {
  final http.Client client = http.Client();
  String get rosMasterUri => 'http://localhost:11311';
  String get qualifiedName;
  int get tcpRosPort;
  String get xmlRpcUri;

  Future<T> _call<T>(
    String methodName,
    List<dynamic> params, {
    Map<String, String> headers,
  }) =>
      _rpcCall<T>(methodName, params, rosMasterUri, client.post,
          headers: headers);
  Future<StatusCode> _callRpc<T>(
    String methodName,
    List<dynamic> params, {
    Map<String, String> headers,
  }) =>
      _rpcCallStatus(methodName, params, rosMasterUri, client.post,
          headers: headers);
}

class SlaveApiClient {
  final String host;
  final int port;
  final String qualifiedName;
  final http.Client client = http.Client();

  SlaveApiClient(this.qualifiedName, this.host, this.port);

  Future<List<TopicInfo>> requestTopic(
      String topic, List<List<dynamic>> protocols) async {
    return (await _rpcCall<List<List<String>>>(
            'requestTopic',
            [qualifiedName, topic, protocols],
            host + ':' + port.toString(),
            client.post))
        .map((t) => TopicInfo(t[0], t[1]))
        .toList();
  }
}

mixin RosXmlRpcClient on XmlRpcClient {
  /// The following section is an implementation of the Master API from here: http://wiki.ros.org/ROS/Master_API
  /// 2
  /// 2.1 register / unregister methods

  /// Registers [callerID] as a provider of the specified [service]
  ///
  /// [callerID] is the ROS caller ID
  /// [service] is the fully qualified name of the service
  /// [serviceAPI] is the ROSRPC Service URI
  /// [callerAPI] is the XML-RPC URI of the caller node
  ///
  /// Returns an int that can be ignored
  Future<void> registerService(
    String service,
  ) async {
    await _call<int>('registerService', [
      qualifiedName,
      service,
      NetworkUtils.formatServiceUri(tcpRosPort),
      xmlRpcUri
    ]);
  }

  /// Unregisters [callerID] as a provider of the specified [service]
  ///
  /// [callerID] is the ROS caller ID
  /// [service] is the fully qualified name of the service
  /// [serviceAPI] is the ROSRPC Service URI
  ///
  /// Returns number of unregistrations (either 0 or 1).
  /// If this is zero it means that the caller was not registered as a service provider.
  /// The call still succeeds as the intended final state is reached.
  Future<void> unregisterService(
    String service,
  ) async {
    await _call<int>('unregisterService',
        [qualifiedName, service, NetworkUtils.formatServiceUri(tcpRosPort)]);
  }

  /// Subscribe the [callerID] to the specified [topic].
  ///
  /// In addition to receiving a list of current publishers, the subscriber
  /// will also receive notifications of new publishers via the publisherUpdate API
  ///
  /// [callerID] is the ROS caller ID
  /// [topic] is the fully qualified name of the topic
  /// [topicType] is the datatype for the topic. Must be a package-resource name i.e. the .msg name
  /// [callerAPI] is the XML-RPC URI of the caller node
  ///
  /// Returns a list of XMLRPC API URIs for nodes currently publishing the specified topic.
  Future<List<String>> registerSubscriber(
    String topic,
    String topicType,
  ) {
    return _call<List<String>>(
        'registerSubscriber', [qualifiedName, topic, topicType, xmlRpcUri]);
  }

  /// Unsubscribes the [callerID] from the specified [topic].
  ///
  /// [callerID] is the ROS caller ID
  /// [topic] is the fully qualified name of the topic
  /// [callerAPI] is the XML-RPC URI of the caller node
  ///
  /// Return of zero means that the caller was not registered as a subscriber.
  /// The call still succeeds as the intended final state is reached.
  Future<void> unregisterSubscriber(
    String topic,
  ) async {
    await _call<int>('unregisterSubscriber', [qualifiedName, topic, xmlRpcUri]);
  }

  /// Register the [callerID] as a publisher of the specified [topic].
  ///
  /// [callerID] is the ROS caller ID
  /// [topic] is the fully qualified name of the topic
  /// [topicType] is the datatype for the topic. Must be a package-resource name i.e. the .msg name
  /// [callerAPI] is the XML-RPC URI of the caller node
  ///
  /// Returns a list of XMLRPC API URIs for nodes currently subscribing the specified topic.
  Future<List<String>> registerPublisher(
    String topic,
    String topicType,
  ) {
    return _call<List<String>>(
        'registerPublisher', [qualifiedName, topic, topicType, xmlRpcUri]);
  }

  /// Unregisters the [callerID] as a publisher of the specified [topic].
  ///
  /// [callerID] is the ROS caller ID
  /// [topic] is the fully qualified name of the topic
  /// [callerAPI] is the XML-RPC URI of the caller node
  ///
  /// Return of zero means that the caller was not registered as a publisher.
  /// The call still succeeds as the intended final state is reached.
  Future<void> unregisterPublisher(
    String topic,
  ) async {
    await _call<int>('unregisterPublisher', [qualifiedName, topic, xmlRpcUri]);
  }

  /// 2.2 Name service and system state

  /// Get the XML-RPC URI of the node with the associated [nodeName].
  ///
  /// This API is for looking information about publishers and subscribers.
  /// Use [lookupService] instead to lookup ROS-RPC URIs.
  ///
  /// [nodeName] is the name of the node to lookup
  /// [callerID] is the ROS caller ID
  ///
  /// Returns the URI of the node
  Future<String> lookupNode(
    String nodeName,
  ) {
    return _call<String>('lookupNode', [qualifiedName, nodeName]);
  }

  /// Gets the URI of the master
  ///
  /// [service] is the fully qualified name of the service
  /// [callerID] is the ROS caller ID
  ///
  /// Return service URL (address and port). Fails if there is no provider.
  Future<String> lookupService(
    String service,
  ) {
    return _call<String>('lookupService', [qualifiedName, service]);
  }

  /// Get list of topics that can be subscribed to.
  ///
  /// This does not return topics that have no publishers.
  /// See [getSystemState] to get more comprehensive list.
  ///
  /// [callerID] is the ROS caller ID
  /// [subgraph] is for restricting topic names to match within the specified subgraph.
  /// Subgraph namespace is resolved relative to the caller's namespace.
  /// Use empty string to specify all names.
  Future<List<TopicInfo>> getPublishedTopics(
    String subgraph,
  ) async {
    return (await _call<List<List<String>>>(
            'getPublishedTopics', [qualifiedName, subgraph]))
        .map((t) => TopicInfo(t[0], t[1]))
        .toList();
  }

  /// Retrieve list topic names and their types.
  ///
  /// [callerID] is the ROS caller ID
  ///
  /// Returns a list of (topicName, topicType) pairs (lists)
  Future<List<TopicInfo>> getTopicTypes() async {
    return (await _call<List<List<String>>>('getTopicTypes', [qualifiedName]))
        .map((t) => TopicInfo(t[0], t[1]))
        .toList();
  }

  /// Retrieve list representation of system state (i.e. publishers, subscribers, and services).
  ///
  /// [callerID] is the ROS caller ID
  ///
  /// Returns the information in the following format
  /// System state is in list representation [publishers, subscribers, services]
  /// publishers is of the form
  /// [ [topic1, [topic1Publisher1...topic1PublisherN]] ... ]
  /// subscribers is of the form
  /// [ [topic1, [topic1Subscriber1...topic1SubscriberN]] ... ]
  /// services is of the form
  /// [ [service1, [service1Provider1...service1ProviderN]] ... ]
  Future<SystemState> getSystemState() async {
    final resp = await _call<List<dynamic>>('getSystemState', [qualifiedName]);
    return SystemState(
      [
        for (final pubInfo in resp[0])
          PublisherInfo(pubInfo[0] as String, pubInfo[1] as List<String>)
      ],
      [
        for (final subInfo in resp[1])
          SubscriberInfo(subInfo[0] as String, subInfo[1] as List<String>)
      ],
      [
        for (final servInfo in resp[2])
          ServiceInfo(servInfo[0] as String, servInfo[1] as List<String>)
      ],
    );
  }

  /// Gets the URI of the master.
  ///
  /// [callerID] is the ROS caller ID
  Future<String> getMasterUri() {
    return _call<String>('getUri', [qualifiedName]);
  }
}

@freezed
abstract class TopicInfo with _$TopicInfo {
  factory TopicInfo(String name, String type) = _TopicInfo;
}

@freezed
abstract class SystemState with _$SystemState {
  factory SystemState(
    List<PublisherInfo> publishers,
    List<SubscriberInfo> subscribers,
    List<ServiceInfo> services,
  ) = _SystemState;
}

@freezed
abstract class PublisherInfo with _$PublisherInfo {
  factory PublisherInfo(String topic, List<String> publishers) = _PublisherInfo;
}

@freezed
abstract class SubscriberInfo with _$SubscriberInfo {
  factory SubscriberInfo(String topic, List<String> subscibers) =
      _SubscriberInfo;
}

@freezed
abstract class ServiceInfo with _$ServiceInfo {
  factory ServiceInfo(String service, List<String> serviceProviders) =
      _ServiceInfo;
}
