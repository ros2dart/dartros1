import 'dart:async';
import 'dart:io';

import 'package:dartros/src/ros_xmlrpc_client.dart';
import 'package:dartros/src/ros_xmlrpc_server.dart';
import 'package:dartx/dartx.dart';
import 'package:path/path.dart' as path;

import 'utils/log/logger.dart';

class Node extends RosXmlRpcServer
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
  @override
  String qualifiedName;

  // final TCPROSHandler handler = TCPRosHandler();
  Node(this.name) : super() {
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

  @override
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
}
