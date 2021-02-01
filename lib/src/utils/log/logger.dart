import 'package:logger/logger.dart' as logging;
import 'package:rosgraph_msgs/msgs.dart';
import 'package:std_msgs/msgs.dart';
import '../../../dartros.dart';
import '../../publisher.dart';
export 'package:logger/logger.dart';

enum Level { trace, debug, info, warn, error, fatal }

class RosFilter extends logging.LogFilter {
  RosFilter(this.logger);
  String logger;

  @override
  bool shouldLog(logging.LogEvent event) {
    if (event.level.index >=
        Logger._loggers[logger]!.logLevel.loggingLevel.index) {
      return true;
    }
    return false;
  }
}

class RosPrinter extends logging.PrettyPrinter {
  RosPrinter(this.logger);
  String logger;

  @override
  List<String> log(logging.LogEvent event) {
    Logger._rosLog?.publish(
        Log(
          header: Header(stamp: RosTime.now()),
          msg: event.message,
          level: event.level.intValue,
          name: nh.nodeName,
        ),
        0);
    return super.log(event);
  }
}

final Logger log = Logger();

class Logger extends logging.Logger {
  factory Logger() => _log;
  Logger._(this.name, {required this.logLevel})
      : super(
          filter: RosFilter(name),
          // TODO: Fix the color & line length problem with flutter
          printer: logging.PrettyPrinter(
            // printTime: true,
            printEmojis: false,
            methodCount: 0,
            colors: true,
            lineLength: 80,
          ),
          level: logLevel.loggingLevel,
          output: logging.ConsoleOutput(),
        );
  static const SUPERDEBUG = 'superdebug';
  static const DARTROS = 'dartros';
  static const MASTERAPI = 'masterapi';
  static const PARAMS = 'params';
  static final Logger _log = Logger._('ros', logLevel: Level.debug);
  static final Map<String, Logger> _loggers = {};
  static Publisher<Log>? _rosLog;

  void initializeNodeLogger(String nodeName, {Level? level}) {
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

  Logger getChildLogger(String childName, {Level? level}) {
    final newName = '$name.$childName';
    if (!_loggers.containsKey(newName)) {
      _loggers[newName] = Logger._(newName, logLevel: level!);
    }
    return _loggers[newName]!;
  }

  final String name;
  Level logLevel;

  void trace(Object message) => v(message);
  void debug(Object message) => d(message);
  void info(Object message) => i(message);
  void warn(Object message) => w(message);
  void error(Object message) => e(message);
  void fatal(Object message) => wtf(message);

  void traceThrottled(int ms, Object message) => _throttle(message, ms, trace);
  void debugThrottled(int ms, Object message) => _throttle(message, ms, debug);
  void infoThrottled(int ms, Object message) => _throttle(message, ms, info);
  void warnThrottled(int ms, Object message) => _throttle(message, ms, warn);
  void errorThrottled(int ms, Object message) => _throttle(message, ms, error);
  void fatalThrottled(int ms, Object message) => _throttle(message, ms, fatal);

  void traceOnce(Object message) => _once(message, trace);
  void debugOnce(Object message) => _once(message, debug);
  void infoOnce(Object message) => _once(message, info);
  void warnOnce(Object message) => _once(message, warn);
  void errorOnce(Object message) => _once(message, error);
  void fatalOnce(Object message) => _once(message, fatal);

  void _throttle(message, int ms, Function(Object) _logger) {
    if (_lastSentThrottled.containsKey(message)) {
      if (_lastSentThrottled[message]!.millisecondsSinceEpoch <
          DateTime.now().millisecondsSinceEpoch - ms) {
        _logger(message);
        _lastSentThrottled[message] = DateTime.now();
      }
    } else {
      _logger(message);
      _lastSentThrottled[message] = DateTime.now();
    }
  }

  void _once(message, Function(Object) _logger) {
    if (!_onceSent.contains(message)) {
      _logger(message);
      _onceSent.add(message);
    }
  }

  final Map<String, DateTime> _lastSentThrottled = {};
  final Set<String> _onceSent = {};

  static Future<void> initializeRosLogger() async {
    _rosLog = nh.advertise<Log>('/rosout', Log.$prototype,
        queueSize: 10, latching: true);
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

extension LoggingLevelToString on logging.Level {
  int get intValue {
    switch (this) {
      case logging.Level.verbose:
        return Log.DEBUG;
      case logging.Level.debug:
        return Log.DEBUG;
      case logging.Level.info:
        return Log.INFO;
      case logging.Level.warning:
        return Log.WARN;
      case logging.Level.error:
        return Log.ERROR;
      case logging.Level.wtf:
        return Log.FATAL;
      case logging.Level.nothing:
        return Log.FATAL;
    }
    return Log.FATAL;
  }
}
