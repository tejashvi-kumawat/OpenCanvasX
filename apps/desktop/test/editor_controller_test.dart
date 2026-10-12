import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencanvasx/src/editor/editor_controller.dart';
import 'package:opencanvasx/src/providers.dart';
import 'package:storage/storage.dart';

import 'support/fakes.dart';

void main() {
  late AppIndex index;
  late InMemoryDesignLibrary library;
  late ProviderContainer container;
  late String path;

  EditorController editor() => container.read(editorProvider.notifier);
  EditorSession session() => container.read(editorProvider)!;
  DesignDocument doc() => session().document;
  List<ObjectId> roots() => session().activePage.objectIds;

  setUp(() async {
    index = AppIndex.inMemory();
    library = InMemoryDesignLibrary();
    path = library.seed('/designs', 'Poster');
    container = ProviderContainer(
      overrides: [
        appIndexProvider.overrideWithValue(index),
        designLibraryProvider.overrideWithValue(library),
        autosaveDelayProvider.overrideWithValue(Duration.zero),
        textMeasurerProvider.overrideWithValue(fakeMeasure),
      ],
    );
    await editor().open(path);
  });

  tearDown(() {
    container.dispose();
    index.close();
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test('open starts on the first page and records a recent document', () {
    expect(session().path, path);
    expect(session().saveStatus, SaveStatus.saved);
    expect(index.recent.list().single.title, 'Poster');
  });

  test('insertShape adds a centred shape and selects it', () {
    editor().insertShape(ObjectType.ellipse);
    final id = roots().single;
    expect(session().selection, {id});
    final shape = doc().objects[id]!;
    expect(shape.type, ObjectType.ellipse);
    expect(shape.transform.x + shape.transform.width / 2, 540);
    expect(session().undoLabel, 'Add Ellipse');
  });

  test('undo and redo restore documents and labels', () {
    editor()
      ..insertShape(ObjectType.rect)
      ..undo();
    expect(roots(), isEmpty);
    expect(session().canUndo, isFalse);
    expect(session().redoLabel, 'Add Rectangle');
    editor().redo();
    expect(roots(), hasLength(1));
  });

  test('edits autosave the design and report status', () async {
    editor().insertShape(ObjectType.rect);
    expect(session().saveStatus, SaveStatus.pending);
    await settle();
    expect(session().saveStatus, SaveStatus.saved);
    expect(library.saves, 1);
    expect(library.files[path]!.objects, hasLength(1));
    expect(library.files[path]!.metadata.modifiedAt, isNotNull);
  });

  test('a drag previews live and becomes one undo step', () {
    editor().insertShape(ObjectType.rect);
    final id = roots().single;
    final start = doc().objects[id]!;
    editor().beginGesture();
    for (final dx in [10.0, 20.0, 30.0]) {
      editor().previewObjects([
        start.copyWith(
          transform: start.transform.copyWith(x: start.transform.x + dx),
        ),
      ]);
    }
    expect(doc().objects[id]!.transform.x, start.transform.x + 30);
    expect(
      session().undoLabel,
      'Add Rectangle',
      reason: 'preview not recorded',
    );
    editor().endGesture('Move');
    expect(session().undoLabel, 'Move');
    editor().undo();
    expect(doc().objects[id]!.transform.x, start.transform.x);
  });

  test('a gesture without movement records nothing', () {
    editor()
      ..insertShape(ObjectType.rect)
      ..beginGesture()
      ..endGesture('Move');
    expect(session().undoLabel, 'Add Rectangle');
  });

  test('copy, paste, cut and duplicate', () {
    editor()
      ..insertShape(ObjectType.rect)
      ..copySelection()
      ..paste();
    expect(roots(), hasLength(2));
    expect(session().selection, {roots().last});
    editor().duplicateSelection();
    expect(roots(), hasLength(3));
    editor().cutSelection();
    expect(roots(), hasLength(2));
    editor().paste();
    expect(roots(), hasLength(3));
  });

  test('nudge, delete and select all', () {
    editor().insertShape(ObjectType.rect);
    final id = roots().single;
    final x = doc().objects[id]!.transform.x;
    editor().nudge(1, 0);
    expect(doc().objects[id]!.transform.x, x + 1);
    editor().nudge(-1, 0, large: true);
    expect(doc().objects[id]!.transform.x, x - 9);
    editor()
      ..insertShape(ObjectType.ellipse)
      ..clearSelection()
      ..selectAll();
    expect(session().selection, hasLength(2));
    editor().deleteSelection();
    expect(roots(), isEmpty);
  });

  test('align a single element to the page', () {
    editor()
      ..insertShape(ObjectType.rect)
      ..align(AlignEdge.left);
    expect(doc().objects[roots().single]!.transform.x, 0);
  });

  test('arrange and layer order', () {
    editor()
      ..insertShape(ObjectType.rect)
      ..insertShape(ObjectType.ellipse);
    final [a, b] = roots();
    editor().select({b});
    editor().arrange(ZOrderMove.toBack);
    expect(roots(), [b, a]);
    editor().setLayerOrder([a, b]);
    expect(roots(), [a, b]);
  });

  test('hiding or locking a selected layer deselects it', () {
    editor().insertShape(ObjectType.rect);
    final id = roots().single;
    editor().updateObject(id, (o) => o.copyWith(locked: true), label: 'Lock');
    expect(session().selection, isEmpty);
    expect(doc().objects[id]!.locked, isTrue);
  });

  test('pages: add, duplicate, move, delete', () {
    editor().insertShape(ObjectType.rect);
    final first = session().state.activePageId;
    editor().addPage();
    expect(doc().pages, hasLength(2));
    expect(session().state.activePageIndex, 1);
    editor().duplicatePage(first);
    expect(doc().pages, hasLength(3));
    expect(doc().pages[1].objectIds, hasLength(1));
    editor().movePage(0, 2);
    expect(doc().pages.last.id, first);
    editor().deletePage(first);
    expect(doc().pages, hasLength(2));
    expect(doc().pages.any((p) => p.id == first), isFalse);
  });

  test('the last page cannot be deleted', () {
    editor().deletePage(session().state.activePageId);
    expect(doc().pages, hasLength(1));
  });

  test('rename and page settings are undoable', () {
    editor().rename('Spring Poster');
    expect(doc().metadata.title, 'Spring Poster');
    editor().updatePage(
      session().activePage.copyWith(background: const TransparentBackground()),
    );
    expect(session().activePage.background, const TransparentBackground());
    editor()
      ..undo()
      ..undo();
    expect(doc().metadata.title, 'Poster');
  });

  test('close flushes pending edits and clears the session', () async {
    editor().insertShape(ObjectType.rect);
    await editor().close();
    expect(container.read(editorProvider), isNull);
    expect(library.files[path]!.objects, hasLength(1));
  });

  test('start with unsaved writes a restored document back', () async {
    final restored = doc();
    editor().start(path, restored, unsaved: true);
    expect(session().saveStatus, SaveStatus.pending);
    await settle();
    expect(session().saveStatus, SaveStatus.saved);
  });

  test('layerName numbers unnamed elements per type', () {
    editor()
      ..insertShape(ObjectType.rect)
      ..insertShape(ObjectType.rect)
      ..insertShape(ObjectType.ellipse);
    final page = session().activePage;
    final names = [
      for (final id in page.objectIds)
        layerName(doc(), page, doc().objects[id]!),
    ];
    expect(names, ['Rectangle 1', 'Rectangle 2', 'Ellipse 1']);
  });

  group('text', () {
    TextPayload payloadOf(ObjectId id) =>
        doc().objects[id]!.payload as TextPayload;

    test('insertText measures and selects the new box', () {
      final id = editor().insertText(TextRole.heading);
      final payload = payloadOf(id);
      expect(payload.text, 'Heading');
      final t = doc().objects[id]!.transform;
      expect(t.width, fakeMeasure(payload).x);
      expect(session().selection, {id});
      expect(session().undoLabel, 'Add text');
    });

    test('inline editing is one undo step and resizes auto-width text', () {
      final id = editor().insertText(TextRole.body);
      final before = doc().objects[id]!.transform.width;
      editor()
        ..startTextEdit(id)
        ..updateEditedText('Hello')
        ..updateEditedText('Hello world, longer');
      expect(container.read(textEditingProvider), id);
      expect(doc().objects[id]!.transform.width, greaterThan(before));
      editor().finishTextEdit();
      expect(container.read(textEditingProvider), isNull);
      expect(payloadOf(id).text, 'Hello world, longer');
      expect(session().undoLabel, 'Edit text');
      editor().undo();
      expect(payloadOf(id).text, 'Body text');
    });

    test('finishing with empty text removes the box', () {
      final id = editor().insertText(TextRole.body);
      editor()
        ..startTextEdit(id)
        ..updateEditedText('   ')
        ..finishTextEdit();
      expect(doc().objects.containsKey(id), isFalse);
    });

    test('formatting re-measures the box for its sizing mode', () {
      final id = editor().insertText(TextRole.body);
      final w = doc().objects[id]!.transform.width;
      editor().updateSelectedText(
        (t) => t.copyWith(fontSize: t.fontSize * 2),
        label: 'Font size',
      );
      expect(doc().objects[id]!.transform.width, closeTo(w * 2, 0.01));
      editor().updateSelectedText(
        (t) => t.copyWith(sizing: TextSizing.fixed),
        label: 'Text sizing',
      );
      final fixedWidth = doc().objects[id]!.transform.width;
      editor().updateSelectedText(
        (t) => t.copyWith(fontSize: t.fontSize * 2),
        label: 'Font size',
      );
      expect(doc().objects[id]!.transform.width, fixedWidth);
    });
  });

  test('insertDrawnShape uses the drawn transform', () {
    final page = session().state.activePageId;
    editor().insertDrawnShape(
      ObjectType.star,
      ObjectTransform(x: 10, y: 20, width: 30, height: 40),
      pageId: page,
    );
    final star = doc().objects[roots().single]!;
    expect(star.payload, StarPayload());
    expect((star.transform.x, star.transform.width), (10.0, 30.0));
  });

  test('distribute needs three or more', () {
    editor()
      ..insertShape(ObjectType.rect, at: const Point2D(100, 100))
      ..insertShape(ObjectType.rect, at: const Point2D(200, 100))
      ..selectAll()
      ..distribute(DistributeAxis.horizontal);
    expect(session().undoLabel, 'Add Rectangle');
    editor()
      ..insertShape(ObjectType.rect, at: const Point2D(900, 100))
      ..selectAll()
      ..distribute(DistributeAxis.horizontal);
    expect(session().undoLabel, 'Distribute');
  });
}
