import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:storage/storage.dart';

import 'library/design_library.dart';

/// App-wide SQLite index. Opened in `main()` and supplied with
/// `appIndexProvider.overrideWithValue(...)`.
final appIndexProvider = Provider<AppIndex>(
  (ref) => throw UnimplementedError('appIndexProvider must be overridden'),
);

/// Design file passed on the command line (or by "Open with"), if any.
final launchFileProvider = Provider<String?>((ref) => null);

/// All design file access; tests substitute an in-memory library.
final designLibraryProvider = Provider<DesignLibrary>(
  (ref) => const FileDesignLibrary(),
);

/// Shows a native folder picker; returns `null` if the user cancels.
typedef FolderPicker = Future<String?> Function({String? initialDirectory});

final folderPickerProvider = Provider<FolderPicker>(
  (ref) =>
      ({initialDirectory}) => getDirectoryPath(
        initialDirectory: initialDirectory,
        confirmButtonText: 'Use this folder',
      ),
);

/// Checks a candidate projects folder; tests replace it.
typedef FolderChecker = Future<ProjectsFolderProblem?> Function(String path);

final folderCheckerProvider = Provider<FolderChecker>(
  (ref) => checkProjectsFolder,
);

/// Creates a folder (and parents); tests replace it.
final folderCreatorProvider = Provider<Future<void> Function(String path)>(
  (ref) => (path) => Directory(path).create(recursive: true),
);

/// Suggested projects folder for first run: `Documents/OpenCanvasX`.
final suggestedProjectsFolderProvider = FutureProvider<String>((ref) async {
  final documents = await getApplicationDocumentsDirectory();
  return '${documents.path}${Platform.pathSeparator}OpenCanvasX';
});

/// The folder where projects live (P1.1.7), or `null` before the user has
/// chosen one. Persisted in the app index settings.
final projectsFolderProvider =
    NotifierProvider<ProjectsFolderController, String?>(
      ProjectsFolderController.new,
    );

class ProjectsFolderController extends Notifier<String?> {
  @override
  String? build() =>
      ref.watch(appIndexProvider).settings.get(AppSettings.projectsRootKey);

  /// Lets the user pick a folder. Returns `null` when a usable folder was
  /// saved or the picker was cancelled, otherwise why it was refused.
  Future<ProjectsFolderProblem?> choose() async {
    final picked = await ref.read(folderPickerProvider)(
      initialDirectory: state,
    );
    if (picked == null) return null;
    return use(picked);
  }

  /// Uses [path], creating it first when [create] is set (the suggested
  /// default folder may not exist yet).
  Future<ProjectsFolderProblem?> use(String path, {bool create = false}) async {
    if (create) {
      try {
        await ref.read(folderCreatorProvider)(path);
      } on FileSystemException {
        return ProjectsFolderProblem.notWritable;
      }
    }
    final problem = await ref.read(folderCheckerProvider)(path);
    if (problem != null) return problem;
    ref.read(appIndexProvider).settings.set(AppSettings.projectsRootKey, path);
    state = path;
    return null;
  }
}

/// Whether the saved projects folder is still usable (e.g. a removed USB
/// drive makes it `notFound`).
final projectsFolderStatusProvider = FutureProvider<ProjectsFolderProblem?>((
  ref,
) async {
  final folder = ref.watch(projectsFolderProvider);
  return folder == null ? null : ref.watch(folderCheckerProvider)(folder);
});

/// Designs in the projects folder, newest first.
final designsProvider = FutureProvider<List<DesignSummary>>((ref) async {
  final folder = ref.watch(projectsFolderProvider);
  if (folder == null) return const [];
  return ref.watch(designLibraryProvider).list(folder);
});

/// User-facing explanation for a refused projects folder.
String describeFolderProblem(ProjectsFolderProblem problem) =>
    switch (problem) {
      ProjectsFolderProblem.notFound => 'That folder no longer exists.',
      ProjectsFolderProblem.notAFolder => 'That is a file, not a folder.',
      ProjectsFolderProblem.notWritable =>
        'OpenCanvasX cannot save files in that folder. Choose another one.',
    };

/// Light, dark or follow the system (P1.10.3), persisted in settings.
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final saved = ref.watch(appIndexProvider).settings.get(_key);
    return ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  void set(ThemeMode mode) {
    ref.read(appIndexProvider).settings.set(_key, mode.name);
    state = mode;
  }
}
