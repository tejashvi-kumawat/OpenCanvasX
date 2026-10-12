import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storage/storage.dart';
import 'package:template_engine/template_engine.dart';

/// Every bundled template decodes, validates and matches its index entry
/// (P2.2.5).
void main() {
  final index = parseTemplateIndex(
    jsonDecode(File('assets/templates/index.json').readAsStringSync())
        as Map<String, Object?>,
  );

  test('the index lists every template file', () {
    final files = [
      for (final f
          in Directory('assets/templates').listSync().whereType<File>())
        if (f.path.endsWith('.opencanvasx')) f.uri.pathSegments.last,
    ]..sort();
    expect([for (final t in index) t.file]..sort(), files);
    expect(index.length, greaterThanOrEqualTo(20));
  });

  for (final info in index) {
    test('${info.id} is a valid design', () {
      final contents = decodeProject(
        File('assets/templates/${info.file}').readAsBytesSync(),
      );
      final doc = contents.document;
      expect(contents.missingAssets, isEmpty);
      expect(validateTemplate(doc), isEmpty);
      expect(doc.pages, hasLength(info.pages));
      expect(doc.pages.first.width, info.width);
      expect(info.license, isNotEmpty);
      expect(templateCategories.containsKey(info.category), isTrue);
      for (final asset in doc.assets.values) {
        expect(asset.licenseRef, startsWith('pack:'));
      }
    });
  }
}
