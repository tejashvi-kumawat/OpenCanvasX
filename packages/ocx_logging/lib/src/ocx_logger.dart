import 'dart:developer' as developer;

import 'log_level.dart';
import 'redaction.dart';

typedef LogSink = void Function(LogLevel level, String message, {Object? error, StackTrace? stackTrace});

/// Application logger; always redacts secrets before emitting.
class OcxLogger {
  OcxLogger({
    this.name = 'ocx',
    LogLevel minLevel = LogLevel.info,
    SecretRedactor? redactor,
    LogSink? sink,
  })  : _minLevel = minLevel,
        _redactor = redactor ?? SecretRedactor(),
        _sink = sink ?? _defaultSink;

  final String name;
  final LogLevel _minLevel;
  final SecretRedactor _redactor;
  final LogSink _sink;

  void trace(String message) => _log(LogLevel.trace, message);
  void debug(String message) => _log(LogLevel.debug, message);
  void info(String message) => _log(LogLevel.info, message);
  void warn(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.warn, message, error: error, stackTrace: stackTrace);
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.error, message, error: error, stackTrace: stackTrace);

  void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < _minLevel.index) return;
    final safe = _redactor.redact(message);
    _sink(level, safe, error: error, stackTrace: stackTrace);
  }

  static void _defaultSink(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: 'ocx',
      level: _toDeveloperLevel(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static int _toDeveloperLevel(LogLevel level) => switch (level) {
        LogLevel.trace => 500,
        LogLevel.debug => 700,
        LogLevel.info => 800,
        LogLevel.warn => 900,
        LogLevel.error => 1000,
      };
}
