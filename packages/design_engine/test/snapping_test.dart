import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  final doc = documentWith([
    rect('a', x: 100, y: 100, h: 100),
    rect('b', x: 400, y: 300, w: 50),
    rect('hidden', x: 700, y: 700, hidden: true),
  ]);
  final page = doc.pages.first;

  test('a moved box snaps its nearest edge or centre', () {
    final targets = SnapTargets.collect(
      doc,
      page,
      exclude: const {ObjectId('b')},
    );
    // b moved so its left edge sits 3 units right of a's right edge (200).
    final result = targets.snapRect(
      Rect2D.fromLTWH(203, 404, 50, 50),
      threshold: 5,
    );
    expect(result.dx, -3);
    expect(result.dy, 0);
    expect(result.guides.single.vertical, isTrue);
    expect(result.guides.single.position, 200);
    // The guide spans the target and the moved box.
    expect(result.guides.single.start, 100);
    expect(result.guides.single.end, 454);
  });

  test('page centre and edges are targets; far boxes do not snap', () {
    final targets = SnapTargets.collect(
      doc,
      page,
      exclude: const {ObjectId('b')},
    );
    final centred = targets.snapRect(
      Rect2D.fromLTWH(473, 800, 50, 50),
      threshold: 4,
    );
    expect(centred.dx, 2); // centre 498 → page centre 500
    final none = targets.snapRect(
      Rect2D.fromLTWH(320, 820, 30, 30),
      threshold: 2,
    );
    expect((none.dx, none.dy), (0.0, 0.0));
    expect(none.guides, isEmpty);
  });

  test('hidden objects and the moving object are not targets', () {
    final targets = SnapTargets.collect(
      doc,
      page,
      exclude: const {ObjectId('a')},
    );
    expect(targets.xs.any((l) => l.$1 == 100), isFalse);
    expect(targets.xs.any((l) => l.$1 == 700), isFalse);
  });

  test('points snap on each axis independently', () {
    final targets = SnapTargets.collect(doc, page);
    final r = targets.snapPoint(const Point2D(198, 302), threshold: 3);
    expect(r.point, const Point2D(200, 300));
    expect(r.guides, hasLength(2));
    final onlyX = targets.snapPoint(
      const Point2D(198, 302),
      threshold: 3,
      snapY: false,
    );
    expect(onlyX.point, const Point2D(200, 302));
  });

  test('boards have no page edges to snap to', () {
    final board = DesignDocument(
      id: doc.id,
      metadata: doc.metadata,
      pages: [page.copyWith(kind: PageKind.board, objectIds: const [])],
    );
    final targets = SnapTargets.collect(board, board.pages.single);
    expect(targets.xs, isEmpty);
  });

  test('ruler guides and the grid are targets when asked for', () {
    final guided = page.copyWith(
      guides: [Guide(GuideAxis.vertical, 333), Guide(GuideAxis.horizontal, 77)],
    );
    final withGuides = SnapTargets.collect(doc, guided);
    final snapped = withGuides.snapRect(
      Rect2D.fromLTWH(335, 600, 10, 10),
      threshold: 3,
    );
    expect(snapped.dx, -2);
    expect(
      withGuides.snapPoint(const Point2D(50, 79), threshold: 3).point,
      const Point2D(50, 77),
    );
    final noGuides = SnapTargets.collect(doc, guided, guides: false);
    expect(
      noGuides.snapRect(Rect2D.fromLTWH(335, 600, 10, 10), threshold: 3).dx,
      0,
    );
    final grid = SnapTargets.collect(doc, page, guides: false, grid: 8);
    expect(
      grid.snapPoint(const Point2D(613, 619), threshold: 3).point,
      const Point2D(616, 616),
    );
  });
}
