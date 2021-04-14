part of 'ros_xmlrpc_client.dart';

mixin RosParamServerClient on XmlRpcClient {
  Future<T> getParam<T extends Object>(String key, {T? defaultValue}) =>
      _call('getParam', [nodeName, key], onError: () => defaultValue);

  Future<List<String>> getParamNames() => _call('getParamNames', [nodeName]);

  Future<String> searchParam(String key) =>
      _call('searchParam', [nodeName, key]);

  Future<bool> hasParam(String key) async =>
      (await _call('hasParam', [nodeName, key])) == 1;

  Future<bool> deleteParam(String key) async =>
      (await _callRpc('deleteParam', [nodeName, key])) == StatusCode.SUCCESS;

  Future<bool> setParam(String key, String value) async =>
      (await _callRpc('setParam', [nodeName, key, value])) ==
      StatusCode.SUCCESS;

  Future<Object> subscribeParam(String key) async {
    throw Exception('Subscribe to param not implemented');
  }

  Future<Object> unsubscribeParam(String key) async {
    throw Exception('Unubscribe to param not implemented');
  }
}
