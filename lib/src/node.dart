import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:dartros/src/publisher.dart';
import 'package:dartros/src/ros_xmlrpc_client.dart';
import 'package:dartros/src/subscriber.dart';
import 'package:dartros_msgutils/msg_utils.dart';
import 'package:dartx/dartx.dart';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';
import 'package:xml_rpc/client.dart';
import 'package:xml_rpc/simple_server.dart' as rpc_server;

import 'impl/publisher_impl.dart';
import 'impl/subscriber_impl.dart';
import 'ros_xmlrpc_common.dart';
import 'service_client.dart';
import 'service_server.dart';
import 'utils/error_utils.dart';
import 'utils/log/logger.dart';
import 'utils/network_utils.dart';
import 'utils/tcpros_utils.dart';
import 'utils/udpros_utils.dart' as udp;

class Node extends rpc_server.XmlRpcHandler
    with XmlRpcClient, RosParamServerClient, RosXmlRpcClient {
  factory Node(String name, String rosMasterURI, {InternetAddress? rosIP}) =>
      _node ??= Node._(name, rosMasterURI, rosIP);
  Node._(this.nodeName, this.rosMasterURI, InternetAddress? rosIP)
      : super(methods: {}, codecs: [...standardCodecs, xmlRpcResponseCodec]) {
    _startServers();
    ProcessSignal.sigint.watch().listen((sig) => shutdown());
    init(rosIP: rosIP);
  }
  Future<void> init({InternetAddress? rosIP}) async {
    _ipAddress = rosIP?.address ?? await NetworkUtils.getIPAddress();
  }

  static Node? _node;
  static Node? get singleton => _node;
  String? _ipAddress;
  @override
  String get ipAddress => _ipAddress!;
  @override
  String get xmlRpcUri => 'http://$ipAddress:${_xmlRpcServer.port}';
  @override
  int get tcpRosPort => _tcpRosServer.port;
  @override
  String nodeName;
  Completer<bool> nodeReady = Completer();

  final Map<String, PublisherImpl> _publishers = {};
  final Map<String, SubscriberImpl> _subscribers = {};
  final Map<String, ServiceServer> _services = {};
  bool _ok = true;
  bool get ok => _ok;
  bool get isShutdown => !ok;
  String homeDir = Platform.environment['ROS_HOME'] ??
      path.join(Platform.environment['HOME'] ?? '', '.ros');
  String namespace = Platform.environment['ROS_NAMESPACE'] ?? '';
  String? logDir;
  @override
  final String rosMasterURI;
  late rpc_server.SimpleXmlRpcServer _xmlRpcServer;
  late ServerSocket _tcpRosServer;
  late RawServerSocket _udpRosServer;
  int get udpRosPort => _udpRosServer.port;
  int _connections = 0;

  Future<void> _startServers() async {
    await _startTcpRosServer();
    await _startXmlRpcServer();
    await _startUdpRosServer();
    nodeReady.complete(true);
  }

  Future<void> shutdown() async {
    log.dartros.info('Shutting node $nodeName down at ${DateTime.now()}');
    log.dartros.info('Shutdown tcprosServer');
    await _stopTcpRosServer();
    await _stopUdpRosServer();
    _ok = false;
    log.dartros.info('Shutdown subscribers');
    await Future.wait(List.of(_subscribers.values).map((s) => s.shutdown()));
    log.dartros.info('Shutdown subscribers...done');
    log.dartros.info('Shutdown publishers');
    await Future.wait(List.of(_publishers.values).map((p) => p.shutdown()));
    log.dartros.info('Shutdown publishers...done');
    log.dartros.info('Shutdown servers');
    for (final s in List.of(_services.values)) {
      s.shutdown();
    }
    log.dartros.info('Shutdown servers...done');
    log.dartros.info('Shutdown XMLRPC server');
    await _stopXmlRpcServer();
    log.dartros.info('Shutdown XMLRPC server...done');
    log.dartros.info('Shutting $nodeName down completed at ${DateTime.now()}');
    exit(0);
  }

  void processJobs() {}

  Publisher<T> advertise<T extends RosMessage<T>>(
    String topic,
    T typeClass,
    bool latching,
    bool tcpNoDelay,
    int queueSize,
    int throttleMs,
  ) {
    if (!_publishers.containsKey(topic)) {
      _publishers[topic] = PublisherImpl<T>(
          this, topic, typeClass, latching, tcpNoDelay, queueSize, throttleMs);
    }
    return Publisher<T>(_publishers[topic] as PublisherImpl<T>);
  }

  Subscriber<T> subscribe<T extends RosMessage<T>>(
      String topic,
      T typeClass,
      void Function(T) callback,
      int queueSize,
      int throttleMs,
      bool tcpNoDelay) {
    if (!_subscribers.containsKey(topic)) {
      log.superdebug.info('Adding subscriber implementation for topic $topic');
      _subscribers[topic] = SubscriberImpl<T>(
          this, topic, typeClass, queueSize, throttleMs, tcpNoDelay);
    }
    final sub = Subscriber<T>(_subscribers[topic] as SubscriberImpl<T>);
    sub.messageStream.listen(callback);
    return sub;
  }

  ServiceServer<C, R>?
      advertiseService<C extends RosMessage<C>, R extends RosMessage<R>>(
          String service,
          RosServiceMessage<C, R> messageClass,
          R Function(C) callback) {
    if (_services.containsKey(service)) {
      log.dartros.warn(
          'Tried to advertise a service that is already advertised in this node [$service]');
      return null;
    } else {
      _services[service] =
          ServiceServer<C, R>(service, messageClass, this, true, callback);
      return _services[service] as ServiceServer<C, R>?;
    }
  }

  ServiceClient<C, R> serviceClient<C extends RosMessage<C>,
              R extends RosMessage<R>>(
          String service, RosServiceMessage<C, R> messageClass,
          {bool persist = true, int maxQueueSize = -1}) =>
      ServiceClient<C, R>(service, messageClass, persist, maxQueueSize, this);

  Future<void> unadvertise<T>(String topic) async {
    final pub = _publishers[topic];
    if (pub != null) {
      log.superdebug.info('Unadvertising from topic $topic');
      _publishers.remove(topic);
      await pub.shutdown();
    }
    return unregisterPublisher(topic);
  }

  Future<void> unsubscribe(String topic) async {
    final sub = _subscribers[topic];
    if (sub != null) {
      log.superdebug.info('Unsubscribing from topic $topic');
      _subscribers.remove(topic);
      await sub.shutdown();
    }
    return unregisterSubscriber(topic);
  }

  Future<void> unadvertiseService(String service) async {
    if (_services.containsKey(service)) {
      log.superdebug.info('Unadvertising service $service');
      _services[service]!.disconnect();
      _services.remove(service);
      return unregisterService(service);
    }
  }

  /// The following section is an implementation of the Slave API from here: http://wiki.ros.org/ROS/Slave_API
  /// 1

  /// Starts the server for the slave api
  Future<void> _startXmlRpcServer() async {
    methods.addAll({
      'getBusStats': _handleGetBusStats,
      'getBusInfo': _handleGetBusInfo,
      'getMasterUri': _handleGetMasterUri,
      'shutdown': _handleShutdown,
      'getPid': _handleGetPid,
      'getSubscriptions': _handleGetSubscriptions,
      'getPublications': _handleGetPublications,
      'paramUpdate': _handleParamUpdate,
      'publisherUpdate': _handlePublisherUpdate,
      'requestTopic': _handleRequestTopic,
    });
    _xmlRpcServer = await listenRandomPort(
      10,
      (port) async => rpc_server.SimpleXmlRpcServer(
        host: '0.0.0.0',
        port: port,
        handler: this,
      ),
    );
    await _xmlRpcServer.start();
    log.superdebug.debug('Slave API Listening on port ${_xmlRpcServer.port}');
  }

  /// Stops the server for the slave api
  Future<void> _stopXmlRpcServer() async {
    await _xmlRpcServer.stop(force: true);
  }

  Future<void> _startUdpRosServer() async {
    _udpRosServer = await listenRandomPort(
      10,
      (port) => RawServerSocket.bind(
        '0.0.0.0',
        0,
      ),
    );

    _udpRosServer.listen(
      (socket) async {
        final connection = udp.UdpConnection(socket);
        log.superdebug
            .info('Node $nodeName got connection from ${connection.name}');

        await for (final _ in socket) {
          final reader = ByteDataReader(endian: Endian.little);
          final data = socket.read()!;
          reader.add(data);
          try {
            final header = udp.UDPRosHeader.deserialize(reader);
            log.superdebug.info('Got connection header $header');
            final connId = header.connectionId;
            final topic = _subscribers.keys.firstWhereOrNull(
                (topic) => _subscribers[topic]!.connectionId == connId);
            if (topic != null) {
              _subscribers[topic]!.handleMessageChunk(header, reader);
            } else {
              log.dartros
                  .info('Got connection header for unknown topic $topic');
            }
          } on Exception catch (e, st) {
            log.dartros
                .error('Unable to validate connection header $data $e\n$st');
            await socket.close();
            return;
          }
        }
      },
      onError: (e) => log.dartros.warn('Error on tcpros server! $e'),
      onDone: () => log.dartros.info('Closing tcp ros server'),
    );
    log.superdebug.info('UDP socket listening on $udpRosPort');
  }

  Future<void> _startTcpRosServer() async {
    _tcpRosServer = await listenRandomPort(
      10,
      (port) => ServerSocket.bind(
        '0.0.0.0',
        0,
      ),
    );

    _tcpRosServer.listen(
      (socket) async {
        final connection = TcpConnection(socket);
        log.superdebug
            .info('Node $nodeName got connection from ${connection.name}');

        final listener = socket.asBroadcastStream();
        late TCPRosChunk message;
        try {
          message = await listener
              .transform(TCPRosChunkTransformer().transformer)
              .first;
          final header = parseTcpRosHeader(message);

          log.superdebug.info('Got connection header $header');
          if (header.topic.isNotNullOrEmpty) {
            final topic = header.topic;
            if (_publishers.containsKey(topic)) {
              await _publishers[topic!]!
                  .handleSubscriberConnection(connection, listener, header);
            } else {
              log.dartros
                  .info('Got connection header for unknown topic $topic');
            }
          } else if (header.service.isNotNullOrEmpty) {
            final service = header.service;
            final serviceServer = _services[service!];
            if (serviceServer != null) {
              await serviceServer.handleClientConnection(
                  connection, listener, header);
            } else {
              log.dartros.info('Got service connection for unknown service');
            }
          } else {
            socket.add(serializeString(
                'Connection header $message has neither topic nor service'));
            await socket.flush();
            await socket.close();
          }
        } on HeaderParseException catch (e) {
          log.dartros.error('Unable to validate connection header $e');
          socket.add(
              serializeString('Unable to validate connection header $message'));
          await socket.flush();
          await socket.close();
          // ignore: avoid_catching_errors
        } on StateError catch (e, st) {
          log.dartros.error('$e\n$st');
          return;
        }
      },
      onError: (e) => log.dartros.warn('Error on tcpros server! $e'),
      onDone: () => log.dartros.info('Closing tcp ros server'),
    );
    log.superdebug.info('listening on $tcpRosPort');
  }

  Future<void> _stopTcpRosServer() => _tcpRosServer.close();
  Future<void> _stopUdpRosServer() => _udpRosServer.close();

  ///
  /// Retrieve transport/topic statistics
  /// Returns (int, str, [XMLRPCLegalValue*]) (code, statusMessage, stats)
  ///
  /// stats is of the form `[publishStats, subscribeStats, serviceStats]` where
  /// publishStats: `[[topicName, messageDataSent, pubConnectionData]...]`
  /// subscribeStats: `[[topicName, subConnectionData]...]`
  /// serviceStats: (proposed) `[numRequests, bytesReceived, bytesSent]`
  /// pubConnectionData: `[connectionId, bytesSent, numSent, connected]*`
  /// subConnectionData: `[connectionId, bytesReceived, dropEstimate, connected]*`
  /// dropEstimate: -1 if no estimate.
  XMLRPCResponse _handleGetBusStats(String callerID) {
    log.dartros.error('Handling get bus stats -- not implemented');
    return XMLRPCResponse(StatusCode.FAILURE.asInt, 'Not Implemented', 0);
  }

  /// Retrieve transport/topic connection information.
  ///
  /// Returns
  /// ```
  /// (int, str, [XMLRPCLegalValue*]) (code, statusMessage, busInfo)
  /// ```
  /// busInfo is of the form:
  /// ```
  /// [[connectionId1, destinationId1, direction1, transport1, topic1, connected1]... ]
  /// ```
  /// connectionId is defined by the node and is opaque.
  /// destinationId is the XMLRPC URI of the destination.
  /// direction is one of 'i', 'o', or 'b' (in, out, both).
  /// transport is the transport type (e.g. 'TCPROS').
  /// topic is the topic name.
  /// connected1 indicates connection status. Note that this field is only provided by slaves written in Python at the moment (cf. rospy/masterslave.py in _TopicImpl.get_stats_info() vs. roscpp/publication.cpp in Publication::getInfo()).
  XMLRPCResponse _handleGetBusInfo(String callerID) {
    log.dartros.info('Handling get bus info');
    var count = 0;
    final resp = [
      for (final sub in _subscribers.values)
        for (final client in sub.clientUris)
          [++count, client, 'i', sub.transport, sub.topic, true],
      for (final pub in _publishers.values)
        for (final client in pub.clientUris)
          [
            ++count,
            client,
            'o',
            pub.isUdpSubscriber(client) ? 'UDPROS' : 'TCPROS',
            pub.topic,
            true
          ]
    ];
    return XMLRPCResponse(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, resp);
  }

  /// Gets the URI of the master node
  XMLRPCResponse _handleGetMasterUri(String callerID) {
    log.dartros.info('Handling get master uri');
    return XMLRPCResponse(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, rosMasterURI);
  }

  /// Stop this server.
  ///
  /// [message] A message describing why the node is being shutdown
  XMLRPCResponse _handleShutdown(String callerID, [String message = '']) {
    if (message.isNotEmpty) {
      log.dartros.warn('Shutdown request: $message');
    } else {
      log.dartros.warn('Shutdown request');
    }
    shutdown();
    return XMLRPCResponse(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, 0);
  }

  /// Get the PID of this server.
  ///
  /// returns the PID
  XMLRPCResponse _handleGetPid(String callerID) {
    log.dartros.info('Handling get pid');
    return XMLRPCResponse(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, pid);
  }

  /// Retrieve a list of topics that this node subscribes to
  ///
  /// returns the topicList
  /// topicList is a list of topics this node subscribes to and is of the form
  /// `[ [topic1, topicType1]...[topicN, topicTypeN] ]`
  XMLRPCResponse _handleGetSubscriptions(String callerID) {
    log.dartros.info('Handling get subscriptions');
    return XMLRPCResponse(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, [
      for (final sub in _subscribers.entries) [sub.key, sub.value.type]
    ]);
  }

  /// Retrieve a list of topics that this node publishes
  ///
  /// returns the topicList
  /// topicList is a list of topics this node subscribes to and is of the form
  /// `[ [topic1, topicType1]...[topicN, topicTypeN] ]`
  XMLRPCResponse _handleGetPublications(String callerID) {
    log.dartros.info('Handling get publications');
    return XMLRPCResponse(
        StatusCode.SUCCESS.asInt, StatusCode.SUCCESS.asString, [
      for (final pub in _publishers.entries) [pub.key, pub.value.type]
    ]);
  }

  /// Callback from master with updated value of subscribed parameter.
  ///
  /// [parameterKey] parameter name, globally resolved
  /// [parameterValue] new parameter value
  XMLRPCResponse _handleParamUpdate(
      String callerID, String parameterKey, parameterValue) {
    log.dartros.info(
        'Got param update! $callerID sent parameter $parameterKey: $parameterValue. Not really doing anything with it...');
    return XMLRPCResponse(StatusCode.FAILURE.asInt, 'Not Implemented', 0);
  }

  /// Callback from master of current publisher list for specified topic
  ///
  /// [topic] Topic name
  /// [publishers] List of current publishers for topic in form of XMLRPC URIs
  XMLRPCResponse _handlePublisherUpdate(
      String callerID, String topic, List<dynamic> publishers) {
    log.superdebug.info(
        'Publisher update from $callerID for topic $topic, with publishers $publishers');
    if (_subscribers.containsKey(topic)) {
      final sub = _subscribers[topic]!;
      log.superdebug.info('Got sub for topic $topic');
      sub.handlePublisherUpdate(publishers);
      return XMLRPCResponse(StatusCode.SUCCESS.asInt,
          'Handled publisher update for topic $topic', 0);
    } else {
      log.superdebug.warn('Got publisher update for unknown topic $topic');
      return XMLRPCResponse(
          StatusCode.FAILURE.asInt, 'Don\'t have topic $topic', 0);
    }
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
  /// `[ProtocolName, ProtocolParam1, ProtocolParam2...N]`
  ///
  /// Returns `(int, str, [str, !XMLRPCLegalValue*] ) (code, statusMessage, protocolParams)`
  /// protocolParams may be an empty list if there are no compatible protocols.
  XMLRPCResponse _handleRequestTopic(
      String callerID, String topic, List<dynamic> protocols) {
    log.superdebug.info(
        'Handling topic request from $callerID for $topic with protocols: $protocols');
    List resp;
    if (_publishers.containsKey(topic)) {
      if (protocols[0][0] == 'TCPROS') {
        resp = [
          1,
          'Allocated topic connection on port $tcpRosPort',
          ['TCPROS', _ipAddress, tcpRosPort]
        ];
      } else {
        final pub = _publishers[topic]!;
        final msgCls = pub.messageClass;
        final header = udp.UDPRosHeader.parse(protocols[0][1]);
        assert(header.topic == topic);
        // final host = protocols[2][0][2];
        final port = protocols[0][3];
        final dgramSize = protocols[0][4];
        final writer = ByteDataWriter(endian: Endian.little);
        udp.createPubHeader(writer, nodeName, msgCls.md5sum, msgCls.fullType,
            msgCls.messageDefinition);
        final pubHeader = writer.toString();
        resp = [
          1,
          '',
          ['UDPROS', _ipAddress, port, ++_connections, dgramSize, pubHeader]
        ];
        _publishers[topic]!.addUdpSubscriber(_connections,
            UdpSocketOptions(port, _ipAddress!, dgramSize, _connections));
      }
    } else {
      log.dartros.error('Topic $topic does not exist for this ros node');
      resp = [0, 'Unable to allocate topic connection for $topic', []];
    }
    return XMLRPCResponse(resp[0], resp[1], resp[2]);
  }

  /// Our client's api to request a topic from another node
  Future<ProtocolParams> requestTopic(String remoteAddress, int remotePort,
      String topic, List<List<String>> protocols) {
    log.superdebug.info(
        'Requesting topic $topic from $remoteAddress:$remotePort with protocols: $protocols');

    final slave = SlaveApiClient(nodeName, remoteAddress, remotePort);
    return slave.requestTopic(topic, protocols);
  }

  @override
  XmlDocument handleFault(Fault fault, {List<Codec>? codecs}) {
    log.dartros.warn('XMLRPC Server error $fault');
    return super.handleFault(fault);
  }
}
