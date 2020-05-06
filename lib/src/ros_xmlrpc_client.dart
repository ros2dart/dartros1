import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml_rpc/client.dart' as rpc;

import 'ros_xmlrpc_common.dart';
part 'ros_paramserver_client.dart';

mixin XmlRpcClient {
  http.Client client = http.Client();
  String get rosMasterUri => 'http://localhost:11311';
  String get qualifiedName;
  Future<XMLRPCResponse<T>> _call<T>(
    String methodName,
    List<dynamic> params, {
    Map<String, String> headers,
  }) async {
    final result = await rpc.call(
      rosMasterUri,
      methodName,
      params,
      headers: headers,
      encoding: utf8,
      client: client,
      encodeCodecs: [...rpc.standardCodecs, rpc.faultCodec],
      decodeCodecs: [...rpc.standardCodecs, rpc.faultCodec],
    ) as List<dynamic>;
    return XMLRPCResponse<T>(result[0] as int, result[1] as String, result[2]);
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
  Future<XMLRPCResponse<int>> registerService(
    String service,
    String serviceAPI,
    String callerAPI, {
    String callerID = '/',
  }) {
    return _call('registerService', [callerID, service, serviceAPI, callerAPI]);
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
  Future<XMLRPCResponse<int>> unregisterService(
    String service,
    String serviceAPI, {
    String callerID = '/',
  }) {
    return _call('unregisterService', [callerID, service, serviceAPI]);
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
  Future<XMLRPCResponse<List<String>>> registerSubscriber(
    String topic,
    String topicType,
    String callerAPI, {
    String callerID = '/',
  }) {
    return _call('registerSubscriber', [callerID, topic, topicType, callerAPI]);
  }

  /// Unsubscribes the [callerID] from the specified [topic].
  ///
  /// [callerID] is the ROS caller ID
  /// [topic] is the fully qualified name of the topic
  /// [callerAPI] is the XML-RPC URI of the caller node
  ///
  /// Return of zero means that the caller was not registered as a subscriber.
  /// The call still succeeds as the intended final state is reached.
  Future<XMLRPCResponse<int>> unregisterSubscriber(
    String topic,
    String callerAPI, {
    String callerID = '/',
  }) {
    return _call('unregisterSubscriber', [callerID, topic, callerAPI]);
  }

  /// Register the [callerID] as a publisher of the specified [topic].
  ///
  /// [callerID] is the ROS caller ID
  /// [topic] is the fully qualified name of the topic
  /// [topicType] is the datatype for the topic. Must be a package-resource name i.e. the .msg name
  /// [callerAPI] is the XML-RPC URI of the caller node
  ///
  /// Returns a list of XMLRPC API URIs for nodes currently subscribing the specified topic.
  Future<XMLRPCResponse<List<String>>> registerPublisher(
    String topic,
    String topicType,
    String callerAPI, {
    String callerID = '/',
  }) {
    return _call('registerPublisher', [callerID, topic, topicType, callerAPI]);
  }

  /// Unregisters the [callerID] as a publisher of the specified [topic].
  ///
  /// [callerID] is the ROS caller ID
  /// [topic] is the fully qualified name of the topic
  /// [callerAPI] is the XML-RPC URI of the caller node
  ///
  /// Return of zero means that the caller was not registered as a publisher.
  /// The call still succeeds as the intended final state is reached.
  Future<XMLRPCResponse<int>> unregisterPublisher(
    String topic,
    String callerAPI, {
    String callerID = '/',
  }) {
    return _call('unregisterPublisher', [callerID, topic, callerAPI]);
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
  Future<XMLRPCResponse<String>> lookupNode(
    String nodeName, {
    String callerID = '/',
  }) {
    return _call('lookupNode', [callerID, nodeName]);
  }

  /// Get list of topics that can be subscribed to.
  ///
  /// This does not return topics that have no publishers.
  /// See [getSystemState] to get more comprehensive list.
  ///
  /// [callerID] is the ROS caller ID
  /// [subgraph] is for restricting topic names to match within the specified subgraph.
  /// Subgraph namespace is resolved relative to the caller's namespace.
  /// Use emptry string to specify all names.
  Future<XMLRPCResponse<List<List<String>>>> getPublishedTopics(
    String subgraph, {
    String callerID = '/',
  }) {
    return _call('getPublishedTopics', [callerID, subgraph]);
  }

  /// Retrieve list topic names and their types.
  ///
  /// [callerID] is the ROS caller ID
  ///
  /// Returns a list of (topicName, topicType) pairs (lists)
  Future<XMLRPCResponse<List<List<String>>>> getTopicTypes({
    String callerID = '/',
  }) {
    return _call('getTopicTypes', [callerID]);
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
  Future<XMLRPCResponse<List<dynamic>>> getSystemState({
    String callerID = '/',
  }) {
    return _call('getSystemState', [callerID]);
  }

  /// Gets the URI of the master.
  ///
  /// [callerID] is the ROS caller ID
  Future<XMLRPCResponse<String>> getUri({
    String callerID = '/',
  }) {
    return _call('getUri', [callerID]);
  }

  /// Gets the URI of the master
  ///
  /// [service] is the fully qualified name of the service
  /// [callerID] is the ROS caller ID
  ///
  /// Return service URL (address and port). Fails if there is no provider.
  Future<XMLRPCResponse<String>> lookupService(
    String service, {
    String callerID = '/',
  }) {
    return _call('lookupService', [callerID, service]);
  }
}
