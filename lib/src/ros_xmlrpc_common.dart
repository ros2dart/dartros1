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
