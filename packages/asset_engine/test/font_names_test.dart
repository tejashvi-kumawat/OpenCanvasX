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

  test('faces carry weight and italic; bestFace picks the closest', () {
    final faces = [
      ...fontFacesOfFile(r'C:\Windows\Fonts\arial.ttf'),
      ...fontFacesOfFile(r'C:\Windows\Fonts\arialbd.ttf'),
      ...fontFacesOfFile(r'C:\Windows\Fonts\ariali.ttf'),
    ];
    expect(faces.map((f) => (f.family, f.weight, f.italic)), [
      ('Arial', 400, false),
      ('Arial', 700, false),
      ('Arial', 400, true),
    ]);
    expect(bestFace(faces, 'arial', weight: 800)!.weight, 700);
    expect(bestFace(faces, 'Arial', italic: true)!.italic, isTrue);
    expect(bestFace(faces, 'Arial', weight: 500)!.weight, 400);
    expect(bestFace(faces, 'Comic Sans'), isNull);
  }, skip: !File(r'C:\Windows\Fonts\arialbd.ttf').existsSync());
}
