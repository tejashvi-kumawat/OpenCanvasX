import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  group('Change', () {
    test('applies puts and deletes and returns the exact inverse', () {
      final doc = documentWith([rect('a'), rect('b')]);
      final moved = doc.objects[const ObjectId('a')]!.copyWith(
        transform: ObjectTransform(width: 1, height: 1, x: 9),
      );
      final change = Change(
        label: 'Edit',
        objects: {const ObjectId('a'): moved, const ObjectId('b'): null},
      );
      final (next, inverse) = change.applyTo(doc);
      expect(next.objects[const ObjectId('a')], moved);
      expect(next.objects.containsKey(const ObjectId('b')), isFalse);

      final (restored, redo) = inverse.applyTo(next);
      expect(restored, doc);
      expect(redo.applyTo(restored).$1, next);
    });

    test('replaces pages and metadata reversibly', () {
      final doc = documentWith([]);
      final change = Change(
        label: 'Pages',
        pages: [doc.pages.last],
        metadata: const DocumentMetadata(title: 'New'),
      );
      final (next, inverse) = change.applyTo(doc);
      expect(next.pages, hasLength(1));
      expect(next.metadata.title, 'New');
      expect(inverse.applyTo(next).$1, doc);
    });

    test('isEmpty', () {
      expect(Change(label: 'x').isEmpty, isTrue);
      expect(Change(label: 'x', pages: const []).isEmpty, isFalse);
    });
  });

  group('History', () {
    late History history;
    late DesignDocument doc;

    setUp(() {
      history = History();
      doc = documentWith([rect('a')]);
    });

    test('undo and redo walk back and forth', () {
      final moved = history.apply(
        doc,
        moveObjects(doc, [const ObjectId('a')], 5, 0),
      );
      expect(history.canUndo, isTrue);
      expect(history.undoLabel, 'Move');

      final undone = history.undo(moved);
      expect(undone, doc);
      expect(history.canRedo, isTrue);
      expect(history.redoLabel, 'Move');

      final redone = history.redo(undone);
      expect(redone, moved);
      expect(history.canRedo, isFalse);
    });

    test('a new edit clears redo', () {
      final a = history.apply(
        doc,
        moveObjects(doc, [const ObjectId('a')], 1, 0),
      );
      history.undo(a);
      history.apply(doc, moveObjects(doc, [const ObjectId('a')], 0, 1));
      expect(history.canRedo, isFalse);
    });

    test('empty changes are not recorded', () {
      expect(history.apply(doc, Change(label: 'Nothing')), same(doc));
      expect(history.canUndo, isFalse);
    });

    test('keeps at most limit steps', () {
      final small = History(limit: 3);
      var current = doc;
      for (var i = 0; i < 5; i++) {
        current = small.apply(
          current,
          moveObjects(current, [const ObjectId('a')], 1, 0),
        );
      }
      var steps = 0;
      while (small.canUndo) {
        current = small.undo(current);
        steps++;
      }
      expect(steps, 3);
      expect(current.objects[const ObjectId('a')]!.transform.x, 2);
    });

    test('recordApplied supports live previews', () {
      final change = moveObjects(doc, [const ObjectId('a')], 10, 0);
      final (next, inverse) = change.applyTo(doc);
      history.recordApplied(inverse);
      expect(history.undo(next), doc);
    });

    test('undo and redo with empty stacks are no-ops', () {
      expect(history.undo(doc), same(doc));
      expect(history.redo(doc), same(doc));
    });
  });

  group('EditorState', () {
    test('initial selects the first page', () {
      final state = EditorState.initial(documentWith([rect('a')]));
      expect(state.activePageId, page1);
      expect(state.selection, isEmpty);
    });

    test('normalized drops selection that no longer exists', () {
      final doc = documentWith([rect('a'), rect('b')]);
      final state = EditorState(
        document: doc,
        activePageId: page1,
        selection: const {ObjectId('a'), ObjectId('b')},
      );
      final after = state.copyWith(
        document: deleteObjects(doc, [const ObjectId('b')]).applyTo(doc).$1,
      );
      expect(after.selection, {const ObjectId('a')});
    });

    test('normalized falls back to the first page when the page is gone', () {
      final doc = documentWith([]);
      final state = EditorState(document: doc, activePageId: page2);
      final after = state.copyWith(
        document: deletePage(doc, page2).applyTo(doc).$1,
      );
      expect(after.activePageId, page1);
    });

    test('selectedObjects follows z-order', () {
      final doc = documentWith([rect('a'), rect('b'), rect('c')]);
      final state = EditorState(
        document: doc,
        activePageId: page1,
        selection: const {ObjectId('c'), ObjectId('a')},
      );
      expect(state.selectedObjects.map((o) => o.id.value), ['a', 'c']);
    });
  });
}
