import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

DesignDocument apply(DesignDocument doc, Change change) =>
    change.applyTo(doc).$1;

void main() {
  final hash = 'b' * 64;

  test('use as mask groups siblings with the bottom one as mask', () {
    final doc = documentWith([
      rect('shape', h: 100, type: ObjectType.ellipse),
      rect('photo', x: -20, y: -20, w: 200, h: 150),
    ]);
    final (change, id) = useAsMask(doc, const [
      ObjectId('photo'),
      ObjectId('shape'),
    ]);
    final after = apply(doc, change);
    final group = after.objects[id]!;
    expect(isMaskGroup(group), isTrue);
    expect(group.childIds.first, const ObjectId('shape'));
    expect(validatePages(after.pages, after.objects), isEmpty);
  });

  test('image frames are mask groups that cover-fit images', () {
    final objects = newImageFrame(
      id: const ObjectId('f'),
      maskId: const ObjectId('m'),
      pageId: page1,
      shape: ImageFrameShape.heart,
      center: const Point2D(500, 500),
      size: 200,
    );
    var doc = documentWith([objects.first], nested: [objects.last]);
    expect(validatePages(doc.pages, doc.objects), isEmpty);
    expect((objects.last.payload as PathPayload).viewWidth, 200);

    DesignObject image(String id, double w, double h) => DesignObject(
      id: ObjectId(id),
      type: ObjectType.image,
      pageId: page1,
      transform: ObjectTransform(width: w, height: h),
      payload: ImagePayload(hash),
    );
    final info = {hash: AssetInfo(mime: 'image/png', byteLength: 4)};
    doc = apply(
      doc,
      placeImageInFrame(
        doc,
        const ObjectId('f'),
        image('i1', 400, 200),
        assets: info,
      ),
    );
    final placed = doc.objects[const ObjectId('i1')]!;
    // Wide image: height matches the frame, width overflows and is centred.
    expect(placed.transform.height, 200);
    expect(placed.transform.width, 400);
    expect(placed.transform.x, -100);
    expect(doc.objects[const ObjectId('f')]!.childIds, const [
      ObjectId('m'),
      ObjectId('i1'),
    ]);
    // A second image replaces the first.
    doc = apply(
      doc,
      placeImageInFrame(doc, const ObjectId('f'), image('i2', 100, 300)),
    );
    expect(doc.objects.containsKey(const ObjectId('i1')), isFalse);
    expect(doc.objects[const ObjectId('i2')]!.transform.width, 200);
    expect(validatePages(doc.pages, doc.objects), isEmpty);
  });

  test('colour matrices', () {
    expect(colorMatrixFor(ImageAdjustments.none), [
      1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, //
    ]);
    final grey = colorMatrixFor(ImageAdjustments(grayscale: 100));
    // Every output channel uses the same luminance weights.
    expect(grey.sublist(0, 3), grey.sublist(5, 8));
    expect(grey.sublist(0, 3), grey.sublist(10, 13));
    final bright = colorMatrixFor(ImageAdjustments(brightness: 100));
    expect(bright[4], closeTo(102, 0.01));
    expect(imageFilterPresets.keys, contains('Mono'));
  });
}
