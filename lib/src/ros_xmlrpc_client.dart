import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:xml_rpc/client.dart' as rpc;

import 'ros_xmlrpc_common.dart';
import 'utils/network_utils.dart';

part 'ros_paramserver_client.dart';
part 'ros_xmlrpc_client.freezed.dart';

final XmlRpcResponseCodec xmlRpcResponseCodec = XmlRpcResponseCodec();

class XmlRpcResponseCodec implements rpc.Codec<XMLRPCResponse> {
  @override
  XmlNode encode(Object? value, rpc.XmlCodecEncodeSignature? encode) {
    // print('trying xmlrpc response codec');
    if (value is XMLRPCResponse) {
      // print('encoding');
      final values = <XmlNode>[];

      for (final e in [
        value.statusCode.asInt,
        value.statusMessage,
        value.value
      ]) {
        // print('$e');
        values.add(XmlElement(XmlName('value'), [], [encode!(e)]));
      }
      final data = XmlElement(XmlName('data'), [], values);
      // print(data);
      return XmlElement(XmlName('array'), [], [data]);
    } else {
      throw ArgumentError();
    }
  }

  @override
  XMLRPCResponse decode(XmlNode? node, rpc.XmlCodecDecodeSignature? decode) {
    if (!(node is XmlElement && node.name.local == 'array')) {
      throw ArgumentError();
    }
    final list = node
        .findElements('data')
        .first
        .findElements('value')
        .map(getValueContent)
        .map((el) => decode?.call(el))
        .toList();

    return XMLRPCResponse(list[0] as int, list[1] as String, list[2]!);
  }
}

XmlNode? getValueContent(XmlElement valueElt) =>
    valueElt.children.firstWhereOrNull((e) => e is XmlElement) ??
    valueElt.firstChild;

Future<T> _rpcCall<T extends Object>(
  String methodName,
  List<Object> params,
  String rosMasterUri,
  rpc.HttpPost post, {
  Map<String, String>? headers,
  T? Function()? onError,
}) async {
  final result = await rpc.call(
    Uri.parse(rosMasterUri),
    methodName,
    params,
    headers: headers,
    encoding: utf8,
    httpPost: post,
    encodeCodecs: [...rpc.standardCodecs, rpc.faultCodec],
    decodeCodecs: [...rpc.standardCodecs, rpc.faultCodec],
  );
  final resp = XMLRPCResponse(result[0] as int, result[1] as String, result[2]);

  if (resp.success) {
    return resp.value as T;
  } else {
    if (onError == null) {
      throw Exception(
          'Failed to execute RPC call $methodName, args: $params, result: $result');
    }
    return onError()!;
  }
}

Future<StatusCode> _rpcCallStatus<T extends Object>(
  String methodName,
  List<Object> params,
  String rosMasterUri,
  rpc.HttpPost post, {
  Map<String, String>? headers,
}) async {
  final result = await rpc.call(
    Uri.parse(rosMasterUri),
    methodName,
    params,
    headers: headers,
    encoding: utf8,
    httpPost: post,
    encodeCodecs: [...rpc.standardCodecs, rpc.faultCodec],
    decodeCodecs: [...rpc.standardCodecs, rpc.faultCodec],
  ) as List;
  final resp = XMLRPCResponse(result[0] as int, result[1] as String, result[2]);

  return resp.statusCode;
}

mixin XmlRpcClient {
  final http.Client client = http.Client();
  String get rosMasterURI;
  String get nodeName;
  int get tcpRosPort;
  String get xmlRpcUri;
  String get ipAddress;
  NetworkUtils get netUtils;

  Future<T> _call<T extends Object>(
    String methodName,
    List<Object> params, {
    Map<String, String>? headers,
    T? Function()? onError,
  }) =>
      _rpcCall(methodName, params, rosMasterURI, client.post,
          headers: headers, onError: onError);
  Future<StatusCode> _callRpc(
    String methodName,
    List<Object> params, {
    Map<String, String>? headers,
  }) =>
      _rpcCallStatus(methodName, params, rosMasterURI, client.post,
          headers: headers);
}

class SlaveApiClient {
  SlaveApiClient(this.nodeName, this.host, this.port);
  final String host;
  final int port;
  final String nodeName;
  final http.Client client = http.Client();

  Future<ProtocolParams> requestTopic(
      String topic, List<List<String>> protocols) async {
    final p = await _rpcCall('requestTopic', [nodeName, topic, protocols],
        '$host:$port', client.post) as List;
    return ProtocolParams(
        p[0], p[1], p[2] as int, p.length > 3 ? p[3] as int : 0);
  }
}

mixin RosXmlRpcClient on XmlRpcClient {
  /// The following section is an implementation of the Master API from here: http://wiki.ros.org/ROS/Master_API
  /// 2
  /// 2.1 register / unregister methods

  /// Registers node by [nodeName] as a provider of the specified [service]
  ///
  /// [service] is the fully qualified name of the service
  /// `serviceAPI` is the ROSRPC Service URI
  /// [xmlRpcUri] is the XML-RPC URI of the caller node
  ///
  /// Returns an int that can be ignored
  Future<void> registerService(
    String service,
  ) async {
    await _call('registerService', [
      nodeName,
      service,
      netUtils.formatServiceUri(ipAddress, tcpRosPort),
      xmlRpcUri
    ]);
  }

  /// Unregisters the node by [nodeName] as a provider of the specified [service]
  ///
  /// [service] is the fully qualified name of the service
  /// `serviceAPI` is the ROSRPC Service URI
  ///
  /// Returns number of unregistrations (either 0 or 1).
  /// If this is zero it means that the caller was not registered as a service provider.
  /// The call still succeeds as the intended final state is reached.
  Future<void> unregisterService(
    String service,
  ) async {
    await _call('unregisterService',
        [nodeName, service, netUtils.formatServiceUri(ipAddress, tcpRosPort)]);
  }

  /// Subscribe the node by [nodeName] to the specified [topic].
  ///
  /// In addition to receiving a list of current publishers, the subscriber
  /// will also receive notifications of new publishers via the publisherUpdate API
  ///
  /// [topic] is the fully qualified name of the topic
  /// [topicType] is the datatype for the topic. Must be a package-resource name i.e. the .msg name
  /// [xmlRpcUri] is the XML-RPC URI of the caller node
  ///
  /// Returns a list of XMLRPC API URIs for nodes currently publishing the specified topic.
  Future<List<String>> registerSubscriber(
    String topic,
    String topicType,
  ) async =>
      (await _call(
                  'registerSubscriber', [nodeName, topic, topicType, xmlRpcUri])
              as List)
          .cast<String>();

  /// Unsubscribes the node by [nodeName] from the specified [topic].
  ///
  /// [topic] is the fully qualified name of the topic
  /// [xmlRpcUri] is the XML-RPC URI of the caller node
  ///
  /// Return of zero means that the caller was not registered as a subscriber.
  /// The call still succeeds as the intended final state is reached.
  Future<void> unregisterSubscriber(
    String topic,
  ) async {
    await _call('unregisterSubscriber', [nodeName, topic, xmlRpcUri]);
  }

  /// Register the node by [nodeName] as a publisher of the specified [topic].
  ///
  /// [topic] is the fully qualified name of the topic
  /// [topicType] is the datatype for the topic. Must be a package-resource name i.e. the .msg name
  /// [xmlRpcUri] is the XML-RPC URI of the caller node
  ///
  /// Returns a list of XMLRPC API URIs for nodes currently subscribing the specified topic.
  Future<List<String>> registerPublisher(
    String topic,
    String topicType,
  ) async =>
      (await _call('registerPublisher', [nodeName, topic, topicType, xmlRpcUri])
              as List)
          .cast<String>();

  /// Unregisters the node by [nodeName] as a publisher of the specified [topic].
  ///
  /// [topic] is the fully qualified name of the topic
  /// [xmlRpcUri] is the XML-RPC URI of the caller node
  ///
  /// Return of zero means that the caller was not registered as a publisher.
  /// The call still succeeds as the intended final state is reached.
  Future<void> unregisterPublisher(
    String topic,
  ) async {
    await _call('unregisterPublisher', [nodeName, topic, xmlRpcUri]);
  }

  /// 2.2 Name service and system state

  /// Get the XML-RPC URI of the node with the associated [nodeName].
  ///
  /// This API is for looking information about publishers and subscribers.
  /// Use [lookupService] instead to lookup ROS-RPC URIs.
  ///
  /// [nodeName] is the name of the node to lookup
  ///
  /// Returns the URI of the node
  Future<String> lookupNode(
    String nodeName,
  ) async =>
      _call('lookupNode', [nodeName, nodeName]);

  /// Gets the URI of the master
  ///
  /// [service] is the fully qualified name of the service
  ///
  /// Return service URL (address and port). Fails if there is no provider.
  Future<String> lookupService(
    String service,
  ) async =>
      _call('lookupService', [nodeName, service]);

  /// Get list of topics that can be subscribed to.
  ///
  /// This does not return topics that have no publishers.
  /// See [getSystemState] to get more comprehensive list.
  ///
  /// [subgraph] is for restricting topic names to match within the specified subgraph.
  /// Subgraph namespace is resolved relative to the caller's namespace.
  /// Use empty string to specify all names.
  Future<List<TopicInfo>> getPublishedTopics(
    String subgraph,
  ) async =>
      (await _call('getPublishedTopics', [nodeName, subgraph]) as List)
          .map((t) => TopicInfo(t[0], t[1]))
          .toList();

  /// Retrieve list topic names and their types.
  ///
  /// Returns a list of (topicName, topicType) pairs (lists)
  Future<List<TopicInfo>> getTopicTypes() async =>
      (await _call('getTopicTypes', [nodeName]) as List)
          .map((t) => TopicInfo(t[0], t[1]))
          .toList();

  /// Retrieve list representation of system state (i.e. publishers, subscribers, and services).
  ///
  /// Returns the information in the following format
  /// System state is in list representation `[publishers, subscribers, services]`
  /// publishers is of the form
  /// `[ [topic1, [topic1Publisher1...topic1PublisherN]] ... ]`
  /// subscribers is of the form
  /// `[ [topic1, [topic1Subscriber1...topic1SubscriberN]] ... ]`
  /// services is of the form
  /// `[ [service1, [service1Provider1...service1ProviderN]] ... ]`
  Future<SystemState> getSystemState() async {
    final resp = await _call('getSystemState', [nodeName]) as List;
    return SystemState(
      [
        for (final pubInfo in resp[0])
          PublisherInfo(pubInfo[0] as String,
              [
                for (final publisher in pubInfo[1])
                  publisher as String
              ])
      ],
      [
        for (final subInfo in resp[1])
          SubscriberInfo(subInfo[0] as String,
              [
                for (final subscriber in subInfo[1])
                  subscriber as String
              ])
      ],
      [
        for (final servInfo in resp[2])
          ServiceInfo(servInfo[0] as String,
              [
                for (final serviceProvider in servInfo[1])
                  serviceProvider as String
              ])
      ],
    );
  }

  /// Gets the URI of the master.
  Future<String> getMasterUri() async => _call('getUri', [nodeName]);
}

@freezed
abstract class TopicInfo with _$TopicInfo {
  factory TopicInfo(String name, String type) = _TopicInfo;
}

@freezed
abstract class ProtocolParams with _$ProtocolParams {
  factory ProtocolParams(
          String protocol, String address, int port, int connectionId) =
      _ProtocolParams;
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
