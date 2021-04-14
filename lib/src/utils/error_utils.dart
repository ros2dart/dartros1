class HeaderParseException implements Exception {
  HeaderParseException(this.values, this.message);
  final Map<String?, Object?> values;
  final String message;
  @override
  String toString() => '$values: \n $message';
}
