import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storage/storage.dart';
import 'package:template_engine/template_engine.dart';

import '../editor/editor_controller.dart';
import '../editor/editor_page.dart';
import '../providers.dart';

/// Opens the design at [path] in the editor, explaining any crash recovery.
Future<void> openDesign(
  BuildContext context,
  WidgetRef ref,
  String path,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final editor = ref.read(editorProvider.notifier);
  try {
    final notice = await editor.open(path);
    if (notice == OpenNotice.newerAutosaveAvailable && context.mounted) {
      final restore = await _askRestore(context);
      if (restore ?? false) {
        final recovered = await ref
            .read(designLibraryProvider)
            .open(autosavePathFor(path));
        editor.start(path, recovered.contents.document, unsaved: true);
      }
    } else if (notice == OpenNotice.recoveredFromAutosave) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'The design file was damaged, so your latest automatic backup '
            'was opened instead.',
          ),
        ),
      );
    }
    await navigator.push(_editorRoute());
  } on Object catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not open this design. $error')),
    );
  }
}

/// Creates a design with [page] in the projects folder and opens it.
Future<void> createDesign(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required DesignPage page,
}) async {
  final folder = ref.read(projectsFolderProvider);
  if (folder == null) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final path = await ref
        .read(designLibraryProvider)
        .create(folder, title: title, page: page);
    ref.invalidate(designsProvider);
    if (context.mounted) await openDesign(context, ref, path);
  } on Object catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not create the design. $error')),
    );
  }
}

/// Creates a design from template [contents] (P2.2.4) — fresh ids, the
/// template's assets — and opens it.
Future<void> createFromTemplate(
  BuildContext context,
  WidgetRef ref, {
  required String name,
  required ProjectContents contents,
}) async {
  final folder = ref.read(projectsFolderProvider);
  if (folder == null) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final document = instantiateTemplate(contents.document, title: name);
    final path = await ref
        .read(designLibraryProvider)
        .createFrom(folder, document, assets: contents.assets);
    ref.invalidate(designsProvider);
    if (context.mounted) await openDesign(context, ref, path);
  } on Object catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not use this template. $error')),
    );
  }
}

Route<void> _editorRoute() => PageRouteBuilder<void>(
  pageBuilder: (_, _, _) => const EditorPage(),
  transitionDuration: const Duration(milliseconds: 220),
  reverseTransitionDuration: const Duration(milliseconds: 160),
  transitionsBuilder:
      (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: child,
      ),
);

Future<bool?> _askRestore(BuildContext context) => showDialog<bool>(
  context: context,
  builder:
      (context) => AlertDialog(
        icon: const Icon(Icons.history_rounded),
        title: const Text('Restore unsaved changes?'),
        content: const Text(
          'OpenCanvasX found newer changes from an automatic backup than the '
          'saved design. Neither version has been deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep saved version'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore latest changes'),
          ),
        ],
      ),
);
