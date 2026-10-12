import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  test('changes add and remove asset entries, with an exact inverse', () {
    final doc = documentWith(const []);
    final image = newImage(
      id: const ObjectId('i'),
      pageId: page1,
      assetHash:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      width: 200,
      height: 100,
      center: const Point2D(500, 500),
      tint: ArgbColor.black,
    );
    final change = Change(
      label: 'Add image',
      objects: {image.id: image},
      pages: [
        doc.pages.first.copyWith(objectIds: [image.id]),
        doc.pages.last,
      ],
      assets: {
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa':
            AssetInfo(mime: 'image/svg+xml', byteLength: 10),
      },
    );
    expect(change.isEmpty, isFalse);
    final (after, inverse) = change.applyTo(doc);
    expect(after.assets.keys, [
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    ]);
    expect(after.objects[image.id]!.transform.x, 400);
    expect(
      after.objects[image.id]!.style!.fill,
      const SolidFill(ArgbColor.black),
    );
    expect(validatePages(after.pages, after.objects), isEmpty);
    final (back, _) = inverse.applyTo(after);
    expect(back, doc);
    expect(
      Change(
        label: 'x',
        assets: const {
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa':
              null,
        },
      ).isEmpty,
      isFalse,
    );
  });
}
