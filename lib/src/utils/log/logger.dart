import 'dart:io';

import 'package:logger/logger.dart' as logger;

class Logger extends logger.Logger {
  final name;
  Logger(this.name)
      : super(
            printer: logger.PrettyPrinter(
                colors: stdout.supportsAnsiEscapes,
                lineLength: stdout.terminalColumns));
  void trace(message) => v(message);
  void debug(message) => d(message);
  void info(message) => i(message);
  void warn(message) => w(message);
  void error(message) => e(message);
  void fatal(message) => wtf(message);

  // TODO: Support throttling and once logs
  void traceThrottled(message) => v(message);
}
