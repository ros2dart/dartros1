import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:xml_rpc/client.dart' as rpc;

class ROSXMLRPCServer {
  final String rosMasterURI = Platform.environment['ROS_MASTER_URI'];

  Future<XMLRPCResponse<T>> _call<T>(
    String methodName,
    List<dynamic> params, {
    Map<String, String> headers,
    Encoding encoding,
    http.Client client,
    List<rpc.Codec<dynamic>> encodeCodecs,
    List<rpc.Codec<dynamic>> decodeCodecs,
  }) async {
    final result = await rpc.call(
      rosMasterURI,
      methodName,
      params,
      headers: headers,
      encoding: encoding,
      client: client,
      encodeCodecs: encodeCodecs,
      decodeCodecs: decodeCodecs,
    ) as List<dynamic>;
    return XMLRPCResponse<T>(result[0] as int, result[1] as String, result[2]);
  }

  void printRosServerInfo({String callerID = '/'}) async {
    final response = await _call('getSystemState', [callerID]);
    print(response);
  }

  Future<XMLRPCResponse<dynamic>> getParam(
    String key, {
    String callerID = '/',
  }) {
    return _call('getParam', [callerID, key]);
  }

  Future<XMLRPCResponse<String>> searchParam(
    String key, {
    String callerID = '/',
  }) {
    return _call('searchParam', [callerID, key]);
  }

  Future<XMLRPCResponse<String>> getStringParam(
    String key, {
    String callerID = '/',
  }) {
    return _call('getParam', [callerID, key]);
  }

  Future<XMLRPCResponse<int>> getIntParam(
    String key, {
    String callerID = '/',
  }) {
    return _call('getParam', [callerID, key]);
  }

  Future<XMLRPCResponse<double>> getDoubleParam(
    String key, {
    String callerID = '/',
  }) {
    return _call('getParam', [callerID, key]);
  }

  Future<XMLRPCResponse<dynamic>> setParam(
    String key,
    String value, {
    String callerID = '/',
  }) {
    return _call('setParam', [callerID, key, value]);
  }

  /// The following section is an implementation of the Slave API from here: http://wiki.ros.org/ROS/Slave_API
  /// 1
  ///
  /// Retrieve transport/topic statistics
  /// Returns (int, str, [XMLRPCLegalValue*]) (code, statusMessage, stats)
  ///
  /// stats is of the form [publishStats, subscribeStats, serviceStats] where
  /// publishStats: [[topicName, messageDataSent, pubConnectionData]...]
  /// subscribeStats: [[topicName, subConnectionData]...]
  /// serviceStats: (proposed) [numRequests, bytesReceived, bytesSent]
  /// pubConnectionData: [connectionId, bytesSent, numSent, connected]*
  /// subConnectionData: [connectionId, bytesReceived, dropEstimate, connected]*
  /// dropEstimate: -1 if no estimate.
  XMLRPCResponse<dynamic> getBusStats(String callerID) {
    final publishStats = [];
    final subscribeStats = [];
    final serviceStats = [];
    return XMLRPCResponse<dynamic>(
        StatusCode.SUCCESS.asInt,
        StatusCode.SUCCESS.asString,
        [publishStats, subscribeStats, serviceStats]);
  }

  /// Retrieve transport/topic connection information.
  ///
  /// Returns (int, str, [XMLRPCLegalValue*]) (code, statusMessage, busInfo)
  /// busInfo is of the form:
  /// [[connectionId1, destinationId1, direction1, transport1, topic1, connected1]... ]
  /// connectionId is defined by the node and is opaque.
  /// destinationId is the XMLRPC URI of the destination.
  /// direction is one of 'i', 'o', or 'b' (in, out, both).
  /// transport is the transport type (e.g. 'TCPROS').
  /// topic is the topic name.
  /// connected1 indicates connection status. Note that this field is only provided by slaves written in Python at the moment (cf. rospy/masterslave.py in _TopicImpl.get_stats_info() vs. roscpp/publication.cpp in Publication::getInfo()).
  XMLRPCResponse<dynamic> getBusInfo(String callerID) {
    return XMLRPCResponse<dynamic>(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, []);
  }

  /// Gets the URI fo the master node
  XMLRPCResponse<String> getMasterUri(String callerID) {
    return XMLRPCResponse<String>(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, rosMasterURI);
  }

  /// Stop this server.
  ///
  /// [message] A message describing why the node is being shutdown
  XMLRPCResponse<int> shutdown(String callerID, String message) {
    return XMLRPCResponse<int>(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, 0);
  }

  /// Get the PID of this server.
  ///
  /// returns the PID
  XMLRPCResponse<String> getPid(String callerID) {
    return XMLRPCResponse<String>(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, pid);
  }

  /// Retrieve a list of topics that this node subscribes to
  ///
  /// returns the topicList
  /// topicList is a list of topics this node subscribes to and is of the form
  /// [ [topic1, topicType1]...[topicN, topicTypeN] ]
  XMLRPCResponse<List<List<String>>> getSubscriptions(String callerID) {
    return XMLRPCResponse<List<List<String>>>(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, []);
  }

  /// Retrieve a list of topics that this node publishes
  ///
  /// returns the topicList
  /// topicList is a list of topics this node subscribes to and is of the form
  /// [ [topic1, topicType1]...[topicN, topicTypeN] ]
  XMLRPCResponse<List<List<String>>> getPublications(String callerID) {
    return XMLRPCResponse<List<List<String>>>(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, []);
  }

  /// Callback from master with updated value of subscribed parameter.
  ///
  /// [parameterKey] parameter name, globally resolved
  /// [parameterValue] new parameter value
  XMLRPCResponse<int> paramUpdate(
      String callerID, String parameterKey, dynamic parameterValue) {
    return XMLRPCResponse<int>(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, 0);
  }

  /// Callback from master of current publisher list for specified topic
  ///
  /// [topic] Topic name
  /// [publishers] List of current publishers for topic in form of XMLRPC URIs
  XMLRPCResponse<int> publisherUpdate(
      String callerID, String topic, List<String> publishers) {
    return XMLRPCResponse<int>(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, 0);
  }

  /// Publisher node API method called by a subscriber node.
  ///
  /// This requests that source allocate a channel for communication.
  /// Subscriber provides a list of desired protocols for communication.
  /// Publisher returns the selected protocol along with any additional params required for establishing connection.
  /// For example, for a TCP/IP-based connection, the source node may return a port number of TCP/IP server.
  ///
  /// [topic] Topic name
  /// [protocols] List of desired protocols for communication in order of preference.
  /// Each protocol is a list of the form
  /// [ProtocolName, ProtocolParam1, ProtocolParam2...N]
  ///
  /// Returns (int, str, [str, !XMLRPCLegalValue*] ) (code, statusMessage, protocolParams)
  /// protocolParams may be an empty list if there are no compatible protocols.
  XMLRPCResponse<List<dynamic>> requestTopic(
      String callerID, String topic, List<List<dynamic>> protocols) {
    return XMLRPCResponse<List<dynamic>>(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, 0);
  }

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
  Future<XMLRPCResponse<List<List<dynamic>>>> getSystemState({
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

enum StatusCode { SUCCESS, FAILURE, ERROR }

class XMLRPCResponse<T> {
  final StatusCode statusCode;
  final String statusMessage;
  final T value;
  XMLRPCResponse(int status, this.statusMessage, dynamic invalue)
      : statusCode = status.asStatusCode,
        value = invalue as T;

  bool get success => statusCode == StatusCode.SUCCESS;
  bool get failure => statusCode == StatusCode.FAILURE;
  bool get error => statusCode == StatusCode.ERROR;
  @override
  String toString() {
    return 'XMLRPCResponse: $value, Status $statusCode: $statusMessage';
  }
}

extension StatusCodeAsIntString on StatusCode {
  int get asInt {
    switch (this) {
      case StatusCode.SUCCESS:
        return 1;
      case StatusCode.FAILURE:
        return 0;
      case StatusCode.ERROR:
        return -1;
      default:
        return -1;
    }
  }

  String get asString {
    switch (this) {
      case StatusCode.SUCCESS:
        return 'SUCCESS';
      case StatusCode.FAILURE:
        return 'FAILURE';
      case StatusCode.ERROR:
        return 'ERROR';
      default:
        return 'ERROR';
    }
  }
}

extension AsStatusCode on int {
  StatusCode get asStatusCode {
    switch (this) {
      case 1:
        return StatusCode.SUCCESS;
      case 0:
        return StatusCode.FAILURE;
      case -1:
        return StatusCode.ERROR;
      default:
        return StatusCode.ERROR;
    }
  }
}
