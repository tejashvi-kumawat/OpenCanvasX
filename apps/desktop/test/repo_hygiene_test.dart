import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Repository checks that keep the project buildable on every OS.
void main() {
  test('dependency paths use forward slashes (Windows-only paths break '
      'Linux and macOS builds)', () {
    final root = Directory('../..');
    final offenders = <String>[];
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.contains('/.dart_tool/') ||
          path.contains('/build/') ||
          path.contains('/ephemeral/') ||
          path.contains('/.git/')) {
        continue;
      }
      final name = path.split('/').last;
      if (name != 'pubspec.yaml' && name != 'pubspec_overrides.yaml') continue;
      for (final line in entity.readAsLinesSync()) {
        if (line.trimLeft().startsWith('path:') && line.contains(r'\')) {
          offenders.add('$path: ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
