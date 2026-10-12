import 'dart:convert';
import 'dart:io';

import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:export_engine/export_engine.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencanvasx/main.dart';
import 'package:opencanvasx/src/editor/canvas_view.dart';
import 'package:opencanvasx/src/export/exporter.dart';
import 'package:opencanvasx/src/plugins/plugins.dart';
import 'package:opencanvasx/src/present/present_page.dart';
import 'package:opencanvasx/src/templates/template_gallery.dart';
import 'package:opencanvasx/src/editor/editor_controller.dart';
import 'package:opencanvasx/src/editor/side_rail.dart';
import 'package:opencanvasx/src/editor/tools.dart';
import 'package:opencanvasx/src/editor/viewport.dart';
import 'package:opencanvasx/src/providers.dart';
import 'package:storage/storage.dart';
import 'package:template_engine/template_engine.dart';

import 'support/fakes.dart';

const _folder = '/home/me/Documents/OpenCanvasX';

void main() {
  late AppIndex index;
  late InMemoryDesignLibrary library;
  late ProviderContainer container;
  final exported = <(List<ExportedFile>, ExportFormat)>[];

  setUp(() {
    index = AppIndex.inMemory();
    library = InMemoryDesignLibrary();
  });

  tearDown(() => index.close());

  Future<void> pumpApp(
    WidgetTester tester, {
    bool withFolder = true,
    bool withTemplates = false,
  }) async {
    tester.view
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (withFolder) index.settings.set(AppSettings.projectsRootKey, _folder);
    container = ProviderContainer(
      overrides: [
        appIndexProvider.overrideWithValue(index),
        designLibraryProvider.overrideWithValue(library),
        autosaveDelayProvider.overrideWithValue(Duration.zero),
        folderCheckerProvider.overrideWithValue((_) async => null),
        folderCreatorProvider.overrideWithValue((_) async {}),
        suggestedProjectsFolderProvider.overrideWith((ref) async => _folder),
        textMeasurerProvider.overrideWithValue(fakeMeasure),
        // The bundled gallery is tested on its own; elsewhere it would push
        // recent designs below the test window.
        // The official templates come from the repository folder; other
        // tests leave them out so recent designs stay on screen.
        defaultTemplateRepositoriesProvider.overrideWithValue([
          if (withTemplates)
            const FolderTemplateRepository(
              '../../templates/official',
              label: 'OpenCanvasX',
            ),
        ]),
        bundledPluginsProvider.overrideWithValue([
          '../../plugins/placeholder-text',
        ]),
        templateCacheDirProvider.overrideWith(
          (ref) async => Directory.systemTemp.path,
        ),
        exportSaverProvider.overrideWithValue((files, format) async {
          exported.add((files, format));
          return '/exports';
        }),
      ],
    );
    exported.clear();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OpenCanvasXApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  EditorSession session() => container.read(editorProvider)!;
  List<ObjectId> roots() => session().activePage.objectIds;

  Future<void> openFirstDesign(WidgetTester tester) async {
    library.seed(_folder, 'Launch poster');
    await pumpApp(tester);
    await tester.ensureVisible(find.text('Launch poster'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Launch poster'));
    await tester.pumpAndSettle();
  }

  Future<void> showTab(WidgetTester tester, RailTab tab) async {
    container.read(railTabProvider.notifier).tab = tab;
    await tester.pumpAndSettle();
  }

  Future<void> showElements(WidgetTester tester) =>
      showTab(tester, RailTab.elements);

  Future<void> chord(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
  }) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  group('first run', () {
    testWidgets('explains the app and offers the suggested folder', (
      tester,
    ) async {
      await pumpApp(tester, withFolder: false);
      expect(find.text('Welcome to OpenCanvasX'), findsOneWidget);
      expect(find.text('Documents › OpenCanvasX'), findsOneWidget);
      expect(find.text('No account, no uploads, no tracking'), findsOneWidget);
    });

    testWidgets('continue with the suggested folder goes home', (tester) async {
      await pumpApp(tester, withFolder: false);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('What will you design today?'), findsOneWidget);
      expect(index.settings.get(AppSettings.projectsRootKey), _folder);
    });
  });

  group('home', () {
    testWidgets('shows an empty state with one primary action', (tester) async {
      await pumpApp(tester);
      expect(find.text('No designs yet'), findsOneWidget);
      expect(find.text('Create your first design'), findsOneWidget);
      expect(find.text('Instagram post'), findsOneWidget);
    });

    testWidgets('lists designs as cards with their size and age', (
      tester,
    ) async {
      library
        ..seed(_folder, 'Menu')
        ..seed(_folder, 'Bakery flyer');
      await pumpApp(tester);
      expect(find.text('Menu'), findsOneWidget);
      expect(find.text('Bakery flyer'), findsOneWidget);
      expect(find.byTooltip('Last edited'), findsNWidgets(2));
    });

    testWidgets('search filters designs', (tester) async {
      library
        ..seed(_folder, 'Menu')
        ..seed(_folder, 'Bakery flyer');
      await pumpApp(tester);
      await tester.enterText(find.byType(TextField).first, 'men');
      await tester.pumpAndSettle();
      expect(find.text('Menu'), findsOneWidget);
      expect(find.text('Bakery flyer'), findsNothing);
    });

    testWidgets('a preset creates a design and opens the editor', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('Story').first);
      await tester.pumpAndSettle();
      expect(library.files, hasLength(1));
      final page = session().activePage;
      expect((page.width, page.height), (1080.0, 1920.0));
      expect(find.text('Untitled story'), findsOneWidget);
    });

    testWidgets('templates: the gallery creates a design from a template', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await pumpApp(tester, withTemplates: true);
        // Let the bundled index and template files load.
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('Start from a template'), findsOneWidget);
      expect(find.text('Bold sale'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Bold sale'));
        for (var i = 0; i < 40 && library.files.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      expect(library.files, hasLength(1));
      final doc = session().document;
      expect(doc.metadata.title, 'Bold sale');
      expect(doc.pages.single.width, 1080);
      expect(doc.objects.length, greaterThan(5));
    });

    testWidgets('the create dialog supports custom sizes', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Create design'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom size').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pixels (px)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Millimetres (mm)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create design').last);
      await tester.pumpAndSettle();
      expect(session().activePage.unit, LengthUnit.mm);
    });
  });

  group('editor', () {
    testWidgets('opens with the first page fitted in view', (tester) async {
      await openFirstDesign(tester);
      final view = container.read(viewportProvider);
      expect(view.fitted, isTrue);
      final frame = layoutPages(session().document.pages).first;
      final onScreen = view.rectToScreen(frame.rect);
      final canvas = Offset.zero & view.size;
      expect(canvas.contains(onScreen.topLeft), isTrue);
      expect(canvas.contains(onScreen.bottomRight), isTrue);
    });

    testWidgets('Elements adds shapes; layers and inspector follow', (
      tester,
    ) async {
      await openFirstDesign(tester);
      await showElements(tester);
      await tester.tap(find.byTooltip('Rectangle'));
      await tester.pumpAndSettle();
      expect(roots(), hasLength(1));
      expect(find.text('Rectangle 1'), findsWidgets);
      expect(find.text('Layout'), findsOneWidget);
      expect(find.text('Fill'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('Elements adds text with its own inspector section', (
      tester,
    ) async {
      await openFirstDesign(tester);
      await showTab(tester, RailTab.text);
      await tester.tap(find.text('Add a heading'));
      await tester.pumpAndSettle();
      final text = session().document.objects[roots().single]!;
      expect((text.payload as TextPayload).text, 'Heading');
      expect(find.text('Text'), findsWidgets);
      expect(find.text('Text colour'), findsOneWidget);
    });

    testWidgets('a drawing tool draws a shape by dragging and resets', (
      tester,
    ) async {
      await openFirstDesign(tester);
      await tester.tap(find.byTooltip('Rectangle  (R)'));
      await tester.pumpAndSettle();
      expect(container.read(toolProvider).active, EditorTool.rect);
      final canvas = tester.getCenter(find.byType(DesignCanvas));
      final gesture = await tester.startGesture(
        canvas,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(40, 30));
      await gesture.moveBy(const Offset(40, 30));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(roots(), hasLength(1));
      final t = session().document.objects[roots().single]!.transform;
      expect(t.width, greaterThan(0));
      expect(container.read(toolProvider).active, EditorTool.move);
    });

    testWidgets('a group can be dragged, entered and ungrouped', (
      tester,
    ) async {
      await openFirstDesign(tester);
      final editor = container.read(editorProvider.notifier);
      final page = session().activePage;
      editor
        ..insertShape(
          ObjectType.rect,
          at: Point2D(page.width / 2 - 100, page.height / 2),
        )
        ..insertShape(
          ObjectType.rect,
          at: Point2D(page.width / 2 + 100, page.height / 2),
        );
      await tester.pumpAndSettle();
      await chord(tester, LogicalKeyboardKey.keyA);
      await chord(tester, LogicalKeyboardKey.keyG);
      final group = roots().single;
      expect(session().document.objects[group]!.type, ObjectType.group);
      final before = worldBounds(session().document, group)!;

      // Drag from the centre of the left rectangle.
      final canvas = tester.getRect(find.byType(DesignCanvas));
      final viewport = container.read(viewportProvider);
      final frame = layoutPages(session().document.pages).first;
      final child = session().document.objects[group]!.childIds.first;
      final centre = worldBounds(session().document, child)!;
      final screen =
          canvas.topLeft +
          viewport.toScreen(
            frame.toWorkspace(
              Point2D(
                centre.left + centre.width / 2,
                centre.top + centre.height / 2,
              ),
            ),
          );
      final gesture = await tester.startGesture(
        screen,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(30, 0));
      await gesture.moveBy(const Offset(30, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(session().selection, {group});
      final after = worldBounds(session().document, group)!;
      expect(after.left, greaterThan(before.left));
      expect(after.width, closeTo(before.width, 1e-6));

      await chord(tester, LogicalKeyboardKey.keyG, shift: true);
      expect(roots(), hasLength(2));
    });

    testWidgets('export: SVG through the dialog', (tester) async {
      await openFirstDesign(tester);
      container.read(editorProvider.notifier).insertShape(ObjectType.star);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Export'));
      await tester.pumpAndSettle();
      expect(find.text('File type'), findsOneWidget);
      await tester.tap(find.text('SVG'));
      await tester.pumpAndSettle();
      // The new star is selected, so the selection is exported.
      expect(find.text('1 file · Selection'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Export').last);
      await tester.pumpAndSettle();
      final (files, format) = exported.single;
      expect(format, ExportFormat.svg);
      final svg = utf8.decode(files.single.bytes);
      expect(svg, contains('<polygon points='));
      expect(files.single.name, 'Selection.svg');
      expect(find.text('Exported to /exports'), findsOneWidget);
    });

    testWidgets('export: PNG and PDF of the page render real pixels', (
      tester,
    ) async {
      await openFirstDesign(tester);
      container.read(editorProvider.notifier).insertShape(ObjectType.rect);
      await tester.pumpAndSettle();
      final s = session();
      await tester.runAsync(() async {
        final png = await buildExport(
          s.document,
          options: const ExportOptions(scale: 0.25),
          activePage: s.state.activePageId,
          selection: const {},
          media: container.read(mediaCacheProvider),
        );
        expect(png.single.name, 'Page 1.png');
        expect(png.single.bytes.sublist(1, 4), 'PNG'.codeUnits);
        final pdf = await buildExport(
          s.document,
          options: const ExportOptions(
            format: ExportFormat.pdf,
            scope: ExportScope.allPages,
            scale: 0.25,
          ),
          activePage: s.state.activePageId,
          selection: const {},
          media: container.read(mediaCacheProvider),
        );
        expect(latin1.decode(pdf.single.bytes.sublist(0, 5)), '%PDF-');
        final jpg = await buildExport(
          s.document,
          options: const ExportOptions(format: ExportFormat.jpg, scale: 0.25),
          activePage: s.state.activePageId,
          selection: const {},
          media: container.read(mediaCacheProvider),
        );
        expect(jpg.single.bytes.sublist(0, 2), [0xFF, 0xD8]);
      });
    });

    testWidgets('dragging snaps to the page centre unless Alt is held', (
      tester,
    ) async {
      await openFirstDesign(tester);
      container.read(editorProvider.notifier).insertShape(ObjectType.rect);
      await tester.pumpAndSettle();
      final id = roots().single;
      final before = session().document.objects[id]!.transform.x;
      final canvas = tester.getRect(find.byType(DesignCanvas));
      final viewport = container.read(viewportProvider);
      final frame = layoutPages(session().document.pages).first;
      final b = worldBounds(session().document, id)!;
      final centre =
          canvas.topLeft +
          viewport.toScreen(
            frame.toWorkspace(
              Point2D(b.left + b.width / 2, b.top + b.height / 2),
            ),
          );
      Future<void> drag(Offset by) async {
        final gesture = await tester.startGesture(
          centre,
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveBy(by / 2);
        await gesture.moveBy(by / 2);
        await gesture.up();
        await tester.pumpAndSettle();
      }

      await drag(const Offset(4, 0));
      expect(session().document.objects[id]!.transform.x, before);
      expect(session().undoLabel, isNot('Move'));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await drag(const Offset(4, 0));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      expect(session().document.objects[id]!.transform.x, greaterThan(before));
    });

    testWidgets('pen: clicks place points; clicking the first closes', (
      tester,
    ) async {
      await openFirstDesign(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();
      expect(container.read(toolProvider).active, EditorTool.pen);
      final c = tester.getCenter(find.byType(DesignCanvas));
      Future<void> click(Offset at) async {
        await tester.tapAt(at, kind: PointerDeviceKind.mouse);
        await tester.pump(const Duration(milliseconds: 500));
      }

      await click(c + const Offset(-60, -40));
      await click(c + const Offset(60, -40));
      // A drag pulls handles out of the third point.
      final g = await tester.startGesture(
        c + const Offset(0, 60),
        kind: PointerDeviceKind.mouse,
      );
      await g.moveBy(const Offset(30, 0));
      await g.moveBy(const Offset(30, 0));
      await g.up();
      await tester.pump(const Duration(milliseconds: 500));
      await click(c + const Offset(-60, -40));
      await tester.pumpAndSettle();
      final path = session().document.objects[roots().single]!;
      expect(path.type, ObjectType.path);
      final (:anchors, :closed) = localAnchors(path);
      expect(anchors, hasLength(3));
      expect(closed, isTrue);
      expect(anchors[2].handleOut, isNotNull);
      expect(container.read(toolProvider).active, EditorTool.move);
      expect(session().undoLabel, 'Add path');
    });

    testWidgets('pen: Escape finishes an open path', (tester) async {
      await openFirstDesign(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();
      final c = tester.getCenter(find.byType(DesignCanvas));
      await tester.tapAt(c, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tapAt(
        c + const Offset(80, 30),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      final path = session().document.objects[roots().single]!;
      expect(localAnchors(path).closed, isFalse);
    });

    testWidgets('pencil draws a smoothed freehand path', (tester) async {
      await openFirstDesign(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP, platform: 'windows');
      await tester.pumpAndSettle();
      container.read(toolProvider.notifier).select(EditorTool.pencil);
      await tester.pumpAndSettle();
      final c = tester.getCenter(find.byType(DesignCanvas));
      final g = await tester.startGesture(c, kind: PointerDeviceKind.mouse);
      for (var i = 0; i < 20; i++) {
        await g.moveBy(Offset(6, i.isEven ? 8 : -8));
      }
      await g.up();
      await tester.pumpAndSettle();
      final path = session().document.objects[roots().single]!;
      expect(path.name, 'Drawing');
      expect(localAnchors(path).anchors.length, greaterThan(3));
      expect(session().undoLabel, 'Draw');
    });

    testWidgets('double-click a path to edit nodes; Delete removes one', (
      tester,
    ) async {
      await openFirstDesign(tester);
      final page = session().activePage;
      final editor = container.read(editorProvider.notifier);
      final id = editor.insertPath(
        [
          PenAnchor(Point2D(page.width / 2 - 200, page.height / 2)),
          PenAnchor(Point2D(page.width / 2, page.height / 2 - 150)),
          PenAnchor(Point2D(page.width / 2 + 200, page.height / 2)),
        ],
        closed: true,
        pageId: page.id,
      );
      container.read(nodeEditProvider.notifier).value = NodeEdit(id);
      await tester.pumpAndSettle();
      final canvas = tester.getRect(find.byType(DesignCanvas));
      final viewport = container.read(viewportProvider);
      final frame = layoutPages(session().document.pages).first;
      Offset screenOf(Point2D p) =>
          canvas.topLeft + viewport.toScreen(frame.toWorkspace(p));
      // Drag the top point up.
      final top = screenOf(Point2D(page.width / 2, page.height / 2 - 150));
      final g = await tester.startGesture(top, kind: PointerDeviceKind.mouse);
      await g.moveBy(const Offset(0, -20));
      await g.moveBy(const Offset(0, -20));
      await g.up();
      await tester.pumpAndSettle();
      final moved = worldBounds(session().document, id)!;
      expect(moved.top, lessThan(page.height / 2 - 150));
      expect(session().undoLabel, 'Edit path');
      expect(container.read(nodeEditProvider)!.anchor, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      final path = session().document.objects[id]!;
      expect(localAnchors(path).anchors, hasLength(2));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(container.read(nodeEditProvider), isNull);
      expect(session().selection, {id});
    });

    testWidgets('colour: gradient fills from the inspector', (tester) async {
      await openFirstDesign(tester);
      container.read(editorProvider.notifier).insertShape(ObjectType.rect);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Linear gradient'));
      await tester.pumpAndSettle();
      final fill = session().document.objects[roots().single]!.style!.fill;
      expect(fill, isA<LinearGradientFill>());
      expect(session().undoLabel, 'Fill');
      await tester.tap(find.byTooltip('Radial gradient'));
      await tester.pumpAndSettle();
      expect(
        session().document.objects[roots().single]!.style!.fill,
        isA<RadialGradientFill>(),
      );
      await tester.tap(find.byTooltip('Solid colour'));
      await tester.pumpAndSettle();
      expect(
        session().document.objects[roots().single]!.style!.fill,
        isA<SolidFill>(),
      );
    });

    testWidgets('colour: the picker applies swatches and saves colours', (
      tester,
    ) async {
      await openFirstDesign(tester);
      container.read(editorProvider.notifier).insertShape(ObjectType.rect);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Choose colour').first);
      await tester.pumpAndSettle();
      expect(find.text('My colours'), findsOneWidget);
      await tester.tap(find.byTooltip('#E5484D'));
      await tester.pumpAndSettle();
      final fill = session().document.objects[roots().single]!.style!.fill;
      expect(fill!.representative.value & 0xFFFFFF, 0xE5484D);
      await tester.tap(find.byTooltip('Save this colour'));
      await tester.pumpAndSettle();
      expect(
        container.read(customPaletteProvider).first.value & 0xFFFFFF,
        0xE5484D,
      );
      expect(index.settings.get('palette.custom'), contains('e5484d'));
    });

    testWidgets('colour: text shows its contrast', (tester) async {
      await openFirstDesign(tester);
      container.read(editorProvider.notifier).insertText(TextRole.heading);
      await tester.pumpAndSettle();
      expect(find.textContaining('Contrast'), findsOneWidget);
      expect(find.textContaining('AAA'), findsOneWidget);
    });

    testWidgets('colour: the eyedropper samples the canvas', (tester) async {
      await openFirstDesign(tester);
      final editor = container.read(editorProvider.notifier)
        ..insertShape(ObjectType.rect);
      await tester.pumpAndSettle();
      final id = roots().single;
      editor.updateObject(
        id,
        (o) => o.copyWith(
          style: ObjectStyle(fill: SolidFill(ArgbColor(0xFF12A594))),
        ),
        label: 'Fill',
      );
      editor.clearSelection();
      await tester.pumpAndSettle();
      ArgbColor? picked;
      container.read(eyedropperProvider.notifier).pick = (c) => picked = c;
      final canvas = tester.getRect(find.byType(DesignCanvas));
      final viewport = container.read(viewportProvider);
      final frame = layoutPages(session().document.pages).first;
      final b = worldBounds(session().document, id)!;
      final at =
          canvas.topLeft +
          viewport.toScreen(
            frame.toWorkspace(
              Point2D(b.left + b.width / 2, b.top + b.height / 2),
            ),
          );
      await tester.runAsync(() async {
        await tester.tapAt(at, kind: PointerDeviceKind.mouse);
        for (var i = 0; i < 20 && picked == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      expect(picked?.value, 0xFF12A594);
      expect(container.read(eyedropperProvider), isNull);
    });

    testWidgets('present: pages play as a slideshow', (tester) async {
      await openFirstDesign(tester);
      container.read(editorProvider.notifier).addPage();
      await tester.pumpAndSettle();
      container
          .read(editorProvider.notifier)
          .setActivePage(session().document.pages.first.id);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsNothing);
      expect(find.byType(DesignCanvas), findsOneWidget);
    });

    testWidgets('prototype: clicking a linked object opens its frame', (
      tester,
    ) async {
      await openFirstDesign(tester);
      final editor = container.read(editorProvider.notifier)..addBoard();
      await tester.pumpAndSettle();
      final home = editor.insertFrame(
        width: 400,
        height: 800,
        name: 'Home',
        topLeft: Point2D.zero,
      );
      final next = editor.insertFrame(
        width: 400,
        height: 800,
        name: 'Details',
        topLeft: const Point2D(600, 0),
      );
      editor.insertDrawnShape(
        ObjectType.rect,
        ObjectTransform(x: 100, y: 300, width: 200, height: 200),
        pageId: session().activePage.id,
      );
      final button = session().selection.single;
      expect(session().document.objects[button]!.parentId, home);
      editor.setLink(button, next, transition: PrototypeTransition.instant);
      await tester.pumpAndSettle();
      expect(find.text('Prototype'), findsOneWidget);

      editor.clearSelection();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Present'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      // The 400 × 800 frame is fitted to the window; tap the button's
      // centre (page point 200, 400 = the frame's centre).
      final size = tester.getSize(find.byType(PresentPage));
      await tester.tapAt(Offset(size.width / 2, size.height / 2));
      await tester.pumpAndSettle();
      expect(find.text('Details'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('export: a board becomes a website', (tester) async {
      await openFirstDesign(tester);
      final editor = container.read(editorProvider.notifier)..addBoard();
      await tester.pumpAndSettle();
      editor
        ..insertFrame(
          width: 390,
          height: 844,
          name: 'Home',
          topLeft: Point2D.zero,
        )
        ..insertFrame(
          width: 390,
          height: 844,
          name: 'About us',
          topLeft: const Point2D(500, 0),
        )
        ..clearSelection();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Website'));
      await tester.pumpAndSettle();
      expect(find.text('Website · 2 HTML pages'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Export').last);
      await tester.pumpAndSettle();
      final (files, format) = exported.single;
      expect(format, ExportFormat.html);
      expect(files.map((f) => f.name), ['index.html', 'about-us.html']);
      expect(utf8.decode(files.first.bytes), contains('<svg'));
    });

    testWidgets('apps: install a plugin with approval and run it', (
      tester,
    ) async {
      final hasPython = () {
        try {
          return Process.runSync('python', ['--version']).exitCode == 0;
        } on ProcessException {
          return false;
        }
      }();
      if (!hasPython) return;
      await openFirstDesign(tester);
      await showTab(tester, RailTab.apps);
      expect(find.text('Placeholder text'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Placeholder text'),
          matching: find.text('Install'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Install Placeholder text?'), findsOneWidget);
      expect(find.text('Add, change and delete objects'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Install'));
      await tester.pumpAndSettle();
      expect(container.read(installedPluginsProvider), hasLength(1));
      container.read(developerModeProvider.notifier).enabled = true;
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Insert placeholder text'));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.tap(find.widgetWithText(FilledButton, 'Run'));
        for (var i = 0; i < 60 && roots().isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      final text = session().document.objects[roots().single]!;
      expect((text.payload as TextPayload).text, startsWith('Lorem ipsum'));
      expect(session().undoLabel, 'Placeholder text');
    });

    testWidgets('components: Ctrl+Alt+K makes a component', (tester) async {
      await openFirstDesign(tester);
      container.read(editorProvider.notifier)
        ..insertShape(ObjectType.rect)
        ..selectAll();
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(isComponent(session().document.objects[roots().single]), isTrue);
      expect(find.text('Main component'), findsOneWidget);
      await tester.tap(find.text('Create instance'));
      await tester.pumpAndSettle();
      expect(find.text('Instance'), findsWidgets);
      expect(roots(), hasLength(2));
    });

    testWidgets('tool shortcuts switch tools', (tester) async {
      await openFirstDesign(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.pumpAndSettle();
      expect(container.read(toolProvider).active, EditorTool.text);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(container.read(toolProvider).active, EditorTool.move);
    });

    testWidgets('keyboard: undo, redo, select all, duplicate, delete', (
      tester,
    ) async {
      await openFirstDesign(tester);
      await showElements(tester);
      await tester.tap(find.byTooltip('Ellipse'));
      await tester.pumpAndSettle();
      await chord(tester, LogicalKeyboardKey.keyZ);
      expect(roots(), isEmpty);
      await chord(tester, LogicalKeyboardKey.keyZ, shift: true);
      expect(roots(), hasLength(1));
      await chord(tester, LogicalKeyboardKey.keyA);
      await chord(tester, LogicalKeyboardKey.keyD);
      expect(roots(), hasLength(2));
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(roots(), hasLength(1));
    });

    testWidgets('alignment buttons are undoable', (tester) async {
      await openFirstDesign(tester);
      await showElements(tester);
      await tester.tap(find.byTooltip('Rectangle'));
      await tester.pumpAndSettle();
      final id = session().selection.single;
      await tester.tap(find.byTooltip('Align left to page'));
      await tester.pumpAndSettle();
      expect(session().document.objects[id]!.transform.x, 0);
      expect(session().undoLabel, 'Align');
    });

    testWidgets('layers: hovering a row reveals hide, which works', (
      tester,
    ) async {
      await openFirstDesign(tester);
      await showElements(tester);
      await tester.tap(find.byTooltip('Rectangle'));
      await tester.pumpAndSettle();
      await showTab(tester, RailTab.layers);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(find.text('Rectangle 1').first),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hide'));
      await tester.pumpAndSettle();
      expect(session().document.objects[roots().single]!.hidden, isTrue);
      await mouse.removePointer();
    });

    testWidgets('pages: add from the Pages panel', (tester) async {
      await openFirstDesign(tester);
      await showTab(tester, RailTab.pages);
      await tester.tap(find.text('Add page'));
      await tester.pumpAndSettle();
      expect(session().document.pages, hasLength(2));
      expect(find.text('Page 2'), findsWidgets);
    });

    testWidgets('page background can be made transparent', (tester) async {
      await openFirstDesign(tester);
      expect(find.text('Background'), findsOneWidget);
      await tester.tap(find.byTooltip('Make transparent'));
      await tester.pumpAndSettle();
      expect(session().activePage.background, const TransparentBackground());
    });

    testWidgets('renaming from the toolbar updates the title', (tester) async {
      await openFirstDesign(tester);
      await tester.tap(find.text('Launch poster'));
      await tester.pumpAndSettle();
      final titleField = find.byWidgetPredicate(
        (w) => w is TextField && w.autofocus,
      );
      await tester.enterText(titleField, 'Launch poster v2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(session().document.metadata.title, 'Launch poster v2');
    });

    testWidgets('going home saves and shows the design', (tester) async {
      await openFirstDesign(tester);
      await showElements(tester);
      await tester.tap(find.byTooltip('Rectangle'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Home'));
      await tester.pumpAndSettle();
      expect(container.read(editorProvider), isNull);
      expect(find.text('What will you design today?'), findsOneWidget);
      final saved = library.files.values.single;
      expect(saved.objects.values.single.type, ObjectType.rect);
      expect(defaultShapeFill, isNotNull);
    });
  });
}
