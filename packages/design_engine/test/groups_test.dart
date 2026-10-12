import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

DesignDocument apply(DesignDocument doc, Change change) =>
    change.applyTo(doc).$1;

List<String> roots(DesignDocument doc) =>
    doc.pages.first.objectIds.map((id) => id.value).toList();

void expectValid(DesignDocument doc) =>
    expect(validatePages(doc.pages, doc.objects), isEmpty);

void main() {
  final doc = documentWith([
    rect('a', x: 100, y: 100),
    rect('b', x: 300, y: 200, w: 50, h: 100),
    rect('c', x: 600, y: 600),
  ]);

  group('groupObjects', () {
    test('wraps members in a group fitted to their bounds', () {
      final (change, id) = groupObjects(doc, const [
        ObjectId('b'),
        ObjectId('a'),
      ], newId: idSequence('g'));
      final after = apply(doc, change);
      expect(id, const ObjectId('g1'));
      expect(roots(after), ['g1', 'c']);
      final group = after.objects[id]!;
      expect(group.type, ObjectType.group);
      expect(group.childIds, [const ObjectId('a'), const ObjectId('b')]);
      expect(group.transform.x, 100);
      expect(group.transform.y, 100);
      expect(group.transform.width, 250);
      expect(group.transform.height, 200);
      expect(after.objects[const ObjectId('b')]!.transform.x, 200);
      expect(after.objects[const ObjectId('b')]!.parentId, id);
      expectValid(after);
    });

    test('children keep their place on the page', () {
      final (change, _) = groupObjects(doc, const [
        ObjectId('a'),
        ObjectId('b'),
      ]);
      final after = apply(doc, change);
      expect(
        worldBounds(after, const ObjectId('b')),
        worldBounds(doc, const ObjectId('b')),
      );
    });

    test('is undoable', () {
      final (change, _) = groupObjects(doc, const [
        ObjectId('a'),
        ObjectId('c'),
      ]);
      final (after, inverse) = change.applyTo(doc);
      expect(apply(after, inverse), doc);
    });

    test('needs two members with the same parent', () {
      expect(groupObjects(doc, const [ObjectId('a')]).$2, isNull);
      final nested = documentWith(
        [
          rect('g', w: 500, h: 500, children: ['x']),
          rect('a'),
        ],
        nested: [rect('x', parent: 'g')],
      );
      expect(
        groupObjects(nested, const [ObjectId('x'), ObjectId('a')]).$2,
        isNull,
      );
    });
  });

  group('ungroupObjects', () {
    test("restores children in the group's stacking slot", () {
      final (grouped, id) = groupObjects(doc, const [
        ObjectId('a'),
        ObjectId('b'),
      ]);
      final after = apply(doc, grouped);
      final (change, released) = ungroupObjects(after, [id!]);
      final back = apply(after, change);
      expect(released, [const ObjectId('a'), const ObjectId('b')]);
      expect(roots(back), ['a', 'b', 'c']);
      expect(back.objects.containsKey(id), isFalse);
      expect(
        back.objects[const ObjectId('b')]!.transform.x,
        closeTo(300, 1e-9),
      );
      expect(back.objects[const ObjectId('b')]!.parentId, isNull);
      expectValid(back);
    });

    test('folds a rotated group into its children', () {
      final rotated = documentWith(
        [
          rect('g', w: 200, h: 200, rotation: 90, children: ['x']),
        ],
        nested: [rect('x', parent: 'g', h: 100)],
      );
      final before = worldBounds(rotated, const ObjectId('x'))!;
      final after = apply(
        rotated,
        ungroupObjects(rotated, const [ObjectId('g')]).$1,
      );
      final x = after.objects[const ObjectId('x')]!;
      expect(x.transform.rotation, closeTo(90, 1e-9));
      final bounds = worldBounds(after, const ObjectId('x'))!;
      expect(bounds.left, closeTo(before.left, 1e-6));
      expect(bounds.top, closeTo(before.top, 1e-6));
      expect(bounds.width, closeTo(before.width, 1e-6));
    });

    test('ignores non-groups', () {
      final (change, released) = ungroupObjects(doc, const [ObjectId('a')]);
      expect(released, isEmpty);
      expect(apply(doc, change), doc);
    });
  });

  group('nested objects', () {
    final nested = documentWith(
      [
        rect('g', x: 100, y: 100, w: 200, h: 200, children: ['x']),
      ],
      nested: [rect('x', parent: 'g', x: 10, y: 10, w: 50)],
    );

    test('move in page units through a scaled group', () {
      final scaled = documentWith(
        [
          DesignObject(
            id: const ObjectId('g'),
            type: ObjectType.group,
            pageId: page1,
            childIds: const [ObjectId('x')],
            transform: ObjectTransform(
              width: 200,
              height: 200,
              scaleX: 2,
              scaleY: 2,
              anchorX: 0,
              anchorY: 0,
            ),
          ),
        ],
        nested: [rect('x', parent: 'g', w: 50)],
      );
      final after = apply(
        scaled,
        moveObjects(scaled, const [ObjectId('x')], 40, 20),
      );
      expect(after.objects[const ObjectId('x')]!.transform.x, 20);
      expect(after.objects[const ObjectId('x')]!.transform.y, 10);
    });

    test('copies carry page-space transforms', () {
      final copies = copySubtrees(nested, const [ObjectId('x')]);
      expect(copies.single.transform.x, closeTo(110, 1e-9));
      expect(copies.single.transform.y, closeTo(110, 1e-9));
    });

    test('selection may hold objects inside groups', () {
      final state =
          EditorState(
            document: nested,
            activePageId: page1,
            selection: const {ObjectId('x')},
          ).normalized();
      expect(state.selection, {const ObjectId('x')});
      expect(state.selectedObjects.single.id, const ObjectId('x'));
    });

    test('deep hit test finds the leaf', () {
      expect(
        hitTest(nested, nested.pages.first, const Point2D(130, 130)),
        const ObjectId('g'),
      );
      expect(
        hitTestDeep(nested, nested.pages.first, const Point2D(130, 130)),
        const ObjectId('x'),
      );
      expect(
        hitTestDeep(nested, nested.pages.first, const Point2D(250, 250)),
        isNull,
      );
    });

    test('resizing a group scales its contents', () {
      final group = nested.objects[const ObjectId('g')]!;
      final resized = resizeGroup(
        nested,
        group,
        group.transform.copyWith(width: 400, height: 100),
      );
      final x = resized.firstWhere((o) => o.id == const ObjectId('x'));
      expect(x.transform.x, 20);
      expect(x.transform.y, 5);
      expect(x.transform.width, 100);
      expect(x.transform.height, 25);
    });

    test('reorder moves objects among their siblings', () {
      final doc2 = documentWith(
        [
          rect('g', w: 500, h: 500, children: ['x', 'y']),
        ],
        nested: [rect('x', parent: 'g'), rect('y', parent: 'g')],
      );
      final after = apply(
        doc2,
        reorderObjects(doc2, page1, const {ObjectId('x')}, ZOrderMove.toFront),
      );
      expect(after.objects[const ObjectId('g')]!.childIds, const [
        ObjectId('y'),
        ObjectId('x'),
      ]);
    });

    test('duplicating a nested object adds a page root', () {
      final (change, ids) = duplicateObjects(
        nested,
        page1,
        const [ObjectId('x')],
        offset: 10,
        newId: idSequence('d'),
      );
      final after = apply(nested, change);
      expect(ids, [const ObjectId('d1')]);
      expect(roots(after), ['g', 'd1']);
      expect(
        after.objects[const ObjectId('d1')]!.transform.x,
        closeTo(120, 1e-9),
      );
    });

    test('pick selects roots, then siblings inside an entered group', () {
      final two = documentWith(
        [
          rect('g', w: 500, h: 500, children: ['x', 'y']),
        ],
        nested: [
          rect('x', parent: 'g', h: 100),
          rect('y', parent: 'g', x: 200, y: 200, h: 100),
        ],
      );
      final page = two.pages.first;
      const inX = Point2D(50, 50);
      const inY = Point2D(250, 250);
      expect(pickObject(two, page, inX), const ObjectId('g'));
      expect(
        pickObject(
          two,
          page,
          inX,
          selection: {const ObjectId('g')},
          enter: true,
        ),
        const ObjectId('x'),
      );
      expect(
        pickObject(two, page, inY, selection: {const ObjectId('x')}),
        const ObjectId('y'),
      );
      expect(pickObject(two, page, const Point2D(900, 900)), isNull);
    });

    test('pageObjectsInOrder walks depth first', () {
      expect(
        pageObjectsInOrder(nested, nested.pages.first).map((i) => i.value),
        ['g', 'x'],
      );
    });
  });
}
