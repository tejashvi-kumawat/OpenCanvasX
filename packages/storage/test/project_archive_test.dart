import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:document_model/document_model.dart';
import 'package:storage/storage.dart';
import 'package:test/test.dart';

final _png = Uint8List.fromList(List.generate(64, (i) => i));
final _pngHash = sha256Hex(_png);

DesignDocument _doc({bool withImage = true}) {
  const page = PageId('p');
  return DesignDocument(
    id: const DocumentId('doc'),
    metadata: const DocumentMetadata(title: 'Card'),
    pages: [
      DesignPage(
        id: page,
        width: 100,
        height: 100,
        objectIds: [if (withImage) const ObjectId('img')],
      ),
    ],
    objects: {
      if (withImage)
        const ObjectId('img'): DesignObject(
          id: const ObjectId('img'),
          type: ObjectType.image,
          transform: ObjectTransform(width: 10, height: 10),
          pageId: page,
          payload: ImagePayload(_pngHash),
        ),
    },
    assets: {
      if (withImage)
        _pngHash: AssetInfo(mime: 'image/png', byteLength: _png.length),
    },
  );
}

/// Builds a raw ZIP with arbitrary members for hostile-input tests.
Uint8List _zip(Map<String, List<int>> members, {List<ArchiveFile>? extra}) {
  final archive = Archive();
  for (final MapEntry(:key, :value) in members.entries) {
    archive.add(ArchiveFile.bytes(key, value));
  }
  extra?.forEach(archive.add);
  return ZipEncoder().encodeBytes(archive);
}

Map<String, List<int>> _validMembers() {
  final doc = _doc(withImage: false);
  return {
    'manifest.json': utf8.encode(jsonEncode(encodeManifest(doc))),
    'document.json': utf8.encode(jsonEncode(encodeDocumentBody(doc))),
  };
}

Matcher _formatError(String fragment) => throwsA(
  isA<FormatException>().having(
    (e) => e.message,
    'message',
    contains(fragment),
  ),
);

void main() {
  test('extension is .opencanvasx', () {
    expect(projectFileExtension, '.opencanvasx');
  });

  test('round-trips document and asset bytes', () {
    final doc = _doc();
    final bytes = encodeProject(doc, assets: {_pngHash: _png});
    final opened = decodeProject(bytes);
    expect(opened.document, doc);
    expect(opened.assets[_pngHash], _png);
    expect(opened.missingAssets, isEmpty);
    expect(opened.issues, isEmpty);
  });

  test('writes the documented container layout', () {
    final bytes = encodeProject(
      _doc(),
      assets: {_pngHash: _png},
      appVersion: '0.0.1',
    );
    final names = ZipDecoder().decodeBytes(bytes).map((f) => f.name).toSet();
    expect(names, {
      'manifest.json',
      'document.json',
      'fonts.json',
      'assets/sha256/$_pngHash',
    });
  });

  test('stores human-readable JSON', () {
    final archive = ZipDecoder().decodeBytes(encodeProject(_doc()));
    final manifest = utf8.decode(archive.findFile('manifest.json')!.content);
    expect(manifest, contains('\n  "format_version": "1.0.0"'));
  });

  test('reports missing asset bytes instead of failing', () {
    final opened = decodeProject(encodeProject(_doc()));
    expect(opened.missingAssets, [_pngHash]);
    expect(opened.assets, isEmpty);
  });

  test('rejects asset bytes that do not match their hash on save', () {
    expect(
      () => encodeProject(_doc(), assets: {_pngHash: Uint8List(3)}),
      throwsArgumentError,
    );
  });

  test('rejects a tampered asset on open', () {
    final doc = _doc();
    final tampered = Uint8List.fromList(_png)..[0] = 255;
    final bytes = _zip({
      'manifest.json': utf8.encode(jsonEncode(encodeManifest(doc))),
      'document.json': utf8.encode(jsonEncode(encodeDocumentBody(doc))),
      'assets/sha256/$_pngHash': tampered,
    });
    expect(() => decodeProject(bytes), _formatError('corrupt or was modified'));
  });

  test('reports cross-reference issues without failing', () {
    final members = _validMembers();
    final body =
        jsonDecode(utf8.decode(members['document.json']!))
            as Map<String, Object?>;
    (body['pages']! as List).add({
      'id': 'p',
      'width': 1,
      'height': 1,
      'unit': 'px',
    });
    members['document.json'] = utf8.encode(jsonEncode(body));
    final opened = decodeProject(_zip(members));
    expect(opened.issues.single.message, 'duplicate page id');
  });

  group('hostile input', () {
    test('not a zip', () {
      expect(
        () => decodeProject(Uint8List.fromList(utf8.encode('hello'))),
        _formatError('Not a valid .opencanvasx file'),
      );
    });

    test('file larger than the limit', () {
      expect(
        () => decodeProject(
          encodeProject(_doc()),
          limits: const ArchiveLimits(maxArchiveBytes: 10),
        ),
        _formatError('larger than'),
      );
    });

    test('path traversal and absolute names', () {
      for (final name in [
        '../evil.txt',
        'assets/../../evil',
        '/etc/passwd',
        'C:/evil',
      ]) {
        final members = _validMembers()..[name] = [1];
        expect(
          () => decodeProject(_zip(members)),
          _formatError('Unsafe entry name'),
          reason: name,
        );
      }
    });

    test('backslash names written by other tools', () {
      // package:archive normalises "\\" to "/" when writing, so patch the
      // name bytes afterwards to simulate a hostile third-party ZIP.
      final bytes = _zip(_validMembers()..['assets/evil'] = [1]);
      final from = utf8.encode('assets/evil');
      final to = utf8.encode(r'assets\evil');
      var patched = 0;
      for (var i = 0; i + from.length <= bytes.length; i++) {
        var match = true;
        for (var j = 0; j < from.length && match; j++) {
          match = bytes[i + j] == from[j];
        }
        if (match) {
          bytes.setRange(i, i + to.length, to);
          patched++;
        }
      }
      expect(patched, 2); // local header + central directory
      expect(() => decodeProject(bytes), _formatError('Unsafe entry name'));
    });

    test('deeply nested names', () {
      final members = _validMembers()..['a/b/c/d/e/f/g/h/i/j'] = [1];
      expect(() => decodeProject(_zip(members)), _formatError('Unsafe'));
    });

    test('symbolic links', () {
      // Unix file type 0xA000 in the mode bits marks a symlink entry.
      final link = ArchiveFile.bytes('assets/link', utf8.encode('/etc/passwd'))
        ..mode = 0xA1FF;
      final bytes = _zip(_validMembers(), extra: [link]);
      // package:archive always writes "made by MS-DOS", which hides the mode
      // bits; mark every central directory entry as made on Unix (OS 3),
      // as a zip created on Linux or macOS would be.
      for (var i = 0; i + 6 <= bytes.length; i++) {
        if (bytes[i] == 0x50 &&
            bytes[i + 1] == 0x4b &&
            bytes[i + 2] == 0x01 &&
            bytes[i + 3] == 0x02) {
          bytes[i + 5] = 3;
        }
      }
      expect(() => decodeProject(bytes), _formatError('Symbolic links'));
    });

    test('too many entries', () {
      final members = _validMembers();
      for (var i = 0; i < 5; i++) {
        members['meta/thumbnails/$i.png'] = [i];
      }
      expect(
        () => decodeProject(
          _zip(members),
          limits: const ArchiveLimits(maxEntries: 4),
        ),
        _formatError('more than 4 entries'),
      );
    });

    test('entry that expands beyond the per-entry limit', () {
      final members =
          _validMembers()
            ..['meta/big.bin'] = Uint8List(100000); // compresses to ~100 bytes
      expect(
        () => decodeProject(
          _zip(members),
          limits: const ArchiveLimits(maxEntryBytes: 50000),
        ),
        _formatError('Entry too large'),
      );
    });

    test('members that together exceed the total limit', () {
      final members =
          _validMembers()
            ..['meta/a.bin'] = Uint8List(30000)
            ..['meta/b.bin'] = Uint8List(30000);
      expect(
        () => decodeProject(
          _zip(members),
          limits: const ArchiveLimits(maxTotalBytes: 50000),
        ),
        _formatError('beyond the size limit'),
      );
    });

    test('oversized JSON', () {
      expect(
        () => decodeProject(
          _zip(_validMembers()),
          limits: const ArchiveLimits(maxJsonBytes: 20),
        ),
        _formatError('too large'),
      );
    });

    test('missing or invalid JSON members', () {
      expect(
        () => decodeProject(_zip(_validMembers()..remove('document.json'))),
        _formatError('Missing document.json'),
      );
      expect(
        () => decodeProject(
          _zip(_validMembers()..['manifest.json'] = utf8.encode('{nope')),
        ),
        _formatError('manifest.json is not valid JSON'),
      );
    });

    test('unknown members are ignored for forward compatibility', () {
      final members = _validMembers()..['snapshots/v1/document.json'] = [1];
      expect(decodeProject(_zip(members)).document.pages, hasLength(1));
    });
  });

  test('fonts.json lists the families the text uses', () {
    final page = DesignPage(id: const PageId('p'), width: 10, height: 10);
    DesignObject text(String id, String? family) => DesignObject(
      id: ObjectId(id),
      type: ObjectType.text,
      pageId: page.id,
      transform: ObjectTransform(width: 10, height: 10),
      payload: TextPayload('Hi', fontFamily: family),
    );
    final doc = DesignDocument(
      id: const DocumentId('d'),
      metadata: const DocumentMetadata(title: 'f'),
      pages: [
        page.copyWith(
          objectIds: const [ObjectId('a'), ObjectId('b'), ObjectId('c')],
        ),
      ],
      objects: {
        const ObjectId('a'): text('a', 'Lora'),
        const ObjectId('b'): text('b', null),
        const ObjectId('c'): text('c', 'Inter'),
      },
    );
    expect(usedFontFamilies(doc), ['Inter', 'Lora']);
  });
}
