import 'dart:io';
import 'dart:math';

import 'ros_xmlrpc_common.dart';
import 'package:xml_rpc/server.dart' as rpc_server;
import 'package:dartx/dartx.dart';

dynamic listenRandomPort(int limit, Function(int) create) {
  final random = Random();
  for (final i in 0.rangeTo(limit)) {
    try {
      final port = random.nextInt(65535 - 1024) + 1024;
      final result = create(port);
      return result;
    } catch (e) {
      // Do nothing
    }
  }
  throw Exception("Couldn't find a port to listen on");
}

abstract class RosXmlRpcServer extends rpc_server.XmlRpcHandler {
  final String rosMasterURI = Platform.environment['ROS_MASTER_URI'];
  rpc_server.SimpleXmlRpcServer _server;
  String get xmlRpcUri => '${_server.host}:${_server.port}';

  RosXmlRpcServer({bool onlyLocalhost = false}) : super(methods: {}) {
    methods.addAll({
      'getBusStats': _getBusStats,
      'getBusInfo': _getBusInfo,
      'getMasterUri': _getMasterUri,
      'shutdown': _shutdown,
      'getPid': _getPid,
      'getSubscriptions': _getSubscriptions,
      'getPublications': _getPublications,
      'paramUpdate': _paramUpdate,
      'publisherUpdate': _publisherUpdate,
      'requestTopic': _requestTopic,
    });
    _server = listenRandomPort(
      10,
      (port) => rpc_server.SimpleXmlRpcServer(
        host: onlyLocalhost ? '0.0.0.0' : '127.0.0.1',
        port: port,
        requestHandler: this,
      ),
    );
  }

  Future<void> startXmlRpcServer() async {
    await _server.serveForever();
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
  XMLRPCResponse<dynamic> _getBusStats(String callerID) {
    return XMLRPCResponse<dynamic>(
        StatusCode.FAILURE.asInt, 'Not Implemented', 0);
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
  XMLRPCResponse<dynamic> _getBusInfo(String callerID) {
    return XMLRPCResponse<dynamic>(
        StatusCode.FAILURE.asInt, 'Not Implemented', 0);
  }

  /// Gets the URI of the master node
  XMLRPCResponse<String> _getMasterUri(String callerID) {
    return XMLRPCResponse<String>(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, rosMasterURI);
  }

  void shutdown();

  /// Stop this server.
  ///
  /// [message] A message describing why the node is being shutdown
  XMLRPCResponse<int> _shutdown(String callerID, [String message = '']) {
    if (message != null && message.isNotEmpty) {
      print('shutdown request: $message');
    } else {
      print('shutdown request');
    }
    shutdown();
    return XMLRPCResponse<int>(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, 0);
  }

  /// Get the PID of this server.
  ///
  /// returns the PID
  XMLRPCResponse<String> _getPid(String callerID) {
    return XMLRPCResponse<String>(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, pid);
  }

  /// Retrieve a list of topics that this node subscribes to
  ///
  /// returns the topicList
  /// topicList is a list of topics this node subscribes to and is of the form
  /// [ [topic1, topicType1]...[topicN, topicTypeN] ]
  XMLRPCResponse<List<List<String>>> _getSubscriptions(String callerID) {
    return XMLRPCResponse<List<List<String>>>(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, [
      ['hello', 'hello']
    ]);
  }

  /// Retrieve a list of topics that this node publishes
  ///
  /// returns the topicList
  /// topicList is a list of topics this node subscribes to and is of the form
  /// [ [topic1, topicType1]...[topicN, topicTypeN] ]
  XMLRPCResponse<List<List<String>>> _getPublications(String callerID) {
    return XMLRPCResponse<List<List<String>>>(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, []);
  }

  /// Callback from master with updated value of subscribed parameter.
  ///
  /// [parameterKey] parameter name, globally resolved
  /// [parameterValue] new parameter value
  XMLRPCResponse<int> _paramUpdate(
      String callerID, String parameterKey, dynamic parameterValue) {
    return XMLRPCResponse<int>(StatusCode.FAILURE.asInt, 'Not Implemented', 0);
  }

  /// Callback from master of current publisher list for specified topic
  ///
  /// [topic] Topic name
  /// [publishers] List of current publishers for topic in form of XMLRPC URIs
  XMLRPCResponse<int> _publisherUpdate(
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
  XMLRPCResponse<List<dynamic>> _requestTopic(
      String callerID, String topic, List<List<dynamic>> protocols) {
    return XMLRPCResponse<List<dynamic>>(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, 0);
  }
}
