import 'dart:math' as math;

import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

Matcher closeToPoint(Point2D expected) => isA<Point2D>()
    .having((p) => p.x, 'x', closeTo(expected.x, 1e-6))
    .having((p) => p.y, 'y', closeTo(expected.y, 1e-6));

void main() {
  group('geometry', () {
    test('localToParent rotates around the centre by default', () {
      final t = ObjectTransform(
        width: 100,
        height: 50,
        rotation: 90,
      );
      final m = localToParent(t);
      expect(
        m.apply(const Point2D(50, 25)),
        closeToPoint(const Point2D(50, 25)),
      );
      // Top-left corner swings to the top-right of the rotated box.
      expect(m.apply(Point2D.zero), closeToPoint(const Point2D(75, -25)));
    });

    test('inverse undoes the matrix', () {
      final m = localToParent(
        ObjectTransform(
          x: 7,
          y: -3,
          width: 40,
          height: 10,
          rotation: 33,
          scaleX: -2,
        ),
      );
      const p = Point2D(12, 34);
      expect(m.inverse()!.apply(m.apply(p)), closeToPoint(p));
      expect(Affine2D.scale(0, 1).inverse(), isNull);
    });

    test('boundsInParent covers the rotated box', () {
      final b = boundsInParent(
        ObjectTransform(width: 100, height: 100, rotation: 45),
      );
      expect(b.width, closeTo(100 * math.sqrt2, 1e-9));
    });
  });

  group('world geometry', () {
    test('nested objects compose parent transforms', () {
      final doc = documentWith(
        [
          rect('g', x: 100, y: 100, children: ['c']),
        ],
        nested: [rect('c', parent: 'g', x: 10, y: 10, w: 20, h: 20)],
      );
      expect(
        worldCorners(doc, const ObjectId('c')).first,
        closeToPoint(const Point2D(110, 110)),
      );
      expect(
        worldBounds(doc, const ObjectId('c')),
        const Rect2D.fromLTRB(110, 110, 130, 130),
      );
    });

    test('selectionBounds unions and skips unknown ids', () {
      final doc = documentWith([
        rect('a', w: 10, h: 10),
        rect('b', x: 50, y: 60, w: 10, h: 10),
      ]);
      expect(
        selectionBounds(doc, [
          const ObjectId('a'),
          const ObjectId('b'),
          const ObjectId('ghost'),
        ]),
        const Rect2D.fromLTRB(0, 0, 60, 70),
      );
      expect(selectionBounds(doc, const []), isNull);
    });
  });

  group('hitTest', () {
    DesignObject at(String id, double x, {ObjectType type = ObjectType.rect}) =>
        rect(id, x: x, h: 100, type: type);

    test('returns the topmost object under the point', () {
      final doc = documentWith([at('back', 0), at('front', 50)]);
      final page = doc.pages.first;
      expect(
        hitTest(doc, page, const Point2D(75, 50)),
        const ObjectId('front'),
      );
      expect(hitTest(doc, page, const Point2D(25, 50)), const ObjectId('back'));
      expect(hitTest(doc, page, const Point2D(500, 500)), isNull);
    });

    test('skips hidden and locked objects', () {
      final doc = documentWith([
        at('base', 0),
        rect('hidden', h: 100, hidden: true),
        rect('locked', h: 100, locked: true),
      ]);
      expect(
        hitTest(doc, doc.pages.first, const Point2D(50, 50)),
        const ObjectId('base'),
      );
    });

    test('ellipses ignore their corners', () {
      final doc = documentWith([at('e', 0, type: ObjectType.ellipse)]);
      final page = doc.pages.first;
      expect(hitTest(doc, page, const Point2D(50, 50)), isNotNull);
      expect(hitTest(doc, page, const Point2D(3, 3)), isNull);
    });

    test('lines use distance to the segment with tolerance', () {
      final doc = documentWith([
        rect('l', y: 100, w: 200, h: 0, type: ObjectType.line),
      ]);
      final page = doc.pages.first;
      expect(hitTest(doc, page, const Point2D(100, 104)), isNull);
      expect(
        hitTest(doc, page, const Point2D(100, 104), tolerance: 5),
        const ObjectId('l'),
      );
    });

    test('rotated objects are hit in their rotated shape', () {
      final doc = documentWith([
        rect('r', w: 200, h: 20, rotation: 90),
      ]);
      final page = doc.pages.first;
      // After 90° about the centre (100, 10) the bar spans y -90…110.
      expect(hitTest(doc, page, const Point2D(100, -80)), isNotNull);
      expect(hitTest(doc, page, const Point2D(10, 10)), isNull);
    });

    test('clicking a group child selects the group', () {
      final doc = documentWith(
        [
          rect('g', w: 200, h: 200, children: ['c']),
        ],
        nested: [rect('c', parent: 'g', x: 10, y: 10, w: 20, h: 20)],
      );
      final page = doc.pages.first;
      expect(hitTest(doc, page, const Point2D(15, 15)), const ObjectId('g'));
      expect(hitTest(doc, page, const Point2D(150, 150)), isNull);
    });
  });

  test('objectsInRect selects overlapping visible roots', () {
    final doc = documentWith([
      rect('a', w: 10, h: 10),
      rect('b', x: 100, y: 100, w: 10, h: 10),
      rect('c', x: 5, y: 5, w: 10, h: 10, locked: true),
    ]);
    expect(
      objectsInRect(doc, doc.pages.first, const Rect2D.fromLTRB(-5, -5, 8, 8)),
      [const ObjectId('a')],
    );
  });
}
