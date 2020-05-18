import 'dart:io';

import 'package:logger/logger.dart' as logging;
export 'package:logger/logger.dart';

enum Level { trace, debug, info, warn, error, fatal }

class RosFilter extends logging.LogFilter {
  String logger;
  RosFilter(this.logger);

  @override
  bool shouldLog(logging.LogEvent event) {
    // TODO: From the logger name get the current log level of the logger.
    // TODO: Create a custom ros logger
    return true;
  }
}

final log = Logger();

class Logger extends logging.Logger {
  static const SUPERDEBUG = 'superdebug';
  static const DARTROS = 'dartros';
  static const MASTERAPI = 'masterapi';
  static const PARAMS = 'params';
  static final Logger _log = Logger._('ros');
  static final Map<String, Logger> _loggers = {};
  factory Logger() => _log;
  void initializeNodeLogger(String nodeName, {Level level}) {
    getChildLogger(SUPERDEBUG, level: Level.fatal);
    getChildLogger(DARTROS, level: Level.warn);
    getChildLogger(MASTERAPI, level: Level.warn);
    getChildLogger(PARAMS, level: Level.warn);
    // getChildLogger('spinner', level: Level.error);
  }

  Logger get superdebug => log.getChildLogger(SUPERDEBUG);
  Logger get dartros => log.getChildLogger(DARTROS);
  Logger get masterapi => log.getChildLogger(MASTERAPI);
  Logger get params => log.getChildLogger(PARAMS);

  Logger getChildLogger(String childName, {Level level}) {
    final newName = name + '.' + childName;
    if (!_loggers.containsKey(newName)) {
      _loggers[newName] = Logger._(newName, level: level);
    }
    return _loggers[newName];
  }

  final name;
  Level level;

  Logger._(this.name, {this.level})
      : super(
          filter: RosFilter(name),
          printer: logging.PrettyPrinter(
            // printTime: true,
            printEmojis: false,
            methodCount: 0,
            colors: stdout.supportsAnsiEscapes,
            lineLength: stdout.terminalColumns,
          ),
          level: level.loggingLevel,
          output: logging.ConsoleOutput(),
        );
  void trace(message) => v(message);
  void debug(message) => d(message);
  void info(message) => i(message);
  void warn(message) => w(message);
  void error(message) => e(message);
  void fatal(message) => wtf(message);

  void traceThrottled(int ms, message) => _throttle(message, ms, trace);
  void debugThrottled(int ms, message) => _throttle(message, ms, debug);
  void infoThrottled(int ms, message) => _throttle(message, ms, info);
  void warnThrottled(int ms, message) => _throttle(message, ms, warn);
  void errorThrottled(int ms, message) => _throttle(message, ms, error);
  void fatalThrottled(int ms, message) => _throttle(message, ms, fatal);

  void traceOnce(message) => _once(message, trace);
  void debugOnce(message) => _once(message, debug);
  void infoOnce(message) => _once(message, info);
  void warnOnce(message) => _once(message, warn);
  void errorOnce(message) => _once(message, error);
  void fatalOnce(message) => _once(message, fatal);

  void _throttle(message, int ms, Function(dynamic) _logger) {
    if (_lastSentThrottled.containsKey(message)) {
      if (_lastSentThrottled[message].millisecondsSinceEpoch <
          DateTime.now().millisecondsSinceEpoch - ms) {
        _logger(message);
        _lastSentThrottled[message] = DateTime.now();
      }
    } else {
      _logger(message);
      _lastSentThrottled[message] = DateTime.now();
    }
  }

  void _once(message, Function(dynamic) _logger) {
    if (!_onceSent.contains(message)) {
      _logger(message);
      _onceSent.add(message);
    }
  }

  Map<String, DateTime> _lastSentThrottled = {};
  Set<String> _onceSent = {};

  Future<void> initializeRosLogger() async {
    //TODO: initialize ros logger
  }
}

extension LevelToLoggingLevel on Level {
  logging.Level get loggingLevel {
    switch (this) {
      case Level.trace:
        return logging.Level.verbose;
      case Level.debug:
        return logging.Level.debug;
      case Level.info:
        return logging.Level.info;
      case Level.warn:
        return logging.Level.warning;
      case Level.error:
        return logging.Level.error;
      case Level.fatal:
        return logging.Level.wtf;
    }
    return logging.Level.nothing;
  }
}
