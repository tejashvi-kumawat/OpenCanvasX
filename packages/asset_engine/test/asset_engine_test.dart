import 'dart:convert';
import 'dart:typed_data';

import 'package:asset_engine/asset_engine.dart';
import 'package:test/test.dart';

Map<String, Object?> packJson({
  String id = 'demo',
  bool attribution = false,
  List<Map<String, Object?>>? items,
}) => {
  'id': id,
  'name': 'Demo',
  'kind': 'icon',
  'version': '1.0.0',
  'license': 'MIT',
  'license_url': 'https://example.org/license',
  'author': 'Someone',
  'source': 'https://example.org/demo.zip',
  'attribution_required': attribution,
  'attribution': attribution ? 'Demo by Someone, CC-BY 4.0' : null,
  'recolorable': true,
  'items':
      items ??
      [
        {
          'id': 'demo/heart',
          'name': 'Heart',
          'file': 'svg/heart.svg',
          'sha256': 'ab',
          'mime': 'image/svg+xml',
          'tags': ['love', 'like'],
          'category': 'shapes',
        },
        {
          'id': 'demo/heart-filled',
          'name': 'Heart filled',
          'file': 'svg/heart-filled.svg',
          'sha256': 'cd',
          'mime': 'image/svg+xml',
          'tags': ['love'],
          'category': 'shapes',
          'style': 'filled',
        },
        {
          'id': 'demo/home',
          'name': 'Home',
          'file': 'svg/home.svg',
          'sha256': 'ef',
          'mime': 'image/svg+xml',
          'tags': ['house', 'building'],
          'category': 'buildings',
        },
      ],
};

Uint8List bytes(List<int> b) => Uint8List.fromList(b);

void main() {
  group('AssetPack', () {
    test('parses pack.json with licence metadata', () {
      final pack = AssetPack.fromJson(packJson());
      expect(pack.items, hasLength(3));
      expect(pack.license.spdx, 'MIT');
      expect(pack.recolorable, isTrue);
      expect(pack.licenseRef, 'pack:demo@1.0.0');
      expect(pack.categories, ['shapes', 'buildings']);
      expect(pack.items[1].style, 'filled');
      expect(pack.items.first.isSvg, isTrue);
    });

    test('rejects packs without licence metadata', () {
      for (final key in ['license', 'license_url', 'author', 'source']) {
        final json = packJson()..remove(key);
        expect(() => AssetPack.fromJson(json), throwsFormatException);
      }
    });

    test('requires attribution text when attribution is required', () {
      final json = packJson(attribution: true)..['attribution'] = null;
      expect(() => AssetPack.fromJson(json), throwsFormatException);
      expect(
        AssetPack.fromJson(packJson(attribution: true)).license.attribution,
        contains('CC-BY'),
      );
    });

    test('rejects unsafe item paths and bad ids', () {
      final traversal = packJson(
        items: [
          {
            'id': 'x',
            'name': 'x',
            'file': '../secret.svg',
            'sha256': 'a',
            'mime': 'image/svg+xml',
          },
        ],
      );
      expect(() => AssetPack.fromJson(traversal), throwsFormatException);
      expect(
        () => AssetPack.fromJson(packJson(id: 'Bad Id')),
        throwsFormatException,
      );
    });
  });

  group('AssetCatalog', () {
    final catalog = AssetCatalog([AssetPack.fromJson(packJson())]);

    test('ranks exact names and prefixes first', () {
      expect(catalog.search('heart').map((i) => i.id), [
        'demo/heart',
        'demo/heart-filled',
      ]);
      expect(catalog.search('love').first.id, 'demo/heart');
      expect(catalog.search('hou').single.id, 'demo/home');
    });

    test('every word must match', () {
      expect(catalog.search('heart filled').single.id, 'demo/heart-filled');
      expect(catalog.search('heart house'), isEmpty);
    });

    test('filters by kind, pack, category and style', () {
      expect(catalog.search(''), hasLength(3));
      expect(catalog.search('', kind: AssetKind.sticker), isEmpty);
      expect(catalog.search('', category: 'buildings'), hasLength(1));
      expect(catalog.search('', style: 'filled'), hasLength(1));
      expect(catalog.search('', packId: 'other'), isEmpty);
      expect(catalog.search('', limit: 2), hasLength(2));
    });
  });

  group('checkMedia', () {
    test('reads PNG size from IHDR', () {
      final png = bytes([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
        0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52, //
        0, 0, 0x01, 0x00, 0, 0, 0x00, 0xC8, //
      ]);
      final check = checkMedia(png);
      expect((check.mime, check.width, check.height), ('image/png', 256, 200));
    });

    test('reads GIF, BMP and JPEG sizes', () {
      final gif = bytes([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 10, 0, 20, 0]);
      expect((checkMedia(gif).width, checkMedia(gif).height), (10, 20));

      final bmp =
          Uint8List(26)
            ..[0] = 0x42
            ..[1] = 0x4D
            ..[18] = 64
            ..[22] = 0xF0
            ..[23] = 0xFF
            ..[24] = 0xFF
            ..[25] = 0xFF; // height -16 (top-down)
      expect((checkMedia(bmp).width, checkMedia(bmp).height), (64, 16));

      final jpeg = bytes([
        0xFF, 0xD8, // SOI
        0xFF, 0xE0, 0, 4, 0, 0, // APP0, length 4
        0xFF, 0xC0, 0, 11, 8, 0x01, 0x2C, 0x01, 0x90, 3, 0, 0, 0, // SOF0
      ]);
      final j = checkMedia(jpeg);
      expect((j.mime, j.width, j.height), ('image/jpeg', 400, 300));
    });

    test('accepts clean SVG and reads its size', () {
      final svg = checkMedia(
        utf8.encode(
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 32"><path d="M0 0h24"/></svg>',
        ),
      );
      expect((svg.isSvg, svg.width, svg.height), (true, 24, 32));
      final sized = checkMedia(
        utf8.encode('<svg width="100px" height="50"></svg>'),
      );
      expect((sized.width, sized.height), (100, 50));
    });

    test('rejects hostile SVG', () {
      for (final body in [
        '<svg><script>alert(1)</script></svg>',
        '<svg onload="x()"></svg>',
        '<svg><a href="https://evil.example"/></svg>',
        '<svg><image xlink:href="file:///etc/passwd"/></svg>',
        '<!DOCTYPE svg [<!ENTITY x "y">]><svg></svg>',
        '<svg><foreignObject></foreignObject></svg>',
      ]) {
        expect(checkMedia(utf8.encode(body)).isOk, isFalse, reason: body);
      }
      expect(
        checkMedia(utf8.encode('<svg><use href="#a"/></svg>')).isOk,
        isTrue,
      );
    });

    test('rejects unknown and empty files', () {
      expect(checkMedia(Uint8List(0)).isOk, isFalse);
      expect(checkMedia(bytes([1, 2, 3, 4])).isOk, isFalse);
    });
  });
}
