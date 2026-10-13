import 'dart:convert';
import 'dart:io';

import 'package:document_model/document_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:opencanvasx/main.dart';
import 'package:opencanvasx/src/editor/editor_controller.dart';
import 'package:opencanvasx/src/export/exporter.dart';
import 'package:opencanvasx/src/library/design_library.dart';
import 'package:opencanvasx/src/providers.dart';
import 'package:design_engine/design_engine.dart';
import 'package:export_engine/export_engine.dart' show ExportScope;
import 'package:storage/storage.dart';

/// Phase 1 exit gate, run inside the real app on each OS
/// (`flutter test integration_test -d windows|linux|macos`): create,
/// edit, save, reopen and export a multi-page design offline, with the
/// real file library, engine, fonts and encoders.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('multi-page design: create, edit, save, reopen, export', (
    tester,
  ) async {
    final attempts = <Uri>[];
    HttpOverrides.global = _NoNetwork(attempts);
    final tmp = Directory.systemTemp.createTempSync('ocx_exit_gate');
    final designs = Directory('${tmp.path}/designs')..createSync();
    final index = AppIndex.open('${tmp.path}/index.sqlite');
    index.settings.set(AppSettings.projectsRootKey, designs.path);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appIndexProvider.overrideWithValue(index)],
        child: const OpenCanvasXApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('What will you design today?'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OpenCanvasXApp)),
    );

    // Create.
    const library = FileDesignLibrary();
    final path = await library.create(
      designs.path,
      title: 'Exit gate',
      page: DesignPage(id: PageId.generate(), width: 1080, height: 1080),
    );
    expect(File(path).existsSync(), isTrue);

    // Edit: two pages with shapes and text.
    final editor = container.read(editorProvider.notifier);
    await editor.open(path);
    await tester.pumpAndSettle();
    editor
      ..insertShape(ObjectType.rect)
      ..insertShape(ObjectType.star)
      ..insertText(TextRole.heading, text: 'Page one');
    editor.addPage();
    editor
      ..insertShape(ObjectType.ellipse)
      ..insertText(TextRole.body, text: 'Page two');
    await tester.pumpAndSettle();
    final edited = container.read(editorProvider)!.document;
    expect(edited.pages, hasLength(2));

    // Save, close and reopen from disk.
    await editor.saveNow();
    await editor.close();
    await tester.pumpAndSettle();
    final reopened = (await library.open(path)).contents.document;
    expect(reopened.pages, hasLength(2));
    expect(reopened.objects.length, edited.objects.length);
    final texts = {
      for (final o in reopened.objects.values)
        if (o.payload case TextPayload(:final text)) text,
    };
    expect(texts, {'Page one', 'Page two'});

    // Export every format.
    await editor.open(path);
    await tester.pumpAndSettle();
    final session = container.read(editorProvider)!;
    final out = Directory('${tmp.path}/exports')..createSync();
    for (final format in ExportFormat.values) {
      final files = await buildExport(
        session.document,
        options: ExportOptions(
          format: format,
          scope: ExportScope.allPages,
          scale: 0.5,
        ),
        activePage: session.state.activePageId,
        selection: const {},
        media: container.read(mediaCacheProvider),
      );
      expect(files, isNotEmpty, reason: '$format');
      for (final f in files) {
        File('${out.path}/${f.name}').writeAsBytesSync(f.bytes);
        expect(f.bytes.length, greaterThan(50), reason: f.name);
      }
      final head = files.first.bytes;
      switch (format) {
        case ExportFormat.png:
          expect(head.sublist(1, 4), 'PNG'.codeUnits);
          expect(files, hasLength(2));
        case ExportFormat.jpg:
          expect(head.sublist(0, 2), [0xFF, 0xD8]);
        case ExportFormat.webp:
          expect(latin1.decode(head.sublist(8, 12)), 'WEBP');
        case ExportFormat.pdf:
          expect(latin1.decode(head.sublist(0, 5)), '%PDF-');
        case ExportFormat.svg:
          expect(utf8.decode(head), contains('<svg'));
        case ExportFormat.html:
          expect(files.map((f) => f.name), contains('index.html'));
      }
    }
    await editor.close();
    await tester.pumpAndSettle();

    expect(attempts, isEmpty, reason: 'no network during core work');
    // Printed so the per-OS run shows where the exported files are.
    // ignore: avoid_print
    print('EXIT GATE OK on ${Platform.operatingSystem}: ${out.path}');
    index.close();
  });
}

class _NoNetwork extends HttpOverrides {
  _NoNetwork(this.attempts);

  final List<Uri> attempts;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts.add(Uri(path: 'createHttpClient'));
    return super.createHttpClient(context);
  }
}
