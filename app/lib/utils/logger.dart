import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  final String name;

  const AppLogger(this.name);

  void debug(String message) => _log(LogLevel.debug, message);
  void info(String message) => _log(LogLevel.info, message);
  void warning(String message) => _log(LogLevel.warning, message);
  void error(String message) => _log(LogLevel.error, message);

  void _log(LogLevel level, String message) {
    // Skip debug logs in release mode
    if (level == LogLevel.debug && kReleaseMode) return;

    final prefix = switch (level) {
      LogLevel.debug => '[DEBUG]',
      LogLevel.info => '[INFO]',
      LogLevel.warning => '[WARN]',
      LogLevel.error => '[ERROR]',
    };
    debugPrint('$prefix [$name] $message');
  }
}
