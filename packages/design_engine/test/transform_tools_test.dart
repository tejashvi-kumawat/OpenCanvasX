import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

Matcher closeToPoint(Point2D expected) => isA<Point2D>()
    .having((p) => p.x, 'x', closeTo(expected.x, 1e-6))
    .having((p) => p.y, 'y', closeTo(expected.y, 1e-6));

Point2D corner(ObjectTransform t, ResizeHandle h) =>
    localToParent(t).apply(h.position(t.width, t.height));

void main() {
  final box = ObjectTransform(x: 100, y: 100, width: 200, height: 100);

  group('resizeTransform', () {
    test('bottom-right drag grows the box, top-left stays', () {
      final r = resizeTransform(
        box,
        ResizeHandle.bottomRight,
        const Point2D(350, 260),
      );
      expect((r.width, r.height), (250.0, 160.0));
      expect((r.x, r.y), (100.0, 100.0));
    });

    test('top-left drag keeps the bottom-right corner fixed', () {
      final r = resizeTransform(
        box,
        ResizeHandle.topLeft,
        const Point2D(50, 80),
      );
      expect((r.width, r.height), (250.0, 120.0));
      expect(
        corner(r, ResizeHandle.bottomRight),
        closeToPoint(const Point2D(300, 200)),
      );
    });

    test('edge handles change one dimension only', () {
      final r = resizeTransform(
        box,
        ResizeHandle.right,
        const Point2D(400, 999),
      );
      expect((r.width, r.height), (300.0, 100.0));
      final l = resizeTransform(box, ResizeHandle.top, const Point2D(-999, 50));
      expect((l.width, l.height), (200.0, 150.0));
      expect(l.y, 50);
    });

    test('keeps the aspect ratio on corners when asked', () {
      final r = resizeTransform(
        box,
        ResizeHandle.bottomRight,
        const Point2D(500, 150),
        keepAspectRatio: true,
      );
      expect(r.width / r.height, closeTo(2, 1e-9));
      expect(r.width, 400);
    });

    test('clamps to the minimum size instead of inverting', () {
      final r = resizeTransform(
        box,
        ResizeHandle.right,
        const Point2D(0, 150),
        minSize: 4,
      );
      expect(r.width, 4);
      expect(r.x, 100);
    });

    test('rotated boxes keep the opposite corner fixed in page space', () {
      final rotated = box.copyWith(rotation: 30);
      final fixedBefore = corner(rotated, ResizeHandle.topLeft);
      final dragged = localToParent(rotated).apply(const Point2D(260, 130));
      final r = resizeTransform(rotated, ResizeHandle.bottomRight, dragged);
      expect(r.width, closeTo(260, 1e-9));
      expect(r.height, closeTo(130, 1e-9));
      expect(corner(r, ResizeHandle.topLeft), closeToPoint(fixedBefore));
    });

    test('a zero-height line stays flat when its end is dragged', () {
      final line = ObjectTransform(width: 100, height: 0);
      final r = resizeTransform(
        line,
        ResizeHandle.right,
        const Point2D(150, 0),
      );
      expect((r.width, r.height), (150.0, 0.0));
    });
  });

  group('rotateTransform', () {
    test('pointing right of the centre is 90°', () {
      final r = rotateTransform(box, const Point2D(500, 150));
      expect(r.rotation, closeTo(90, 1e-9));
      expect((r.x, r.y), (box.x, box.y));
    });

    test('pointing straight up is 0° and snaps', () {
      expect(
        rotateTransform(box, const Point2D(200, 0)).rotation,
        closeTo(0, 1e-9),
      );
      expect(
        rotateTransform(box, const Point2D(290, 0), snapDegrees: 15).rotation,
        30,
      );
    });

    test('normalizeDegrees maps into (-180, 180]', () {
      expect(normalizeDegrees(270), -90);
      expect(normalizeDegrees(-180), 180);
      expect(normalizeDegrees(720), 0);
    });
  });

  test('flipTransform mirrors in place', () {
    final rotated = box.copyWith(rotation: 20);
    final h = flipTransform(rotated, horizontal: true);
    expect(h.scaleX, -1);
    expect(
      boundsInParent(h).center,
      closeToPoint(boundsInParent(rotated).center),
    );
    final v = flipTransform(box, horizontal: false);
    expect(v.scaleY, -1);
    expect((v.x, v.y), (box.x, box.y));
  });
}
