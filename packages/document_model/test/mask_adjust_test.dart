import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

void main() {
  final hash = 'a' * 64;

  test('adjustments validate their ranges', () {
    expect(ImageAdjustments().isNone, isTrue);
    expect(() => ImageAdjustments(brightness: 101), throwsArgumentError);
    expect(() => ImageAdjustments(hue: -181), throwsArgumentError);
    expect(() => ImageAdjustments(blur: -1), throwsArgumentError);
    final a = ImageAdjustments(contrast: 20).withValue('blur', 5);
    expect((a.contrast, a.blur), (20.0, 5.0));
  });

  test('masks and adjusted images round-trip', () {
    const page = PageId('p');
    final mask = DesignObject(
      id: const ObjectId('m'),
      type: ObjectType.group,
      pageId: page,
      childIds: const [ObjectId('s'), ObjectId('i')],
      transform: ObjectTransform(width: 100, height: 100),
      payload: const MaskPayload(),
    );
    final shape = DesignObject(
      id: const ObjectId('s'),
      type: ObjectType.ellipse,
      parentId: const ObjectId('m'),
      transform: ObjectTransform(width: 100, height: 100),
    );
    final image = DesignObject(
      id: const ObjectId('i'),
      type: ObjectType.image,
      parentId: const ObjectId('m'),
      transform: ObjectTransform(width: 150, height: 100),
      payload: ImagePayload(
        hash,
        adjust: ImageAdjustments(saturation: -100, hue: 30, blur: 2),
      ),
    );
    final doc = DesignDocument(
      id: const DocumentId('d'),
      metadata: const DocumentMetadata(title: 'm'),
      pages: [
        DesignPage(id: page, width: 200, height: 200, objectIds: [mask.id]),
      ],
      objects: {mask.id: mask, shape.id: shape, image.id: image},
      assets: {hash: AssetInfo(mime: 'image/png', byteLength: 3)},
    );
    final body = encodeDocumentBody(doc);
    final objects = body['objects']! as Map;
    expect((objects['m'] as Map)['payload'], {'mask': true});
    expect(((objects['i'] as Map)['payload'] as Map)['adjust'], {
      'saturation': -100.0,
      'hue': 30.0,
      'blur': 2.0,
    });
    expect(decodeDocument(manifest: encodeManifest(doc), body: body), doc);
  });
}
