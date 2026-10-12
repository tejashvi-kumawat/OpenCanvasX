import 'dart:convert';

import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

const _hash =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

DesignDocument sampleDocument() {
  const p1 = PageId('p1');
  const p2 = PageId('p2');
  final box = ObjectTransform(width: 100, height: 50, x: 10, y: 20);
  final objects = [
    DesignObject(
      id: const ObjectId('group'),
      type: ObjectType.group,
      transform: box,
      pageId: p1,
      childIds: const [ObjectId('rect'), ObjectId('text')],
      name: 'Header',
    ),
    DesignObject(
      id: const ObjectId('rect'),
      type: ObjectType.roundedRect,
      transform: box.copyWith(rotation: 15, scaleX: -1, anchorX: 0),
      parentId: const ObjectId('group'),
      opacity: 0.5,
      blendMode: ObjectBlendMode.colorDodge,
      locked: true,
      style: ObjectStyle(
        fill: SolidFill(ArgbColor(0x80112233)),
        stroke: Stroke(color: ArgbColor.black, width: 2),
        cornerRadius: 8,
      ),
    ),
    DesignObject(
      id: const ObjectId('text'),
      type: ObjectType.text,
      transform: box,
      parentId: const ObjectId('group'),
      styleId: 'brand',
      payload: TextPayload('Hello "OpenCanvasX" ✓'),
    ),
    DesignObject(
      id: const ObjectId('photo'),
      type: ObjectType.image,
      transform: box,
      pageId: p1,
      hidden: true,
      payload: ImagePayload(_hash),
    ),
    DesignObject(
      id: const ObjectId('path'),
      type: ObjectType.path,
      transform: box,
      pageId: p2,
      payload: PathPayload([
        MoveTo(0, 0),
        LineTo(10, 0),
        QuadTo(15, 5, 10, 10),
        CubicTo(5, 15, 0, 15, 0, 10),
        const ClosePath(),
      ]),
    ),
  ];
  return DesignDocument(
    id: const DocumentId('doc-1'),
    metadata: DocumentMetadata(
      title: 'Poster',
      author: 'Nikita',
      createdAt: DateTime.utc(2026, 10, 1, 9, 30),
      modifiedAt: DateTime.utc(2026, 10, 12, 18),
    ),
    pages: [
      DesignPage(
        id: p1,
        name: 'Front',
        width: 210,
        height: 297,
        unit: LengthUnit.mm,
        dpi: 300,
        bleed: PageInsets.all(3),
        margins: PageInsets(top: 10, right: 12, bottom: 10, left: 12),
        guides: [
          Guide(GuideAxis.vertical, 105),
          Guide(GuideAxis.horizontal, -5),
        ],
        background: ImageBackground(_hash),
        objectIds: const [ObjectId('group'), ObjectId('photo')],
      ),
      DesignPage(
        id: p2,
        width: 1080,
        height: 1080,
        background: const TransparentBackground(),
        objectIds: const [ObjectId('path')],
      ),
    ],
    objects: {for (final o in objects) o.id: o},
    styles: {'brand': ObjectStyle(fill: const SolidFill(ArgbColor.white))},
    assets: {
      _hash: AssetInfo(mime: 'image/png', byteLength: 0, licenseRef: 'own'),
    },
  );
}

/// Simulates writing to disk and reading back.
DesignDocument roundTrip(DesignDocument doc) => decodeDocument(
  manifest: jsonDecode(jsonEncode(encodeManifest(doc))),
  body: jsonDecode(jsonEncode(encodeDocumentBody(doc))),
);

Map<String, Object?> minimalManifest() => {
  'format_version': currentFormatVersion,
  'document_id': 'd',
  'title': 'T',
};

Map<String, Object?> minimalBody({Map<String, Object?>? objects}) => {
  'schema_version': currentSchemaVersion,
  'pages': [
    {
      'id': 'p',
      'width': 100,
      'height': 100,
      'unit': 'px',
      'object_ids': [...?objects?.keys],
    },
  ],
  'objects': objects ?? {},
};

void main() {
  test('sample document is internally consistent', () {
    expect(sampleDocument().validate(), isEmpty);
  });

  test('round-trips every field through JSON text', () {
    final doc = sampleDocument();
    final back = roundTrip(doc);
    expect(back, doc);
    expect(back.validate(), isEmpty);
    expect(back.metadata.createdAt, DateTime.utc(2026, 10, 1, 9, 30));
  });

  test('writes snake_case keys only', () {
    final json = {
      'manifest': encodeManifest(sampleDocument(), appVersion: '0.0.1'),
      'body': encodeDocumentBody(sampleDocument()),
    };
    final keys = <String>[];
    void collect(Object? v) {
      if (v is Map<String, Object?>) {
        for (final MapEntry(:key, :value) in v.entries) {
          keys.add(key);
          collect(value);
        }
      } else if (v is List<Object?>) {
        v.forEach(collect);
      }
    }

    collect(json);
    final camel = keys.where((k) => RegExp('[A-Z]').hasMatch(k));
    expect(camel, isEmpty);
    expect(
      keys,
      containsAll([
        'format_version',
        'document_id',
        'app_version_saved',
        'schema_version',
        'asset_index',
        'object_ids',
        'child_ids',
        'blend_mode',
        'scale_x',
        'corner_radius',
        'byte_length',
      ]),
    );
  });

  test('uses snake_case enum values and css colours', () {
    final body = encodeDocumentBody(sampleDocument());
    final objects = body['objects']! as Map<String, Object?>;
    final rect = objects['rect']! as Map<String, Object?>;
    expect(rect['type'], 'rounded_rect');
    expect(rect['blend_mode'], 'color_dodge');
    final style = rect['style']! as Map<String, Object?>;
    expect((style['fill']! as Map)['color'], '#11223380');
    final page = (body['pages']! as List).first as Map<String, Object?>;
    expect(page['unit'], 'mm');
  });

  test('decodes minimal objects with documented defaults', () {
    final doc = decodeDocument(
      manifest: minimalManifest(),
      body: minimalBody(
        objects: {
          'r': {
            'type': 'rect',
            'page_id': 'p',
            'transform': {'width': 5, 'height': 6},
          },
        },
      ),
    );
    final r = doc.objects[const ObjectId('r')]!;
    expect(r.opacity, 1);
    expect(r.blendMode, ObjectBlendMode.normal);
    expect(r.transform.anchorX, 0.5);
    expect(doc.pages.single.dpi, defaultDpi);
    expect(doc.pages.single.background, const SolidBackground(ArgbColor.white));
    expect(doc.validate(), isEmpty);
  });

  test('accepts #rrggbb colours as opaque', () {
    final doc = decodeDocument(
      manifest: minimalManifest(),
      body:
          minimalBody()
            ..['pages'] = [
              {
                'id': 'p',
                'width': 1,
                'height': 1,
                'unit': 'px',
                'background': {'type': 'solid', 'color': '#ff0000'},
              },
            ],
    );
    expect(doc.pages.single.background, SolidBackground(ArgbColor(0xFFFF0000)));
  });

  group('rejects malformed files with a JSON path', () {
    void expectFormatError(
      Map<String, Object?> body,
      String pathFragment, {
      Object? manifest,
    }) {
      expect(
        () =>
            decodeDocument(manifest: manifest ?? minimalManifest(), body: body),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(pathFragment),
          ),
        ),
      );
    }

    Map<String, Object?> withObject(Map<String, Object?> object) =>
        minimalBody(objects: {'x': object});

    final box = {'width': 1, 'height': 1};

    test('unknown object type', () {
      expectFormatError(
        withObject({'type': 'hologram', 'page_id': 'p', 'transform': box}),
        'document.objects.x.type',
      );
    });

    test('invalid transform value', () {
      expectFormatError(
        withObject({
          'type': 'rect',
          'page_id': 'p',
          'transform': {'width': -1, 'height': 1},
        }),
        'document.objects.x.transform',
      );
    });

    test('wrong value type', () {
      expectFormatError(
        withObject({
          'type': 'rect',
          'page_id': 'p',
          'transform': box,
          'opacity': 'high',
        }),
        'document.objects.x.opacity',
      );
    });

    test('text object without payload', () {
      expectFormatError(
        withObject({'type': 'text', 'page_id': 'p', 'transform': box}),
        'document.objects.x.payload',
      );
    });

    test('bad path segment', () {
      expectFormatError(
        withObject({
          'type': 'path',
          'page_id': 'p',
          'transform': box,
          'payload': {
            'segments': [
              ['M', 0],
            ],
          },
        }),
        'segments[0]',
      );
    });

    test('bad colour', () {
      expectFormatError(
        withObject({
          'type': 'rect',
          'page_id': 'p',
          'transform': box,
          'style': {
            'fill': {'type': 'solid', 'color': 'red'},
          },
        }),
        'fill.color',
      );
    });

    test('unknown unit', () {
      expectFormatError(
        minimalBody()
          ..['pages'] = [
            {'id': 'p', 'width': 1, 'height': 1, 'unit': 'furlong'},
          ],
        'document.pages[0].unit',
      );
    });

    test('missing manifest field', () {
      expectFormatError(
        minimalBody(),
        'manifest.document_id',
        manifest: {'format_version': '1.0.0', 'title': 'T'},
      );
    });

    test('non-object roots', () {
      expect(
        () => decodeDocument(manifest: [], body: minimalBody()),
        throwsFormatException,
      );
      expect(
        () => decodeDocument(manifest: minimalManifest(), body: 'nope'),
        throwsFormatException,
      );
      expect(
        () => decodeDocument(
          manifest: minimalManifest(),
          body: minimalBody()..['objects'] = {1: 'numeric key'},
        ),
        throwsFormatException,
      );
    });
  });

  group('versions', () {
    test('rejects a newer schema with a clear message', () {
      expect(
        () => decodeDocument(
          manifest: minimalManifest(),
          body: minimalBody()..['schema_version'] = currentSchemaVersion + 1,
        ),
        throwsA(
          isA<UnsupportedVersionException>().having(
            (e) => e.toString(),
            'message',
            contains('newer version of OpenCanvasX'),
          ),
        ),
      );
    });

    test('rejects a newer container major version', () {
      expect(
        () => decodeDocument(
          manifest: minimalManifest()..['format_version'] = '2.0.0',
          body: minimalBody(),
        ),
        throwsA(isA<UnsupportedVersionException>()),
      );
    });

    test('accepts a newer container minor version', () {
      expect(
        decodeDocument(
          manifest: minimalManifest()..['format_version'] = '1.4.0',
          body: minimalBody(),
        ).pages,
        hasLength(1),
      );
    });

    test('runs migrations before decoding', () {
      final migrator = SchemaMigrator(
        currentVersion: 2,
        steps: {
          // v1 called the root list "page_list".
          1: (doc) => doc..['pages'] = doc.remove('page_list'),
        },
      );
      final v1 =
          minimalBody()
            ..['schema_version'] = 1
            ..['page_list'] = minimalBody()['pages']
            ..remove('pages');
      final doc = decodeDocument(
        manifest: minimalManifest(),
        body: v1,
        migrator: migrator,
      );
      expect(doc.pages.single.id, const PageId('p'));
    });
  });

  group('SchemaMigrator', () {
    test('applies steps in order and stamps each version', () {
      final seen = <int>[];
      final migrator = SchemaMigrator(
        currentVersion: 3,
        steps: {
          1: (d) {
            seen.add(d['schema_version']! as int);
            return d..['a'] = 1;
          },
          2: (d) {
            seen.add(d['schema_version']! as int);
            return d..['b'] = (d['a']! as int) + 1;
          },
        },
      );
      final out = migrator.migrate({'schema_version': 1});
      expect(seen, [1, 2]);
      expect(out, {'schema_version': 3, 'a': 1, 'b': 2});
    });

    test('does not mutate the input map', () {
      final input = <String, Object?>{'schema_version': 1};
      SchemaMigrator(
        currentVersion: 2,
        steps: {1: (d) => d..['x'] = true},
      ).migrate(input);
      expect(input, {'schema_version': 1});
    });

    test('current version passes through unchanged', () {
      final input = <String, Object?>{'schema_version': 1, 'k': 'v'};
      expect(SchemaMigrator(currentVersion: 1).migrate(input), input);
    });

    test('fails on a missing step or bad version field', () {
      expect(
        () => SchemaMigrator(currentVersion: 3).migrate({'schema_version': 1}),
        throwsStateError,
      );
      expect(
        () => SchemaMigrator(currentVersion: 1).migrate({'schema_version': 0}),
        throwsFormatException,
      );
      expect(
        () => SchemaMigrator(currentVersion: 1).migrate({}),
        throwsFormatException,
      );
    });
  });

  group('DesignDocument.validate', () {
    test('reports missing pages, styles and assets', () {
      final doc = sampleDocument();
      final broken = DesignDocument(
        id: doc.id,
        metadata: doc.metadata,
        pages: doc.pages,
        objects: doc.objects,
      );
      final messages = broken.validate().map((i) => i.toString());
      expect(messages, contains('text: style brand does not exist'));
      expect(
        messages,
        contains('photo: asset $_hash is not in the asset index'),
      );
      expect(messages, contains('p1: asset $_hash is not in the asset index'));

      final empty = DesignDocument(
        id: const DocumentId('e'),
        metadata: const DocumentMetadata(title: 'E'),
        pages: const [],
      );
      expect(empty.validate().single.message, 'document has no pages');
    });

    test('reports malformed asset keys', () {
      final doc = DesignDocument(
        id: const DocumentId('d'),
        metadata: const DocumentMetadata(title: 'D'),
        pages: [DesignPage(id: const PageId('p'), width: 1, height: 1)],
        assets: {'../../evil': AssetInfo(mime: 'image/png', byteLength: 1)},
      );
      expect(
        doc.validate().single.message,
        'asset key is not a SHA-256 hex digest',
      );
    });
  });

  test('DocumentId.generate is a UUID', () {
    expect(DocumentId.generate().value, hasLength(36));
  });
}
