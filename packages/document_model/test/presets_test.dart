import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

void main() {
  test('preset ids are unique and sizes positive', () {
    final ids = pagePresets.map((p) => p.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    for (final p in pagePresets) {
      expect(p.width, greaterThan(0), reason: p.id);
      expect(p.height, greaterThan(0), reason: p.id);
    }
  });

  test('every category has presets', () {
    for (final category in PresetCategory.values) {
      expect(
        pagePresets.where((p) => p.category == category),
        isNotEmpty,
        reason: category.name,
      );
    }
  });

  test('sizeLabel formats whole and fractional sizes', () {
    expect(presetById('instagram_post')!.sizeLabel, '1080 × 1080 px');
    expect(presetById('us_letter')!.sizeLabel, '8.5 × 11 in');
  });

  test('createPage uses screen DPI for pixels and 300 DPI for print', () {
    final post = presetById('instagram_post')!.createPage(const PageId('a'));
    expect(
      (post.width, post.height, post.unit, post.dpi),
      (1080.0, 1080.0, LengthUnit.px, defaultDpi),
    );
    final a4 = presetById('a4')!.createPage(const PageId('b'));
    expect((a4.unit, a4.dpi), (LengthUnit.mm, 300.0));
  });

  test('presetById returns null for unknown ids', () {
    expect(presetById('nope'), isNull);
  });
}
