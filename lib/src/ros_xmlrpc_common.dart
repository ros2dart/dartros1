import 'dart:math';
import 'package:dartx/dartx.dart';

enum StatusCode { SUCCESS, FAILURE, ERROR }

Future<T> listenRandomPort<T>(int limit, Future<T> Function(int) create) async {
  final random = Random();
  for (final _ in 0.rangeTo(limit)) {
    try {
      final port = random.nextInt(65535 - 1024) + 1024;
      final result = await create(port);
      return result;
    } on Exception catch (_) {
      // Do nothing because we do a manual retry
    }
  }
  throw Exception("Couldn't find a port to listen on");
}

class XMLRPCResponse {
  XMLRPCResponse(int status, this.statusMessage, this.value)
      : statusCode = status.asStatusCode;

  final StatusCode statusCode;
  final String statusMessage;
  final Object value;

  bool get success => statusCode == StatusCode.SUCCESS;
  bool get failure => statusCode == StatusCode.FAILURE;
  bool get error => statusCode == StatusCode.ERROR;
  @override
  String toString() =>
      'XMLRPCResponse: $value, Status $statusCode: $statusMessage';
}

extension StatusCodeAsIntString on StatusCode {
  int get asInt {
    switch (this) {
      case StatusCode.SUCCESS:
        return 1;
      case StatusCode.FAILURE:
        return 0;
      case StatusCode.ERROR:
        return -1;
      default:
        return -1;
    }
  }

  String get asString {
    switch (this) {
      case StatusCode.SUCCESS:
        return 'SUCCESS';
      case StatusCode.FAILURE:
        return 'FAILURE';
      case StatusCode.ERROR:
        return 'ERROR';
      default:
        return 'ERROR';
    }
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
