import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

const _hash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

DesignObject _image({double rotation = 0}) => DesignObject(
  id: const ObjectId('img'),
  pageId: const PageId('p'),
  type: ObjectType.image,
  transform: ObjectTransform(
    x: 100,
    y: 100,
    width: 200,
    height: 100,
    rotation: rotation,
  ),
  payload: ImagePayload(_hash),
);

Rect2D _crop(DesignObject o) => (o.payload as ImagePayload).crop;

void _near(double a, double b) => expect(a, closeTo(b, 1e-6));

void main() {
  test('dragging the right edge in crops and keeps the image in place', () {
    final cropped = cropImage(
      _image(),
      ResizeHandle.right,
      const Point2D(250, 150),
    );
    _near(cropped.transform.width, 150);
    _near(cropped.transform.x, 100);
    _near(_crop(cropped).width, 0.75);
    // The full image still starts at x = 100.
    _near(fullImageRect(cropped).width, 200);
  });

  test('the left edge moves the box and stops at the image edge', () {
    final cropped = cropImage(
      _image(),
      ResizeHandle.left,
      const Point2D(150, 150),
    );
    _near(cropped.transform.x, 150);
    _near(cropped.transform.width, 150);
    _near(_crop(cropped).left, 0.25);
    // Dragging outward past the image is clamped to the full image.
    final back = cropImage(cropped, ResizeHandle.left, const Point2D(0, 150));
    _near(back.transform.x, 100);
    _near(_crop(back).left, 0);
  });

  test('pan moves the image under the box within its edges', () {
    final cropped = cropImage(
      _image(),
      ResizeHandle.right,
      const Point2D(200, 150),
    ); // shows the left half
    final panned = panCrop(cropped, const Point2D(-50, 0));
    _near(_crop(panned).left, 0.25);
    _near(panned.transform.x, cropped.transform.x);
    final far = panCrop(cropped, const Point2D(-1000, 0));
    _near(_crop(far).left, 0.5);
  });

  test('aspect presets and reset', () {
    final square = cropToAspect(_image(), 1);
    _near(square.transform.width, 100);
    _near(square.transform.height, 100);
    _near(square.transform.x, 150);
    _near(_crop(square).left, 0.25);
    final reset = resetCrop(square);
    _near(reset.transform.width, 200);
    _near(reset.transform.x, 100);
    expect(_crop(reset), ImagePayload.fullCrop);
  });

  test('rotated images crop along their own axes', () {
    final cropped = cropImage(
      _image(rotation: 90),
      ResizeHandle.bottom,
      // Rotated 90° about the centre (200, 150): local bottom points left.
      const Point2D(170, 150),
    );
    _near(cropped.transform.height, 80);
    _near(_crop(cropped).height, 0.8);
  });
}
