import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ocx_logging/ocx_logging.dart';

/// Local crash logs (P1.11.2, telemetry-and-privacy-policy.md §72).
///
/// Unhandled errors are appended, with secrets redacted, to
/// `<app data>/logs/crash-YYYY-MM-DD.log`; the newest [keep] files are
/// kept. Nothing is ever uploaded: the user can open the folder and share
/// a log themselves.
class CrashLog {
  CrashLog(this.directory, {this.keep = 10, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final String directory;
  final int keep;
  final DateTime Function() _clock;
  final SecretRedactor _redactor = SecretRedactor();

  String _two(int n) => n.toString().padLeft(2, '0');

  /// The file errors of [day] go to.
  String fileFor(DateTime day) =>
      '$directory${Platform.pathSeparator}crash-${day.year}-'
      '${_two(day.month)}-${_two(day.day)}.log';

  /// Appends [error] and its [stack] to today's log.
  void record(Object error, StackTrace? stack, {String context = ''}) {
    try {
      final now = _clock();
      Directory(directory).createSync(recursive: true);
      final text = _redactor.redact(
        '[${now.toIso8601String()}] ${context.isEmpty ? '' : '$context: '}'
        '$error\n${stack ?? ''}\n',
      );
      File(fileFor(now)).writeAsStringSync(text, mode: FileMode.append);
      _prune();
    } on Object {
      // Logging must never crash the app.
    }
  }

  void _prune() {
    final files =
        Directory(directory)
            .listSync()
            .whereType<File>()
            .where((f) => f.uri.pathSegments.last.startsWith('crash-'))
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    for (final old in files.skip(keep)) {
      old.deleteSync();
    }
  }

  /// Sends Flutter and platform errors here (still printing them in debug).
  void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      record(
        details.exception,
        details.stack,
        context: details.context?.toString() ?? '',
      );
      previous?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack, context: 'Uncaught');
      return false;
    };
  }
}
