part of 'ros_xmlrpc_client.dart';

mixin RosParamServerClient on XmlRpcClient {
  // TODO: Handle remapping keys

  Future<Object> getParam(String key) async {
    return (await _call('getParam', [qualifiedName, key])).value;
  }

  Future<List<String>> getParamNames() async {
    return (await _call('getParamNames', [qualifiedName])).value;
  }

  Future<String> searchParam(String key) async {
    return (await _call('searchParam', [qualifiedName, key])).value;
  }

  Future<bool> hasParam(String key) async {
    return (await _call('hasParam', [qualifiedName, key])).value;
  }

  Future<bool> deleteParam(String key) async {
    return (await _call('deleteParam', [qualifiedName, key])).success;
  }

  Future<bool> setParam(String key, String value) async {
    return (await _call('setParam', [qualifiedName, key, value])).success;
  }

  Future<Object> subscribeParam(String key) async {
    throw Exception('Subscribe to param not implemented');
  }

  Future<Object> unsubscribeParam(String key) async {
    throw Exception('Unubscribe to param not implemented');
  }
}
