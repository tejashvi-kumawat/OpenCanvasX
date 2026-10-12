import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencanvasx/main.dart';
import 'package:opencanvasx/src/editor/editor_controller.dart';
import 'package:opencanvasx/src/editor/viewport.dart';
import 'package:opencanvasx/src/providers.dart';
import 'package:storage/storage.dart';

import 'support/fakes.dart';

const _folder = '/home/me/Documents/OpenCanvasX';

void main() {
  late AppIndex index;
  late InMemoryDesignLibrary library;
  late ProviderContainer container;

  setUp(() {
    index = AppIndex.inMemory();
    library = InMemoryDesignLibrary();
  });

  tearDown(() => index.close());

  Future<void> pumpApp(WidgetTester tester, {bool withFolder = true}) async {
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
      ],
    );
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

  Future<void> openFirstDesign(WidgetTester tester) async {
    library.seed(_folder, 'Launch poster');
    await pumpApp(tester);
    await tester.tap(find.text('Launch poster'));
    await tester.pumpAndSettle();
  }

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
    testWidgets('explains privacy and offers the suggested folder', (
      tester,
    ) async {
      await pumpApp(tester, withFolder: false);
      expect(find.text('Welcome to OpenCanvasX'), findsOneWidget);
      expect(find.text('Documents › OpenCanvasX'), findsOneWidget);
      expect(find.textContaining('No account, no uploads'), findsOneWidget);
    });

    testWidgets('using the suggested folder goes to home', (tester) async {
      await pumpApp(tester, withFolder: false);
      await tester.tap(find.text('Use this folder'));
      await tester.pumpAndSettle();
      expect(find.text('What will you design today?'), findsOneWidget);
      expect(index.settings.get(AppSettings.projectsRootKey), _folder);
    });
  });

  group('home', () {
    testWidgets('shows an inviting empty state', (tester) async {
      await pumpApp(tester);
      expect(find.text('No designs yet'), findsOneWidget);
      expect(find.text('Create your first design'), findsOneWidget);
      expect(find.text('Instagram post'), findsOneWidget);
    });

    testWidgets('lists designs as cards with their size', (tester) async {
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

    testWidgets('a preset tile creates a design and opens the editor', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('Story'));
      await tester.pumpAndSettle();
      expect(library.files, hasLength(1));
      final page = session().activePage;
      expect((page.width, page.height), (1080.0, 1920.0));
      expect(find.text('Untitled Story'), findsOneWidget);
      expect(find.text('Elements'), findsWidgets);
    });

    testWidgets('the create dialog supports custom sizes', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Create a design'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom size').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('mm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create design'));
      await tester.pumpAndSettle();
      expect(session().activePage.unit, LengthUnit.mm);
    });
  });

  group('editor', () {
    testWidgets('adds a shape from the Elements panel and inspects it', (
      tester,
    ) async {
      await openFirstDesign(tester);
      await tester.tap(find.text('Rectangle'));
      await tester.pumpAndSettle();
      expect(session().activePage.objectIds, hasLength(1));
      expect(find.text('Rectangle 1'), findsOneWidget);
      expect(find.text('POSITION'), findsOneWidget);
      expect(find.text('All changes saved'), findsOneWidget);
    });

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

    testWidgets('keyboard shortcuts: undo, redo, duplicate, delete', (
      tester,
    ) async {
      await openFirstDesign(tester);
      await tester.tap(find.text('Circle'));
      await tester.pumpAndSettle();
      await chord(tester, LogicalKeyboardKey.keyZ);
      expect(session().activePage.objectIds, isEmpty);
      await chord(tester, LogicalKeyboardKey.keyZ, shift: true);
      expect(session().activePage.objectIds, hasLength(1));
      await chord(tester, LogicalKeyboardKey.keyA);
      await chord(tester, LogicalKeyboardKey.keyD);
      expect(session().activePage.objectIds, hasLength(2));
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(session().activePage.objectIds, hasLength(1));
    });

    testWidgets('inspector edits are undoable', (tester) async {
      await openFirstDesign(tester);
      await tester.tap(find.text('Rectangle'));
      await tester.pumpAndSettle();
      final id = session().selection.single;
      await tester.tap(find.byTooltip('Align Left'));
      await tester.pumpAndSettle();
      expect(session().document.objects[id]!.transform.x, 0);
      expect(session().undoLabel, 'Align');
    });

    testWidgets('layers panel lists elements and hides them', (tester) async {
      await openFirstDesign(tester);
      await tester.tap(find.text('Rectangle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Layers'));
      await tester.pumpAndSettle();
      expect(find.text('Rectangle 1'), findsWidgets);
      await tester.tap(find.byTooltip('Hide'));
      await tester.pumpAndSettle();
      final id = session().activePage.objectIds.single;
      expect(session().document.objects[id]!.hidden, isTrue);
    });

    testWidgets('pages can be added from the bottom bar', (tester) async {
      await openFirstDesign(tester);
      expect(find.text('Page 1 of 1'), findsOneWidget);
      await tester.tap(find.byTooltip('Add page').last);
      await tester.pumpAndSettle();
      expect(find.text('Page 2 of 2'), findsOneWidget);
    });

    testWidgets('page inspector changes the background', (tester) async {
      await openFirstDesign(tester);
      expect(find.text('BACKGROUND'), findsOneWidget);
      await tester.tap(find.byTooltip('None').first);
      await tester.pumpAndSettle();
      expect(session().activePage.background, const TransparentBackground());
    });

    testWidgets('renaming from the top bar updates the title', (tester) async {
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

    testWidgets('going home saves and shows the updated design', (
      tester,
    ) async {
      await openFirstDesign(tester);
      await tester.tap(find.text('Rectangle'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back to home'));
      await tester.pumpAndSettle();
      expect(container.read(editorProvider), isNull);
      expect(find.text('What will you design today?'), findsOneWidget);
      final saved = library.files.values.single;
      expect(saved.objects.values.single.type, ObjectType.rect);
      expect(defaultShapeFill, isNotNull);
    });
  });
}
