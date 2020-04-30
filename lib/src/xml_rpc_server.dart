import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:xml_rpc/client.dart' as rpc;

class XMLRPCServer {
  final String rosMasterURI = Platform.environment['ROS_MASTER_URI'];

  Future<XMLRPCResponse<T>> call<T>(String methodName, List<dynamic> params,
      {Map<String, String> headers,
      Encoding encoding,
      http.Client client,
      List<rpc.Codec<dynamic>> encodeCodecs,
      List<rpc.Codec<dynamic>> decodeCodecs}) async {
    final result = await rpc.call(
      rosMasterURI,
      methodName,
      params,
      headers: headers,
      encoding: encoding,
      client: client,
      encodeCodecs: encodeCodecs,
      decodeCodecs: decodeCodecs,
    ) as List<dynamic>;
    return XMLRPCResponse<T>(result[0] as int, result[1] as String, result[2]);
  }

  void printRosServerInfo() async {
    final response = await call('getSystemState', ['/']);
    print(response);
  }

  Future<XMLRPCResponse<dynamic>> getParam(String path) {
    return call('getParam', ['/', path]);
  }

  Future<XMLRPCResponse<String>> getStringParam(String path) {
    return call('getParam', ['/', path]);
  }

  Future<XMLRPCResponse<int>> getIntParam(String path) {
    return call('getParam', ['/', path]);
  }

  Future<XMLRPCResponse<double>> getDoubleParam(String path) {
    return call('getParam', ['/', path]);
  }

  Future<XMLRPCResponse<dynamic>> setParam(String path, String value) {
    return call('setParam', ['/', path, value]);
  }
}

enum StatusCode { SUCCESS, FAILURE, ERROR }

class XMLRPCResponse<T> {
  final StatusCode statusCode;
  final String statusMessage;
  final T value;
  XMLRPCResponse(int status, this.statusMessage, dynamic invalue)
      : statusCode = status.asStatusCode,
        value = invalue as T;
  bool get success => statusCode == StatusCode.SUCCESS;
  bool get failure => statusCode == StatusCode.FAILURE;
  bool get error => statusCode == StatusCode.ERROR;
  @override
  String toString() {
    return 'XMLRPCResponse: $value, Status $statusCode: $statusMessage';
  }
}

extension AsStatusCode on int {
  StatusCode get asStatusCode {
    switch (this) {
      case 1:
        return StatusCode.SUCCESS;
      case 0:
        return StatusCode.FAILURE;
      case -1:
        return StatusCode.ERROR;
      default:
        return StatusCode.ERROR;
    }
  }
}
