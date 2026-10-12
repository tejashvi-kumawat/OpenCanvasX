import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

DesignDocument apply(DesignDocument doc, Change change) =>
    change.applyTo(doc).$1;

DesignObject frame(
  String id, {
  double x = 0,
  double y = 0,
  double w = 400,
  double h = 400,
  List<String> children = const [],
  String? parent,
  bool clip = true,
}) => DesignObject(
  id: ObjectId(id),
  type: ObjectType.frame,
  pageId: parent == null ? page1 : null,
  parentId: parent == null ? null : ObjectId(parent),
  childIds: children.map(ObjectId.new),
  transform: ObjectTransform(x: x, y: y, width: w, height: h),
  style: ObjectStyle(fill: const SolidFill(ArgbColor.white)),
  payload: FramePayload(clipContent: clip),
);

void main() {
  final doc = documentWith(
    [
      frame('f', x: 100, y: 100, children: ['r', 'g']),
      rect('out', x: 700, y: 700),
    ],
    nested: [
      rect('r', parent: 'f', x: 10, y: 10),
      // Sticks out of the frame on the right.
      rect('g', parent: 'f', x: 350, y: 200, w: 200),
    ],
  );
  final page = doc.pages.first;

  test('clicks go through a frame to its content', () {
    expect(pickObject(doc, page, const Point2D(130, 130)), const ObjectId('r'));
  });

  test('a top-level frame with content is not picked by its body', () {
    expect(pickObject(doc, page, const Point2D(300, 400)), isNull);
  });

  test('an empty frame is picked by its body', () {
    final empty = documentWith([frame('e')]);
    expect(
      pickObject(empty, empty.pages.first, const Point2D(50, 50)),
      const ObjectId('e'),
    );
  });

  test('clipped content outside the frame is not hit', () {
    expect(hitTestDeep(doc, page, const Point2D(600, 320)), isNull);
    final open = documentWith(
      [
        frame('f', x: 100, y: 100, children: ['g'], clip: false),
      ],
      nested: [rect('g', parent: 'f', x: 350, y: 200, w: 200)],
    );
    expect(
      hitTestDeep(open, open.pages.first, const Point2D(600, 320)),
      const ObjectId('g'),
    );
  });

  test('frameAt finds the deepest frame under a point', () {
    final nested = documentWith(
      [
        frame('a', w: 500, h: 500, children: ['b']),
      ],
      nested: [frame('b', parent: 'a', x: 100, y: 100, w: 100, h: 100)],
    );
    final p = nested.pages.first;
    expect(frameAt(nested, p, const Point2D(150, 150)), const ObjectId('b'));
    expect(frameAt(nested, p, const Point2D(50, 50)), const ObjectId('a'));
    expect(frameAt(nested, p, const Point2D(900, 900)), isNull);
    expect(
      frameAt(
        nested,
        p,
        const Point2D(150, 150),
        exclude: {const ObjectId('b')},
      ),
      const ObjectId('a'),
    );
  });

  test('reparenting into and out of a frame keeps page position', () {
    final before = worldBounds(doc, const ObjectId('out'))!;
    final into = apply(
      doc,
      reparentObjects(
        doc,
        const [ObjectId('out')],
        const ObjectId('f'),
        pageId: page1,
      ),
    );
    expect(into.pages.first.objectIds, const [ObjectId('f')]);
    expect(
      into.objects[const ObjectId('f')]!.childIds.last,
      const ObjectId('out'),
    );
    expect(
      into.objects[const ObjectId('out')]!.transform.x,
      closeTo(600, 1e-9),
    );
    expect(validatePages(into.pages, into.objects), isEmpty);
    final back = apply(
      into,
      reparentObjects(into, const [ObjectId('out')], null, pageId: page1),
    );
    final after = worldBounds(back, const ObjectId('out'))!;
    expect(after.left, closeTo(before.left, 1e-9));
    expect(back.pages.first.objectIds.last, const ObjectId('out'));
    expect(validatePages(back.pages, back.objects), isEmpty);
  });

  test('a frame cannot move into itself', () {
    final change = reparentObjects(
      doc,
      const [ObjectId('f')],
      const ObjectId('f'),
      pageId: page1,
    );
    expect(change.isEmpty, isTrue);
  });

  test('frame selection wraps objects in a white frame', () {
    final (change, id) = groupObjects(doc, const [
      ObjectId('out'),
    ], asFrame: true);
    final after = apply(doc, change);
    final f = after.objects[id]!;
    expect(f.type, ObjectType.frame);
    expect(f.payload, const FramePayload());
    expect(validatePages(after.pages, after.objects), isEmpty);
  });

  test('newFrame places a frame at a point', () {
    final f = newFrame(
      id: const ObjectId('n'),
      pageId: page1,
      width: 390,
      height: 844,
      at: const Point2D(-100, 50),
      name: 'Phone',
    );
    expect((f.transform.x, f.transform.y), (-100.0, 50.0));
    expect(f.type, ObjectType.frame);
  });
}
