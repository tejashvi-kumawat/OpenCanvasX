import 'dart:convert';
import 'dart:typed_data';

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

  test('group, enter, escape and ungroup', () {
    editor()
      ..insertShape(ObjectType.rect, at: const Point2D(100, 100))
      ..insertShape(ObjectType.ellipse, at: const Point2D(500, 500))
      ..selectAll();
    expect(editor().canGroup, isTrue);
    editor().groupSelection();
    final group = roots().single;
    expect(doc().objects[group]!.type, ObjectType.group);
    expect(session().selection, {group});
    expect(session().undoLabel, 'Group');

    // Select a child, move it, then Escape returns to the group.
    final child = doc().objects[group]!.childIds.first;
    final before = worldBounds(doc(), child)!;
    editor()
      ..select({child})
      ..nudge(1, 0, large: true);
    expect(worldBounds(doc(), child)!.left, closeTo(before.left + 10, 1e-9));
    editor().selectParentOrClear();
    expect(session().selection, {group});

    editor().ungroupSelection();
    expect(roots(), hasLength(2));
    expect(session().selection, hasLength(2));
    expect(doc().objects.containsKey(group), isFalse);
    editor().undo();
    expect(roots().single, group);
  });

  test('grouping needs siblings', () {
    editor().insertShape(ObjectType.rect);
    expect(editor().canGroup, isFalse);
    expect(editor().canUngroup, isFalse);
  });

  group('boards and frames', () {
    test('addBoard adds an unbounded page and activates it', () {
      editor().addBoard();
      expect(session().activePage.isBoard, isTrue);
      expect(doc().pages, hasLength(2));
      expect(session().undoLabel, isNotNull);
    });

    test('shapes drawn on a frame go inside it', () {
      editor().addBoard();
      final frame = editor().insertFrame(
        width: 390,
        height: 844,
        name: 'Phone',
        topLeft: Point2D.zero,
      );
      expect(roots(), [frame]);
      editor().insertDrawnShape(
        ObjectType.rect,
        ObjectTransform(x: 20, y: 20, width: 100, height: 100),
        pageId: session().activePage.id,
      );
      final shape = session().selection.single;
      expect(doc().objects[shape]!.parentId, frame);
      expect(doc().objects[frame]!.childIds, [shape]);
      // One undo step removes the shape and its frame membership.
      editor().undo();
      expect(doc().objects[frame]!.childIds, isEmpty);
      expect(doc().objects.containsKey(shape), isFalse);
    });

    test('dragging out of a frame moves the object to the board', () {
      editor().addBoard();
      final frame = editor().insertFrame(
        width: 400,
        height: 400,
        topLeft: Point2D.zero,
      );
      editor().insertDrawnShape(
        ObjectType.rect,
        ObjectTransform(x: 10, y: 10, width: 50, height: 50),
        pageId: session().activePage.id,
      );
      final shape = session().selection.single;
      final o = doc().objects[shape]!;
      editor()
        ..beginGesture()
        ..previewObjects([
          o.copyWith(transform: o.transform.copyWith(x: 600, y: 600)),
        ])
        ..endMoveGesture(const Point2D(620, 620));
      expect(doc().objects[shape]!.parentId, isNull);
      expect(roots(), [frame, shape]);
      expect(worldBounds(doc(), shape)!.left, closeTo(600, 1e-9));
      editor().undo();
      expect(doc().objects[shape]!.parentId, frame);
    });

    test('frame selection wraps objects; ungroup removes the frame', () {
      editor()
        ..insertShape(ObjectType.rect)
        ..frameSelection();
      final frame = roots().single;
      expect(doc().objects[frame]!.type, ObjectType.frame);
      expect(editor().canUngroup, isTrue);
      editor().ungroupSelection();
      expect(doc().objects[roots().single]!.type, ObjectType.rect);
    });
  });

  group('images', () {
    final svg = Uint8List.fromList(
      utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
        ' <path d="M0 0h24v24" stroke="currentColor"/></svg>',
      ),
    );

    test(
      'insertImage stores the asset, sizes the box and saves bytes',
      () async {
        final id = editor().insertImage(
          svg,
          name: 'Heart',
          licenseRef: 'pack:lucide@1.55.0',
          tint: ArgbColor.black,
          size: 240,
        );
        final image = doc().objects[id]!;
        final payload = image.payload as ImagePayload;
        expect(image.type, ObjectType.image);
        expect(image.transform.width, 240);
        expect(image.transform.height, 240);
        expect(image.style!.fill, const SolidFill(ArgbColor.black));
        expect(
          doc().assets[payload.assetHash]!.licenseRef,
          'pack:lucide@1.55.0',
        );
        expect(doc().assets[payload.assetHash]!.mime, 'image/svg+xml');
        await settle();
        expect(library.savedAssets[path]!.keys, [payload.assetHash]);

        editor().undo();
        expect(doc().objects.containsKey(id), isFalse);
        expect(doc().assets, isEmpty);
      },
    );

    test('the same file is stored once', () {
      editor()
        ..insertImage(svg)
        ..insertImage(svg);
      expect(doc().assets, hasLength(1));
      expect(roots(), hasLength(2));
    });

    test('rejects unsafe or unknown files with a message', () {
      expect(
        () => editor().insertImage(
          Uint8List.fromList(utf8.encode('<svg><script/></svg>')),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('scripts'),
          ),
        ),
      );
      expect(
        () => editor().insertImage(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
      expect(roots(), isEmpty);
    });
  });

  group('components', () {
    test('create, instantiate, go to main and detach', () {
      editor()
        ..insertShape(ObjectType.rect, at: const Point2D(300, 300))
        ..insertShape(ObjectType.ellipse, at: const Point2D(500, 300))
        ..selectAll()
        ..createComponent();
      final component = session().selection.single;
      expect(isComponent(doc().objects[component]), isTrue);
      expect(session().undoLabel, 'Create component');

      final instance = editor().insertInstance(component)!;
      final i = doc().objects[instance]!;
      expect(i.type, ObjectType.instance);
      expect((i.payload as InstancePayload).componentId, component);
      expect(i.transform.width, doc().objects[component]!.transform.width);

      editor().goToMainComponent(instance);
      expect(session().selection, {component});

      editor()
        ..select({instance})
        ..detachSelection();
      final detached = session().selection.single;
      expect(doc().objects.containsKey(instance), isFalse);
      expect(doc().objects[detached]!.type, ObjectType.frame);
      expect(isComponent(doc().objects[detached]), isFalse);
      expect(doc().objects[detached]!.childIds, hasLength(2));
      editor().undo();
      expect(doc().objects[instance]!.type, ObjectType.instance);
    });
  });

  group('masks and image frames', () {
    // A PNG header is enough for import checks (decoding is not needed).
    final png = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52,
      0, 0, 0x02, 0x00, 0, 0, 0x01, 0x00, // 512 × 256
    ]);

    test('a selected image frame takes the next image', () {
      final frame = editor().insertImageFrame(ImageFrameShape.circle);
      expect(isMaskGroup(doc().objects[frame]), isTrue);
      final image = editor().insertImage(png);
      final group = doc().objects[frame]!;
      expect(group.childIds, hasLength(2));
      expect(group.childIds.last, image);
      expect(doc().objects[image]!.parentId, frame);
      // Cover: the wide image is as tall as the frame.
      final mask = doc().objects[group.childIds.first]!;
      expect(
        doc().objects[image]!.transform.height,
        closeTo(mask.transform.height, 1e-9),
      );
      expect(roots(), [frame]);
    });

    test('use as mask and adjustments as one undo step each', () {
      editor()
        ..insertShape(ObjectType.ellipse)
        ..insertImage(png)
        ..selectAll()
        ..useSelectionAsMask();
      final group = session().selection.single;
      expect(isMaskGroup(doc().objects[group]), isTrue);
      final image = doc().objects[group]!.childIds.last;
      editor()
        ..select({image})
        ..previewAdjust((a) => a.withValue('saturation', -50))
        ..previewAdjust((a) => a.withValue('saturation', -80))
        ..commitAdjust((a) => a.withValue('saturation', -80));
      final adjust = (doc().objects[image]!.payload as ImagePayload).adjust;
      expect(adjust.saturation, -80);
      expect(session().undoLabel, 'Adjust image');
      editor().undo();
      expect(
        (doc().objects[image]!.payload as ImagePayload).adjust.isNone,
        isTrue,
      );
    });
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
