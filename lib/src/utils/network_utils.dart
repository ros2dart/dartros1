import 'dart:io';

import 'remapping.dart';

class NetworkUtils {
  NetworkUtils(Map<String, String> remappings)
      : _ip = remappings[SPECIAL_KEYS.ip],
        _hostname = remappings[SPECIAL_KEYS.hostname],
        _ros_ip = Platform.environment['ROS_IP'],
        _ros_hostname = Platform.environment['ROS_HOSTNAME'] {
    _host =
        _hostname ?? _ip ?? _ros_hostname ?? _ros_ip ?? Platform.localHostname;
  }
  final String? _ip;
  final String? _hostname;
  final String? _ros_ip;
  final String? _ros_hostname;
  late String _host;
  String get host => _host;

  String getAddressFromUri(String uriString) => Uri.parse(uriString).host;

  Uri getAddressAndPortFromUri(String uriString) => Uri.parse(uriString);

  int getPortFromUri(String uriString) => Uri.parse(uriString).port;

  String formatServiceUri(String ipAddress, int port) =>
      'rosrpc://$ipAddress:$port';

  Future<String> getIPAddress({
    String? interface,
    InternetAddressType type = InternetAddressType.IPv4,
  }) async {
    if (_ip != null) {
      return _ip!;
    }
    if (_ros_ip != null) {
      return _ros_ip!;
    }
    final ifaces = await NetworkInterface.list(type: type);

    for (final iface in ifaces) {
      for (final addr in iface.addresses) {
        if (interface == null) {
          return addr.address;
        } else if (iface.name == interface) {
          return addr.address;
        }
      }
    }
    return '';
  }
}
