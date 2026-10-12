import 'package:document_model/document_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renderer/renderer.dart';

void main() {
  const pageId = PageId('p');
  final rect = DesignObject(
    id: const ObjectId('r'),
    type: ObjectType.rect,
    pageId: pageId,
    transform: ObjectTransform(x: 50, width: 50, height: 100),
    style: ObjectStyle(fill: SolidFill(ArgbColor(0xFFFF0000))),
  );
  final doc = DesignDocument(
    id: const DocumentId('d'),
    metadata: const DocumentMetadata(title: 'x'),
    pages: [
      DesignPage(
        id: pageId,
        width: 100,
        height: 100,
        objectIds: const [ObjectId('r')],
      ),
    ],
    objects: {rect.id: rect},
  );

  testWidgets('renders a region at the requested pixel size', (tester) async {
    await tester.runAsync(() async {
      final image = await renderRegion(
        doc,
        doc.pages.single,
        region: Rect2D.fromLTWH(0, 0, 100, 100),
        roots: doc.pages.single.objectIds,
        background: true,
        width: 20,
        height: 20,
      );
      expect((image.width, image.height), (20, 20));
      final rgba = await imageRgba(image);
      int pixel(int x, int y) => (y * 20 + x) * 4;
      // Left half: white page; right half: the red rectangle.
      expect(rgba.sublist(pixel(2, 10), pixel(2, 10) + 4), [
        255,
        255,
        255,
        255,
      ]);
      expect(rgba.sublist(pixel(17, 10), pixel(17, 10) + 4), [255, 0, 0, 255]);

      final transparent = await renderRegion(
        doc,
        doc.pages.single,
        region: Rect2D.fromLTWH(0, 0, 100, 100),
        roots: doc.pages.single.objectIds,
        background: false,
        width: 20,
        height: 20,
      );
      final clear = await imageRgba(transparent);
      expect(clear[pixel(2, 10) + 3], 0);
      expect((await imagePng(transparent)).sublist(1, 4), 'PNG'.codeUnits);
    });
  });

  test('textLines follows explicit and wrapped lines', () {
    DesignObject text(
      String value, {
      TextSizing sizing = TextSizing.autoWidth,
      double width = 1000,
    }) => DesignObject(
      id: const ObjectId('t'),
      type: ObjectType.text,
      pageId: pageId,
      transform: ObjectTransform(width: width, height: 20),
      payload: TextPayload(value, fontSize: 10, sizing: sizing),
    );
    expect(textLines(text('one\ntwo')), ['one', 'two']);
    expect(textLines(text('end\n')), ['end', '']);
    expect(textLines(text('')), ['']);
    final wrapped = textLines(
      text('alpha beta gamma delta', sizing: TextSizing.autoHeight, width: 120),
    );
    expect(wrapped.length, greaterThan(1));
    expect(
      wrapped.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
      'alpha beta gamma delta',
    );
  });

  testWidgets('linear gradients run along their angle', (tester) async {
    await tester.runAsync(() async {
      final g = DesignObject(
        id: const ObjectId('g'),
        type: ObjectType.rect,
        pageId: pageId,
        transform: ObjectTransform(width: 100, height: 100),
        style: ObjectStyle(
          fill: LinearGradientFill([
            GradientStop(0, ArgbColor(0xFFFF0000)),
            GradientStop(1, ArgbColor(0xFF0000FF)),
          ], angle: 0),
        ),
      );
      final gd = DesignDocument(
        id: const DocumentId('g'),
        metadata: const DocumentMetadata(title: 'g'),
        pages: [
          doc.pages.single.copyWith(objectIds: [g.id]),
        ],
        objects: {g.id: g},
      );
      final rgba = await imageRgba(
        await renderRegion(
          gd,
          gd.pages.single,
          region: Rect2D.fromLTWH(0, 0, 100, 100),
          roots: [g.id],
          background: false,
          width: 20,
          height: 20,
        ),
      );
      int at(int x) => (10 * 20 + x) * 4;
      expect(rgba[at(1)], greaterThan(200)); // red on the left
      expect(rgba[at(1) + 2], lessThan(60));
      expect(rgba[at(18) + 2], greaterThan(200)); // blue on the right
      expect(rgba[at(18)], lessThan(60));
    });
  });
}
