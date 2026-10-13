import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// P1.5.6: no font is bundled without a known open licence, its licence
/// text and matching hashes.
void main() {
  const allowed = {'OFL-1.1', 'Apache-2.0', 'UFL-1.0'};
  final root = Directory('assets/fonts');

  test('every bundled font family is licensed, listed and intact', () {
    final index =
        jsonDecode(File('${root.path}/index.json').readAsStringSync())
            as Map<String, Object?>;
    final listed = {
      for (final f in (index['families']! as List).cast<Map<String, Object?>>())
        f['dir']! as String,
    };
    final dirs = {
      for (final d in root.listSync().whereType<Directory>())
        d.uri.pathSegments.where((s) => s.isNotEmpty).last,
    };
    expect(dirs, listed, reason: 'every folder is in index.json and back');

    for (final dir in dirs) {
      final base = '${root.path}/$dir';
      final meta =
          jsonDecode(File('$base/font.json').readAsStringSync())
              as Map<String, Object?>;
      expect(allowed, contains(meta['license']), reason: dir);
      expect(meta['source'], isA<String>(), reason: dir);
      final licence = File(
        meta['license'] == 'OFL-1.1' ? '$base/OFL.txt' : '$base/LICENSE.txt',
      );
      expect(licence.existsSync(), isTrue, reason: '$dir licence text');
      final files = (meta['files']! as List).cast<Map<String, Object?>>();
      expect(files, isNotEmpty, reason: dir);
      for (final f in files) {
        final bytes = File('$base/${f['file']}').readAsBytesSync();
        expect(sha256.convert(bytes).toString(), f['sha256'], reason: '$f');
      }
      // Nothing else is bundled in the folder.
      final allowedNames = {
        'font.json',
        'OFL.txt',
        'LICENSE.txt',
        for (final f in files) f['file']! as String,
      };
      for (final entity in Directory(base).listSync()) {
        expect(
          allowedNames,
          contains(entity.uri.pathSegments.last),
          reason: 'unexpected file in $dir',
        );
      }
    }
  });
}
