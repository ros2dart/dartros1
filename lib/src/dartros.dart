import 'dart:io';

import 'names.dart';
import 'node.dart';
import 'node_handle.dart';
import 'time.dart';
import 'utils/log/logger.dart';
import 'utils/network_utils.dart';
import 'utils/remapping.dart';

/// Initializes a ros node for this process
///
/// There can only be one node per process,
/// if called twice with the same name,
/// returns a handle to the same node
///
/// The [name] of the ros node
/// Any command line arguments [args]
/// Whether to anonymize the name of the node [anonymize]
/// Override the ros master uri [rosMasterUri]
Future<NodeHandle> initNode(
  String name,
  List<String> args, {
  bool anonymize = false,
  String? rosMasterUri,
  InternetAddress? rosIP,
}) async {
  if (name.isEmpty) {
    throw Exception('Name must not be empty.');
  }
  // Process command line remappings
  final remappings = processRemapping(args);
  // Initializes the network utils from the remappings
  final netUtils = NetworkUtils(remappings);
  // Figures out the node name
  final nodeName = _resolveNodeName(name, remappings, anonymize);
  // Initializes the names in the namespace
  final nameRemappings = NameRemapping(remappings, nodeName.namespace);
  // If the node has already been created return that node or an error

  log.initializeNodeLogger(nodeName.name);
  final masterUri = rosMasterUri ??
      remappings['__master'] ??
      Platform.environment['ROS_MASTER_URI'] ??
      'http://localhost:11311';
  final node = Node(nodeName.name, masterUri,
      rosIP: rosIP, netUtils: netUtils, nameRemappings: nameRemappings);
  await node.nodeReady.future;
  await Logger.initializeRosLogger();
  await Time.initializeRosTime();
  return NodeHandle(node);
}

Node? _node;
NodeHandle get nh => NodeHandle(_node!);
NodeHandle getNodeHandle(String namespace) => NodeHandle(_node!, namespace);

NodeName _resolveNodeName(
    String nodeName, Map<String, String> remappings, bool anonymize) {
  var namespace =
      remappings['__ns'] ?? Platform.environment['ROS_NAMESPACE'] ?? '';
  namespace = NameUtils.clean(namespace);
  if (namespace.isEmpty || !namespace.startsWith('/')) {
    namespace = '/$namespace';
  }

  NameUtils.validate(namespace, throwError: true);

  var name = remappings['__name'] ?? nodeName;
  name = NameUtils.resolve([namespace, name], {}, '');

  // only anonymize node name if they didn't remap from the command line
  if (anonymize && remappings['__name'] == null) {
    name = _anonymizeNodeName(name);
  }

  return NodeName(name, namespace);
}

String _anonymizeNodeName(nodeName) => '${nodeName}_${pid}_${DateTime.now()}';

class NodeName {
  NodeName(this.name, this.namespace);
  final String name, namespace;
}
