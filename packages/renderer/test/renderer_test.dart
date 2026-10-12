import 'dart:ui' as ui;

import 'package:document_model/document_model.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renderer/renderer.dart';

const _page = PageId('p');

DesignObject _object(
  String id,
  ObjectType type, {
  ObjectStyle? style,
  String? styleId,
  ObjectPayload payload = const NoPayload(),
  double opacity = 1,
  ObjectBlendMode blend = ObjectBlendMode.normal,
  String? parent,
  List<String> children = const [],
}) => DesignObject(
  id: ObjectId(id),
  type: type,
  transform: ObjectTransform(x: 10, y: 10, width: 80, height: 40, rotation: 15),
  pageId: parent == null ? _page : null,
  parentId: parent == null ? null : ObjectId(parent),
  childIds: children.map(ObjectId.new),
  style: style,
  styleId: styleId,
  payload: payload,
  opacity: opacity,
  blendMode: blend,
);

DesignDocument _everything() {
  final roots = [
    _object(
      'rect',
      ObjectType.rect,
      style: ObjectStyle(
        fill: SolidFill(ArgbColor(0xFF336699)),
        stroke: Stroke(color: ArgbColor.black, width: 2),
      ),
      opacity: 0.5,
      blend: ObjectBlendMode.multiply,
    ),
    _object('rounded', ObjectType.roundedRect, styleId: 'brand'),
    _object(
      'ellipse',
      ObjectType.ellipse,
      style: ObjectStyle(fill: const SolidFill(ArgbColor.white)),
    ),
    _object(
      'line',
      ObjectType.line,
      style: ObjectStyle(stroke: Stroke(color: ArgbColor.black)),
    ),
    _object(
      'arrow',
      ObjectType.arrow,
      style: ObjectStyle(stroke: Stroke(color: ArgbColor.black, width: 3)),
    ),
    _object(
      'path',
      ObjectType.path,
      style: ObjectStyle(fill: const SolidFill(ArgbColor.black)),
      payload: PathPayload([
        MoveTo(0, 0),
        LineTo(10, 0),
        QuadTo(15, 5, 10, 10),
        CubicTo(5, 15, 0, 15, 0, 10),
        const ClosePath(),
      ]),
    ),
    _object(
      'text',
      ObjectType.text,
      style: ObjectStyle(fill: const SolidFill(ArgbColor.black)),
      payload: TextPayload(
        'Hello\nworld',
        fontWeight: 700,
        italic: true,
        align: TextAlignment.center,
        sizing: TextSizing.fixed,
      ),
    ),
    _object(
      'polygon',
      ObjectType.polygon,
      style: ObjectStyle(
        fill: const SolidFill(ArgbColor.black),
        stroke: Stroke(
          color: ArgbColor.white,
          width: 2,
          dash: StrokeDash.dashed,
        ),
      ),
      payload: PolygonPayload(sides: 5),
    ),
    _object(
      'star',
      ObjectType.star,
      style: ObjectStyle(
        stroke: Stroke(
          color: ArgbColor.black,
          width: 2,
          dash: StrokeDash.dotted,
        ),
      ),
      payload: StarPayload(),
    ),
    _object(
      'image',
      ObjectType.image,
      payload: ImagePayload(
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      ),
    ),
    _object('group', ObjectType.group, children: ['child']),
  ];
  final child = _object(
    'child',
    ObjectType.ellipse,
    parent: 'group',
    style: ObjectStyle(fill: const SolidFill(ArgbColor.black)),
  );
  return DesignDocument(
    id: const DocumentId('d'),
    metadata: const DocumentMetadata(title: 'All'),
    pages: [
      DesignPage(
        id: _page,
        width: 200,
        height: 100,
        background: const TransparentBackground(),
        objectIds: roots.map((o) => o.id),
      ),
    ],
    objects: {
      for (final o in [...roots, child]) o.id: o,
    },
    styles: {'brand': ObjectStyle(fill: SolidFill(ArgbColor(0xFFFF8800)))},
  );
}

void main() {
  test('paints every object type without errors', () {
    final doc = _everything();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paintPageBackground(canvas, doc.pages.single);
    paintPageContent(canvas, doc, doc.pages.single);
    final picture = recorder.endRecording();
    expect(picture.approximateBytesUsed, greaterThan(0));
    picture.dispose();
  });

  testWidgets('thumbnail painter draws the page colours', (tester) async {
    final doc = DesignDocument(
      id: const DocumentId('d'),
      metadata: const DocumentMetadata(title: 'Red'),
      pages: [
        DesignPage(
          id: _page,
          width: 100,
          height: 100,
          background: SolidBackground(ArgbColor(0xFFFF0000)),
        ),
      ],
    );
    final recorder = ui.PictureRecorder();
    PageThumbnailPainter(
      document: doc,
      page: doc.pages.single,
    ).paint(Canvas(recorder), const Size(10, 10));
    final image = await tester.runAsync(
      () => recorder.endRecording().toImage(10, 10),
    );
    final bytes = await tester.runAsync(() => image!.toByteData());
    expect(bytes!.getUint8(0), 255);
    expect(bytes.getUint8(1), 0);
    image!.dispose();
  });

  test('shouldRepaint only when document or page changes', () {
    final doc = _everything();
    final a = PageThumbnailPainter(document: doc, page: doc.pages.single);
    expect(
      a.shouldRepaint(
        PageThumbnailPainter(document: doc, page: doc.pages.single),
      ),
      isFalse,
    );
    expect(
      a.shouldRepaint(
        PageThumbnailPainter(document: _everything(), page: doc.pages.single),
      ),
      isTrue,
    );
  });

  group('effectiveStyle', () {
    test('inline fields override the shared style', () {
      final shared = ObjectStyle(
        fill: const SolidFill(ArgbColor.white),
        stroke: Stroke(color: ArgbColor.black),
        cornerRadius: 4,
      );
      final object = _object(
        'o',
        ObjectType.rect,
        styleId: 's',
        style: ObjectStyle(fill: const SolidFill(ArgbColor.black)),
      );
      final style = effectiveStyle(object, {'s': shared});
      expect(style.fill, const SolidFill(ArgbColor.black));
      expect(style.stroke, shared.stroke);
      expect(style.cornerRadius, 4);
    });

    test('missing styles fall back to none', () {
      expect(
        effectiveStyle(_object('o', ObjectType.rect, styleId: 'gone'), {}),
        ObjectStyle.none,
      );
    });
  });

  test('rounded rectangles get a default radius capped at half the size', () {
    final o = _object('o', ObjectType.roundedRect);
    expect(cornerRadiusOf(o, ObjectStyle.none), closeTo(40 * 0.12, 1e-9));
    expect(cornerRadiusOf(o, ObjectStyle(cornerRadius: 999)), 20);
    expect(cornerRadiusOf(_object('r', ObjectType.rect), ObjectStyle.none), 0);
  });

  test('colour and blend conversion', () {
    expect(toUiColor(ArgbColor(0x80112233)), const Color(0x80112233));
    expect(toUiBlendMode(ObjectBlendMode.normal), BlendMode.srcOver);
    expect(toUiBlendMode(ObjectBlendMode.luminosity), BlendMode.luminosity);
  });

  group('text', () {
    test('auto width measures the natural size', () {
      final short = measureText(TextPayload('Hi', fontSize: 20));
      final long = measureText(TextPayload('Hello there', fontSize: 20));
      expect(long.x, greaterThan(short.x));
      expect(short.y, greaterThanOrEqualTo(20));
    });

    test('auto height wraps to the given width', () {
      final text = TextPayload(
        'a b c d e f g h i j k l m n o p',
        fontSize: 20,
        sizing: TextSizing.autoHeight,
      );
      final one = measureText(text.copyWith(sizing: TextSizing.autoWidth));
      final wrapped = measureText(text, width: one.x / 3);
      expect(wrapped.x, one.x / 3);
      expect(wrapped.y, greaterThan(one.y * 2));
    });

    test('empty text still has one line of height', () {
      expect(
        measureText(TextPayload('', fontSize: 30)).y,
        greaterThanOrEqualTo(30),
      );
    });
  });

  test('shapePath covers closed shapes only', () {
    const style = ObjectStyle.none;
    expect(shapePath(_object('r', ObjectType.rect), style), isNotNull);
    expect(
      shapePath(
        _object('p', ObjectType.polygon, payload: PolygonPayload()),
        style,
      )!.getBounds().width,
      closeTo(80 * 0.866, 0.5),
    );
    expect(shapePath(_object('l', ObjectType.line), style), isNull);
  });
}
