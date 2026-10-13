import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencanvasx/src/crash_log.dart';

void main() {
  test('crash logs are local, redacted and pruned', () {
    final dir = Directory.systemTemp.createTempSync('ocx_crash');
    addTearDown(() => dir.deleteSync(recursive: true));
    var day = DateTime(2026, 10, 1, 8);
    final log = CrashLog(dir.path, keep: 3, clock: () => day);
    log.record(
      StateError('failed with key sk-ant-abcdefghijklmnopqrstuvwx'),
      StackTrace.empty,
    );
    final text = File(log.fileFor(day)).readAsStringSync();
    expect(text, contains('failed with key'));
    expect(text, isNot(contains('abcdefghijklmnopqrstuvwx')));
    for (var i = 2; i <= 6; i++) {
      day = DateTime(2026, 10, i);
      log.record('error $i', null);
    }
    final names =
        dir.listSync().map((f) => f.uri.pathSegments.last).toList()..sort();
    expect(names, [
      'crash-2026-10-04.log',
      'crash-2026-10-05.log',
      'crash-2026-10-06.log',
    ]);
  });
}
