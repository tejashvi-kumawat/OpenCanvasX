import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  const a = Point2D(100, 100);
  const b = Point2D(200, 100);
  const c = Point2D(200, 200);

  test('segments: lines without handles, cubics with them, optional close', () {
    final plain = segmentsFor([const PenAnchor(a), const PenAnchor(b)]);
    expect(plain, [MoveTo(100, 100), LineTo(200, 100)]);
    final curved = segmentsFor([
      PenAnchor.smooth(a, const Point2D(120, 80)),
      const PenAnchor(b),
      const PenAnchor(c),
    ], closed: true);
    expect(curved[1], CubicTo(120, 80, 200, 100, 200, 100));
    expect(curved.last, const ClosePath());
    expect(curved, hasLength(5));
  });

  test('newPathObject fits the box and stores a view box', () {
    final path = newPathObject(
      id: const ObjectId('p'),
      pageId: page1,
      anchors: const [PenAnchor(a), PenAnchor(b), PenAnchor(c)],
      closed: true,
    );
    final t = path.transform;
    expect((t.x, t.y, t.width, t.height), (100.0, 100.0, 100.0, 100.0));
    final payload = path.payload as PathPayload;
    expect((payload.viewWidth, payload.viewHeight), (100.0, 100.0));
    expect(payload.segments.first, MoveTo(0, 0));
  });

  test('anchors read back from segments (round trip, closing folded)', () {
    final anchors = [
      PenAnchor.smooth(a, const Point2D(130, 90)),
      const PenAnchor(b),
      const PenAnchor(c, handleIn: Point2D(210, 150)),
    ];
    final read = anchorsOf(PathPayload(segmentsFor(anchors, closed: true)));
    expect(read.closed, isTrue);
    expect(read.anchors, hasLength(3));
    expect(read.anchors.first.handleOut, const Point2D(130, 90));
    expect(read.anchors[2].handleIn, const Point2D(210, 150));
  });

  test('editing anchors refits the box without moving anything', () {
    final path = newPathObject(
      id: const ObjectId('p'),
      pageId: page1,
      anchors: const [PenAnchor(a), PenAnchor(b), PenAnchor(c)],
    );
    final local = localAnchors(path);
    expect(local.anchors.first.point, Point2D.zero);
    // Drag the last anchor 50 to the right and 50 down.
    final moved = [
      ...local.anchors.take(2),
      local.anchors.last.translated(50, 50),
    ];
    final edited = withAnchors(path, moved, closed: false);
    final doc = documentWith([edited]);
    final world = worldMatrix(doc, edited.id);
    final points = localAnchors(
      edited,
    ).anchors.map((x) => world.apply(x.point));
    expect(points.toList(), [a, b, const Point2D(250, 250)]);
  });

  test('a resized path reports anchors in the new box', () {
    final path = newPathObject(
      id: const ObjectId('p'),
      pageId: page1,
      anchors: const [PenAnchor(a), PenAnchor(c)],
    );
    final wider = path.copyWith(transform: path.transform.copyWith(width: 200));
    expect(localAnchors(wider).anchors.last.point, const Point2D(200, 100));
  });

  test('freehand strokes are simplified and smoothed', () {
    final raw = [
      for (var i = 0; i <= 100; i++) Point2D(i.toDouble(), (i % 2) * 0.2),
    ];
    final straight = smoothStroke(raw);
    expect(straight, hasLength(2));
    final wave = smoothStroke([
      for (var i = 0; i <= 40; i++) Point2D(i * 5.0, i.isEven ? 0 : 30),
    ], tolerance: 2);
    expect(wave.length, greaterThan(10));
    expect(wave[1].handleIn, isNotNull);
    expect(wave.first.handleIn, isNull);
  });
}
