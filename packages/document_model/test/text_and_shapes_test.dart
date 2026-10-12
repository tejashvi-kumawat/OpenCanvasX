import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

void main() {
  group('TextPayload', () {
    test('has documented defaults', () {
      final t = TextPayload('Hi');
      expect(t.fontFamily, isNull);
      expect(t.fontSize, 24);
      expect(t.fontWeight, 400);
      expect(t.italic, isFalse);
      expect(t.align, TextAlignment.left);
      expect(t.lineHeight, 1.2);
      expect(t.letterSpacing, 0);
      expect(t.sizing, TextSizing.autoWidth);
    });

    test('rejects invalid formatting', () {
      expect(() => TextPayload('x', fontSize: 0), throwsArgumentError);
      expect(() => TextPayload('x', fontWeight: 450), throwsArgumentError);
      expect(() => TextPayload('x', fontWeight: 1000), throwsArgumentError);
      expect(() => TextPayload('x', lineHeight: -1), throwsArgumentError);
      expect(
        () => TextPayload('x', letterSpacing: double.nan),
        throwsArgumentError,
      );
    });

    test('blank font family means default', () {
      expect(TextPayload('x', fontFamily: '  ').fontFamily, isNull);
    });

    test('copyWith keeps and clears fields', () {
      final t = TextPayload('Hi', fontFamily: 'Georgia', fontSize: 40);
      final bold = t.copyWith(fontWeight: 700);
      expect(
        (bold.fontFamily, bold.fontSize, bold.fontWeight),
        ('Georgia', 40.0, 700),
      );
      expect(t.copyWith(fontFamily: null).fontFamily, isNull);
      expect(t.copyWith(text: 'Yo').text, 'Yo');
    });
  });

  group('polygon and star', () {
    test('validate their parameters', () {
      expect(PolygonPayload().sides, 6);
      expect(() => PolygonPayload(sides: 2), throwsRangeError);
      expect(StarPayload().points, 5);
      expect(() => StarPayload(points: 2), throwsRangeError);
      expect(() => StarPayload(innerRatio: 0), throwsArgumentError);
      expect(() => StarPayload(innerRatio: 1.5), throwsArgumentError);
    });

    test('fit only their own type', () {
      expect(PolygonPayload().fits(ObjectType.polygon), isTrue);
      expect(PolygonPayload().fits(ObjectType.star), isFalse);
      expect(StarPayload().fits(ObjectType.star), isTrue);
      expect(const NoPayload().fits(ObjectType.polygon), isFalse);
    });
  });

  test('stroke dash defaults to solid and copies', () {
    final s = Stroke(color: ArgbColor.black, width: 2);
    expect(s.dash, StrokeDash.solid);
    expect(s.copyWith(dash: StrokeDash.dashed), isNot(s));
    expect(s.copyWith(dash: StrokeDash.dashed).width, 2);
  });

  group('JSON', () {
    const page = PageId('p');
    DesignObject object(
      String id,
      ObjectType type,
      ObjectPayload payload, {
      ObjectStyle? style,
    }) => DesignObject(
      id: ObjectId(id),
      type: type,
      pageId: page,
      transform: ObjectTransform(width: 100, height: 40),
      payload: payload,
      style: style,
    );

    DesignDocument doc(List<DesignObject> objects) => DesignDocument(
      id: const DocumentId('d'),
      metadata: const DocumentMetadata(title: 'T'),
      pages: [
        DesignPage(
          id: page,
          width: 500,
          height: 500,
          objectIds: objects.map((o) => o.id),
        ),
      ],
      objects: {for (final o in objects) o.id: o},
    );

    DesignDocument roundTrip(DesignDocument d) => decodeDocument(
      manifest: encodeManifest(d),
      body: encodeDocumentBody(d),
    );

    test('round-trips text formatting, shapes and dashes', () {
      final d = doc([
        object(
          't',
          ObjectType.text,
          TextPayload(
            'Hello',
            fontFamily: 'Georgia',
            fontSize: 36,
            fontWeight: 700,
            italic: true,
            align: TextAlignment.center,
            lineHeight: 1.4,
            letterSpacing: 1.5,
            sizing: TextSizing.autoHeight,
          ),
        ),
        object('pg', ObjectType.polygon, PolygonPayload(sides: 8)),
        object('st', ObjectType.star, StarPayload(points: 7, innerRatio: 0.4)),
        object(
          'r',
          ObjectType.rect,
          const NoPayload(),
          style: ObjectStyle(
            stroke: Stroke(
              color: ArgbColor.black,
              width: 3,
              dash: StrokeDash.dotted,
            ),
          ),
        ),
      ]);
      expect(roundTrip(d), d);
      final body = encodeDocumentBody(d);
      final text = (body['objects']! as Map)['t'] as Map;
      expect((text['payload']! as Map)['sizing'], 'auto_height');
    });

    test('minimal text payload decodes with defaults', () {
      final d = decodeDocument(
        manifest: {'format_version': '1.0.0', 'document_id': 'd', 'title': 'T'},
        body: {
          'schema_version': 1,
          'pages': [
            {
              'id': 'p',
              'width': 10,
              'height': 10,
              'unit': 'px',
              'object_ids': ['t'],
            },
          ],
          'objects': {
            't': {
              'type': 'text',
              'page_id': 'p',
              'transform': {'width': 5, 'height': 5},
              'payload': {'text': 'Old file'},
            },
          },
        },
      );
      final payload = d.objects[const ObjectId('t')]!.payload as TextPayload;
      expect(payload.text, 'Old file');
      expect(payload.fontSize, 24);
      expect(payload.sizing, TextSizing.autoWidth);
    });

    test('invalid font weight is a format error with a path', () {
      expect(
        () => decodeDocument(
          manifest: {
            'format_version': '1.0.0',
            'document_id': 'd',
            'title': 'T',
          },
          body: {
            'schema_version': 1,
            'pages': [
              {
                'id': 'p',
                'width': 10,
                'height': 10,
                'unit': 'px',
                'object_ids': ['t'],
              },
            ],
            'objects': {
              't': {
                'type': 'text',
                'page_id': 'p',
                'transform': {'width': 5, 'height': 5},
                'payload': {'text': 'x', 'font_weight': 450},
              },
            },
          },
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('document.objects.t'),
          ),
        ),
      );
    });
  });
}
