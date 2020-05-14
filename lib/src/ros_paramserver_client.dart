part of 'ros_xmlrpc_client.dart';

mixin RosParamServerClient on XmlRpcClient {
  // TODO: Handle remapping keys

  Future<Object> getParam(String key) async {
    return (await _call('getParam', [qualifiedName, key]));
  }

  Future<List<String>> getParamNames() async {
    return (await _call('getParamNames', [qualifiedName]));
  }

  Future<String> searchParam(String key) async {
    return (await _call('searchParam', [qualifiedName, key]));
  }

  Future<bool> hasParam(String key) async {
    return (await _call<int>('hasParam', [qualifiedName, key])) == 1;
  }

  Future<bool> deleteParam(String key) async {
    return (await _callRpc('deleteParam', [qualifiedName, key])) ==
        StatusCode.SUCCESS;
  }

  Future<bool> setParam(String key, String value) async {
    return (await _callRpc('setParam', [qualifiedName, key, value])) ==
        StatusCode.SUCCESS;
  }

  Future<Object> subscribeParam(String key) async {
    throw Exception('Subscribe to param not implemented');
  }

  Future<Object> unsubscribeParam(String key) async {
    throw Exception('Unubscribe to param not implemented');
  }
}
