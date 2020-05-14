import 'dart:io';

import 'remapping.dart';

final NetworkUtils = _NetworkUtils();

class _NetworkUtils {
  String _ip;
  String _hostname;
  String _ros_ip;
  String _ros_hostname;
  String _host;
  String get host => _host;

  _NetworkUtils();
  void init(Map<String, String> remappings) {
    _ip = remappings[SPECIAL_KEYS.ip];
    _hostname = remappings[SPECIAL_KEYS.hostname];
    _ros_ip = Platform.environment['ROS_HOME'];
    _ros_hostname = Platform.environment['ROS_HOSTNAME'];
    _host =
        _ip ?? _hostname ?? _ros_ip ?? _ros_hostname ?? Platform.localHostname;
  }

  String getAddressFromUri(String uriString) {
    return Uri.parse(uriString).host;
  }

  int getPortFromUri(String uriString) {
    return Uri.parse(uriString).port;
  }

  String formatServiceUri(int port) {
    return 'rosrpc://' + host + ':' + port.toString();
  }

  Future<String> getIPAddress({
    String interface,
    InternetAddressType type = InternetAddressType.IPv4,
  }) async {
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
