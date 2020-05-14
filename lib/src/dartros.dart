// TODO: Put public facing types in this file.

import 'dart:io';

import 'node.dart';
import 'utils/network_utils.dart';
import 'utils/remapping.dart';
import 'names.dart';

// TODO: Node handle
Node initNode(String name, List<String> args,
    {bool anonymize = false, String rosMasterUri}) {
  final remappings = processRemapping(args);
  NetworkUtils.init(remappings);
  final nodeName = _resolveNodeName(name, remappings, anonymize);
  names.init(remappings, nodeName.namespace);
  if (Node.singleton != null) {
    if (nodeName.name == Node.singleton.qualifiedName) {
      return Node.singleton;
    } else {
      throw Exception(
          'Unable to initialize ${nodeName.name} - node ${Node.singleton.qualifiedName} already exists');
    }
  } // TODO: Initialize logger
  final masterUri = rosMasterUri ??
      remappings['__master'] ??
      Platform.environment['ROS_MASTER_URI'];
  final node = Node(nodeName.name, rosMasterUri);
  // TODO: Initialize Publishers for Logging and Subscriber for RosTime after node has finished initializing
  return Node.singleton;
}

NodeName _resolveNodeName(
    String nodeName, Map<String, String> remappings, bool anonymize) {
  var namespace =
      remappings['__ns'] ?? Platform.environment['ROS_NAMESPACE'] ?? '';
  namespace = names.clean(namespace);
  if (namespace.isEmpty || !namespace.startsWith('/')) {
    namespace = '/$namespace';
  }

  names.validate(namespace, throwError: true);

  nodeName = remappings['__name'] ?? nodeName;
  nodeName = names.resolve([namespace, nodeName]);

  // only anonymize node name if they didn't remap from the command line
  if (anonymize && remappings['__name'] != null) {
    nodeName = _anonymizeNodeName(nodeName);
  }

  return NodeName(nodeName, namespace);
}

String _anonymizeNodeName(nodeName) {
  return '${nodeName}_${pid}_${DateTime.now()}';
}

class NodeName {
  final String name;
  final String namespace;
  NodeName(this.name, this.namespace);
}
