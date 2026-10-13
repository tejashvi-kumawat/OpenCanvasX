import 'dart:io';

import 'package:asset_engine/asset_engine.dart';
import 'dart:typed_data';

import 'package:test/test.dart';

void main() {
  const fonts = '../asset_packs/assets/fonts';

  test('reads family names of bundled fonts', () {
    expect(fontFamilyNamesOfFile('$fonts/bebasneue/BebasNeue-Regular.ttf'), [
      'Bebas Neue',
    ]);
    final inter = Directory(
      '$fonts/inter',
    ).listSync().whereType<File>().firstWhere((f) => f.path.endsWith('.ttf'));
    expect(fontFamilyNamesOfFile(inter.path), ['Inter']);
  });

  test('rejects files that are not fonts', () {
    expect(
      fontFamilyNames(Uint8List.fromList('hello world, not a font'.codeUnits)),
      isEmpty,
    );
  });

  test('finds installed Windows fonts, including collections', () {
    final families = discoverSystemFontFamilies();
    expect(families, containsAll(['Arial', 'Segoe UI']));
    if (File(r'C:\Windows\Fonts\cambria.ttc').existsSync()) {
      expect(
        fontFamilyNamesOfFile(r'C:\Windows\Fonts\cambria.ttc'),
        containsAll(['Cambria', 'Cambria Math']),
      );
    }
  }, skip: !Platform.isWindows);
}
