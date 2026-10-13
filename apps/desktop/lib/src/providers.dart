import 'dart:io';

import 'package:asset_engine/asset_engine.dart';
import 'package:asset_packs/asset_packs.dart';
import 'package:document_model/document_model.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// A file the user picked: its name and bytes.
typedef PickedFile = ({String name, Uint8List bytes});

/// Shows a native "open" dialog for images and SVGs (P1.6.1, P1.6.2);
/// returns nothing if cancelled.
final imagePickerProvider = Provider<Future<List<PickedFile>> Function()>(
  (ref) => () async {
    final files = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Images',
          extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'svg'],
        ),
      ],
      confirmButtonText: 'Upload',
    );
    return [
      for (final f in files) (name: f.name, bytes: await f.readAsBytes()),
    ];
  },
);

/// The user's saved colours (P1.7.2), stored in the app index.
final customPaletteProvider =
    NotifierProvider<CustomPaletteController, List<ArgbColor>>(
      CustomPaletteController.new,
    );

class CustomPaletteController extends Notifier<List<ArgbColor>> {
  static const _key = 'palette.custom';

  @override
  List<ArgbColor> build() {
    final raw = ref.watch(appIndexProvider).settings.get(_key) ?? '';
    return [
      for (final part in raw.split(','))
        if (int.tryParse(part, radix: 16) case final v?
            when v >= 0 && v <= 0xFFFFFFFF)
          ArgbColor(v),
    ];
  }

  /// Saves [color] first in the list (at most 24, no duplicates).
  void add(ArgbColor color) {
    final next = [color, ...state.where((c) => c != color)].take(24).toList();
    ref
        .read(appIndexProvider)
        .settings
        .set(_key, [for (final c in next) c.value.toRadixString(16)].join(','));
    state = next;
  }
}

/// The project (workspace folder) chosen on Home; new designs go there.
final currentProjectProvider =
    NotifierProvider<CurrentProjectController, String?>(
      CurrentProjectController.new,
    );

class CurrentProjectController extends Notifier<String?> {
  @override
  String? build() => null;

  String? get folder => state;
  set folder(String? value) => state = value;
}

/// Project folders in the projects root (P2.5.3).
final workspaceProjectsProvider = FutureProvider<List<String>>((ref) async {
  final root = ref.watch(projectsFolderProvider);
  if (root == null) return const [];
  ref.watch(designsProvider);
  return ref.watch(designLibraryProvider).listProjectFolders(root);
});

/// Bundled asset packs (icons, stickers) with licence metadata (P2.1).
final assetCatalogProvider = FutureProvider<AssetCatalog>(
  (ref) => loadBundledCatalog(rootBundle),
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

/// Bundled open-licence font families, registered with the engine.
final bundledFontsProvider = FutureProvider<List<BundledFont>>(
  (ref) => loadBundledFonts(rootBundle),
);

/// The user's display name (P1.10.6): recorded as the author of new
/// designs. Stays on this computer; `null` when not given.
final profileNameProvider = NotifierProvider<ProfileNameController, String?>(
  ProfileNameController.new,
);

class ProfileNameController extends Notifier<String?> {
  static const _key = 'profile.name';

  @override
  String? build() {
    final name = ref.watch(appIndexProvider).settings.get(_key)?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  String? get name => state;

  set name(String? value) {
    final clean = value?.trim();
    final settings = ref.read(appIndexProvider).settings;
    if (clean == null || clean.isEmpty) {
      settings.remove(_key);
      state = null;
    } else {
      settings.set(_key, clean);
      state = clean;
    }
  }
}
