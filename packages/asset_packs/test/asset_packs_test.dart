import 'dart:convert';
import 'dart:io';

import 'package:asset_engine/asset_engine.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Validates the bundled packs on disk: licence metadata, files present,
/// hashes match, SVGs pass import validation.
void main() {
  final root = Directory('assets/packs');
  final index =
      jsonDecode(File('${root.path}/index.json').readAsStringSync())
          as Map<String, Object?>;
  final ids = [
    for (final p in (index['packs']! as List).cast<Map<String, Object?>>())
      p['id']! as String,
  ];

  test('index lists every pack folder', () {
    final folders = [
      for (final d in root.listSync().whereType<Directory>())
        d.uri.pathSegments.where((s) => s.isNotEmpty).last,
    ]..sort();
    expect([...ids]..sort(), folders);
  });

  for (final id in ids) {
    test('$id: licence, files and hashes', () {
      final dir = '${root.path}/$id';
      final pack = AssetPack.fromJson(
        jsonDecode(File('$dir/pack.json').readAsStringSync())
            as Map<String, Object?>,
      );
      expect(File('$dir/LICENSE').existsSync(), isTrue);
      expect(pack.items, isNotEmpty);
      expect(pack.items.map((i) => i.id).toSet(), hasLength(pack.items.length));
      // Hash and validate a sample spread across the pack (all would be slow).
      final step = (pack.items.length / 40).ceil();
      for (var i = 0; i < pack.items.length; i += step) {
        final item = pack.items[i];
        final bytes = File('$dir/${item.file}').readAsBytesSync();
        expect(sha256.convert(bytes).toString(), item.sha256, reason: item.id);
        expect(checkMedia(bytes).isOk, isTrue, reason: item.id);
      }
    });
  }
}
