import 'dart:async';
import 'dart:io';

import 'package:dartros/src/ros_xmlrpc_client.dart';
import 'package:dartros/src/ros_xmlrpc_server.dart';
import 'package:dartx/dartx.dart';
import 'package:path/path.dart' as path;
import 'utils/log/logger.dart';

import 'ros_xmlrpc_common.dart';
import 'package:xml_rpc/simple_server.dart' as rpc_server;

import 'utils/network_utils.dart';
import 'utils/remapping.dart';

class Node extends rpc_server.XmlRpcHandler
    with XmlRpcClient, RosParamServerClient, RosXmlRpcClient {
  String name;
  bool _ok = true;
  bool get ok => _ok;
  Map<String, dynamic> publishers = {};
  Map<String, dynamic> subscribers = {};
  Map<String, dynamic> servers = {};
  Logger logger;
  String homeDir = Platform.environment['ROS_HOME'] ??
      path.join(Platform.environment['HOME'], '.ros');
  String namespace = Platform.environment['ROS_NAMESPACE'] ?? '';
  String logDir;
  final int _tcpRosPort = 0;
  final String rosMasterURI = Platform.environment['ROS_MASTER_URI'];
  rpc_server.SimpleXmlRpcServer _server;
  @override
  String get xmlRpcUri => '${_server.host}:${_server.port}';
  @override
  int get tcpRosPort => _tcpRosPort;
  @override
  String qualifiedName;

  Node(this.name, List<String> args) : super(methods: {}) {
    final remappings = processRemapping(args);
    NetworkUtils.init(remappings);
    ProcessSignal.sigint.watch().listen((sig) => shutdown());
    logDir = path.join(homeDir, 'log');
    qualifiedName = namespace + name;
    Logger.logLevel = Level.warning;
    logger = Logger('');
    logger.error('Logging');
    logger.warn('Logging');
    print('here');
    startXmlRpcServer();
  }

  Future<void> printRosServerInfo() async {
    final response = await getSystemState();
    print(response.value);
  }

  Future<void> shutdown() async {
    logger.debug('Shutting node down');
    _ok = false;
    logger.debug('Shutdown subscribers');
    for (final s in subscribers.values) {
      s.shutdown();
    }
    logger.debug('Shutdown subscribers...done');
    logger.debug('Shutdown publishers');
    for (final p in publishers.values) {
      p.shutdown();
    }
    logger.debug('Shutdown publishers...done');
    logger.debug('Shutdown servers');
    for (final s in servers.values) {
      s.shutdown();
    }
    logger.debug('Shutdown servers...done');
    logger.debug('Shutdown XMLRPC server');
    await stopXmlRpcServer();
    logger.debug('Shutdown XMLRPC server...done');
    logger.debug('Shutting node done completed');
    exit(0);
  }

  void spinOnce() async {
    await Future.delayed(10.milliseconds);
    processJobs();
  }

  void spin() async {
    while (_ok) {
      await Future.delayed(1.seconds);
      processJobs();
    }
  }

  void processJobs() {}

  void unadvertise<T>(String topic) {}

  void unsubscribe(String topic) {}

  void requestTopic(String remoteAddress, int remotePort, String topic,
      List<List<String>> protocols) {
    final slave = SlaveApiClient(qualifiedName, remoteAddress, remotePort);
    slave.requestTopic(topic, protocols);
  }

  Future<void> startXmlRpcServer() async {
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
        host: '0.0.0.0',
        port: port,
        handler: this,
      ),
    );
    await _server.start();
  }

  Future<void> stopXmlRpcServer() async {
    await _server.stop(force: true);
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
