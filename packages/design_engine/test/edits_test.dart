import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

DesignDocument apply(DesignDocument doc, Change change) =>
    change.applyTo(doc).$1;

List<String> roots(DesignDocument doc, [PageId page = page1]) =>
    doc.pages
        .firstWhere((p) => p.id == page)
        .objectIds
        .map((id) => id.value)
        .toList();

void main() {
  group('newShape', () {
    final page = DesignPage(id: page1, width: 1000, height: 500);

    test('centres a square shape with the default fill', () {
      final shape = newShape(ObjectType.ellipse, page, id: const ObjectId('s'));
      expect(shape.transform.width, 160);
      expect(shape.transform.height, 160);
      expect(shape.transform.x, 420);
      expect(shape.transform.y, 170);
      expect(shape.style!.fill, SolidFill(defaultShapeFill));
      expect(shape.pageId, page1);
    });

    test('lines are flat with a stroke and no fill', () {
      final line = newShape(ObjectType.arrow, page, id: const ObjectId('l'));
      expect(line.transform.height, 0);
      expect(line.style!.fill, isNull);
      expect(line.style!.stroke!.width, greaterThan(0));
    });

    test('rounded rectangles get a corner radius', () {
      final r = newShape(ObjectType.roundedRect, page, id: const ObjectId('r'));
      expect(r.style!.cornerRadius, greaterThan(0));
    });

    test('line width scales with physical units', () {
      final a4 = DesignPage(
        id: page1,
        width: 210,
        height: 297,
        unit: LengthUnit.mm,
        dpi: 300,
      );
      final line = newShape(ObjectType.line, a4, id: const ObjectId('l'));
      expect(line.style!.stroke!.width, lessThan(2));
    });

    test('honours a custom centre', () {
      final shape = newShape(
        ObjectType.rect,
        page,
        id: const ObjectId('s'),
        center: const Point2D(100, 100),
      );
      expect(shape.transform.x + shape.transform.width / 2, 100);
    });
  });

  test('insertObjects adds on top and records the object', () {
    final doc = documentWith([rect('a')]);
    final next = apply(doc, insertObjects(doc, page1, [rect('b')]));
    expect(roots(next), ['a', 'b']);
    expect(next.validate(), isEmpty);
  });

  test('updateObjects skips unchanged objects', () {
    final doc = documentWith([rect('a')]);
    final change = updateObjects(doc, [
      doc.objects[const ObjectId('a')]!,
    ], label: 'Nothing');
    expect(change.isEmpty, isTrue);
  });

  test('moveObjects shifts positions', () {
    final doc = documentWith([rect('a', x: 10, y: 10)]);
    final next = apply(doc, moveObjects(doc, [const ObjectId('a')], 5, -3));
    final t = next.objects[const ObjectId('a')]!.transform;
    expect((t.x, t.y), (15.0, 7.0));
  });

  group('deleteObjects', () {
    test('removes roots and their whole subtree', () {
      final doc = documentWith(
        [
          rect('g', children: ['c1', 'c2']),
          rect('other'),
        ],
        nested: [rect('c1', parent: 'g'), rect('c2', parent: 'g')],
      );
      final next = apply(doc, deleteObjects(doc, [const ObjectId('g')]));
      expect(next.objects.keys.map((k) => k.value), ['other']);
      expect(roots(next), ['other']);
      expect(next.validate(), isEmpty);
    });

    test('unlinks a nested child from its group', () {
      final doc = documentWith(
        [
          rect('g', children: ['c1', 'c2']),
        ],
        nested: [rect('c1', parent: 'g'), rect('c2', parent: 'g')],
      );
      final next = apply(doc, deleteObjects(doc, [const ObjectId('c1')]));
      expect(next.objects[const ObjectId('g')]!.childIds, [
        const ObjectId('c2'),
      ]);
      expect(next.validate(), isEmpty);
    });

    test('is fully undoable', () {
      final doc = documentWith([rect('a'), rect('b')]);
      final (next, undo) = deleteObjects(doc, [
        const ObjectId('a'),
      ]).applyTo(doc);
      expect(undo.applyTo(next).$1, doc);
    });
  });

  group('copy, paste, duplicate', () {
    test('copySubtrees returns roots then descendants', () {
      final doc = documentWith(
        [
          rect('g', children: ['c']),
        ],
        nested: [rect('c', parent: 'g')],
      );
      expect(copySubtrees(doc, [const ObjectId('g')]).map((o) => o.id.value), [
        'g',
        'c',
      ]);
    });

    test('pasteObjects remaps ids, keeps structure and offsets roots', () {
      final doc = documentWith(
        [
          rect('g', x: 10, children: ['c']),
        ],
        nested: [rect('c', parent: 'g', x: 3)],
      );
      final (change, newRoots) = pasteObjects(
        doc,
        page2,
        copySubtrees(doc, [const ObjectId('g')]),
        offset: 20,
        newId: idSequence(),
      );
      final next = apply(doc, change);
      expect(newRoots, [const ObjectId('n1')]);
      expect(roots(next, page2), ['n1']);
      final group = next.objects[const ObjectId('n1')]!;
      expect(group.pageId, page2);
      expect(group.transform.x, 30);
      expect(group.childIds, [const ObjectId('n2')]);
      final child = next.objects[const ObjectId('n2')]!;
      expect(child.parentId, const ObjectId('n1'));
      expect(child.transform.x, 3, reason: 'children keep local positions');
      expect(next.validate(), isEmpty);
    });

    test('duplicateObjects copies selected roots in z-order', () {
      final doc = documentWith([rect('a'), rect('b'), rect('c')]);
      final (change, ids) = duplicateObjects(
        doc,
        page1,
        {const ObjectId('c'), const ObjectId('a')},
        offset: 10,
        newId: idSequence(),
      );
      final next = apply(doc, change);
      expect(roots(next), ['a', 'b', 'c', 'n1', 'n2']);
      expect(ids.map((i) => i.value), ['n1', 'n2']);
      expect(change.label, 'Duplicate');
    });
  });

  group('reorderObjects', () {
    DesignDocument abcd() =>
        documentWith([rect('a'), rect('b'), rect('c'), rect('d')]);

    List<String> reorder(Set<String> ids, ZOrderMove move) {
      final doc = abcd();
      return roots(
        apply(
          doc,
          reorderObjects(doc, page1, ids.map(ObjectId.new).toSet(), move),
        ),
      );
    }

    test('to front and to back keep relative order', () {
      expect(reorder({'a', 'c'}, ZOrderMove.toFront), ['b', 'd', 'a', 'c']);
      expect(reorder({'b', 'd'}, ZOrderMove.toBack), ['b', 'd', 'a', 'c']);
    });

    test('forward and backward move one step', () {
      expect(reorder({'b'}, ZOrderMove.forward), ['a', 'c', 'b', 'd']);
      expect(reorder({'c'}, ZOrderMove.backward), ['a', 'c', 'b', 'd']);
      expect(reorder({'d'}, ZOrderMove.forward), ['a', 'b', 'c', 'd']);
      expect(reorder({'a'}, ZOrderMove.backward), ['a', 'b', 'c', 'd']);
    });

    test('setLayerOrder requires a permutation', () {
      final doc = abcd();
      expect(
        () => setLayerOrder(doc, page1, [const ObjectId('a')]),
        throwsArgumentError,
      );
      expect(
        setLayerOrder(doc, page1, doc.pages.first.objectIds).isEmpty,
        isTrue,
      );
    });
  });

  group('alignObjects', () {
    test('aligns to page edges and centres', () {
      final doc = documentWith([rect('a', x: 10, y: 20)]);
      const pageRect = Rect2D.fromLTRB(0, 0, 1000, 1000);
      Rect2D aligned(AlignEdge edge) =>
          worldBounds(
            apply(
              doc,
              alignObjects(doc, [const ObjectId('a')], edge, pageRect),
            ),
            const ObjectId('a'),
          )!;

      expect(aligned(AlignEdge.left).left, 0);
      expect(aligned(AlignEdge.right).right, 1000);
      expect(aligned(AlignEdge.centerHorizontal).center.x, 500);
      expect(aligned(AlignEdge.top).top, 0);
      expect(aligned(AlignEdge.bottom).bottom, 1000);
      expect(aligned(AlignEdge.centerVertical).center.y, 500);
    });

    test('uses rotated bounds', () {
      final doc = documentWith([rect('a', x: 100, y: 100, rotation: 45)]);
      final next = apply(
        doc,
        alignObjects(
          doc,
          [const ObjectId('a')],
          AlignEdge.left,
          const Rect2D.fromLTRB(0, 0, 1000, 1000),
        ),
      );
      expect(worldBounds(next, const ObjectId('a'))!.left, closeTo(0, 1e-9));
    });
  });

  group('pages', () {
    test('addPage inserts at an index', () {
      final doc = documentWith([]);
      final page = DesignPage(id: const PageId('p3'), width: 1, height: 1);
      final next = apply(doc, addPage(doc, page, index: 1));
      expect(next.pages.map((p) => p.id.value), ['p1', 'p3', 'p2']);
    });

    test('deletePage removes its objects and refuses the last page', () {
      final doc = documentWith(
        [rect('a')],
        page2Roots: [rect('b', pageId: page2)],
      );
      final next = apply(doc, deletePage(doc, page1));
      expect(next.pages.single.id, page2);
      expect(next.objects.keys.map((k) => k.value), ['b']);
      expect(() => deletePage(next, page2), throwsStateError);
    });

    test('duplicatePage copies settings and objects after the original', () {
      final doc = documentWith(
        [
          rect('g', children: ['c']),
          rect('a'),
        ],
        nested: [rect('c', parent: 'g')],
      );
      final (change, newPage) = duplicatePage(
        doc,
        page1,
        newObjectId: idSequence(),
        newPageId: () => const PageId('copy'),
      );
      final next = apply(doc, change);
      expect(next.pages.map((p) => p.id.value), ['p1', 'copy', 'p2']);
      expect(newPage, const PageId('copy'));
      expect(roots(next, newPage), ['n1', 'n3']);
      expect(next.objects[const ObjectId('n1')]!.pageId, newPage);
      expect(next.validate(), isEmpty);
    });

    test('movePage reorders', () {
      final doc = documentWith([]);
      final next = apply(doc, movePage(doc, 0, 1));
      expect(next.pages.map((p) => p.id.value), ['p2', 'p1']);
    });

    test('updatePage replaces settings', () {
      final doc = documentWith([]);
      final next = apply(
        doc,
        updatePage(doc, doc.pages.first.copyWith(name: 'Cover')),
      );
      expect(next.pages.first.name, 'Cover');
    });

    test('renameDocument trims and ignores blanks', () {
      final doc = documentWith([]);
      expect(
        apply(doc, renameDocument(doc, '  Menu  ')).metadata.title,
        'Menu',
      );
      expect(renameDocument(doc, '   ').isEmpty, isTrue);
    });
  });
}
