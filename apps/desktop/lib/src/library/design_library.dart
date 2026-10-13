import 'dart:io';

import 'package:document_model/document_model.dart';
import 'package:flutter/foundation.dart';
import 'package:storage/storage.dart';

/// What the home screen needs to show one design.
@immutable
class DesignSummary {
  const DesignSummary({
    required this.path,
    required this.title,
    required this.modified,
    this.document,
    this.error,
  });

  final String path;
  final String title;
  final DateTime modified;

  /// The decoded design, for the cover thumbnail; `null` if unreadable.
  final DesignDocument? document;

  /// Why the file could not be read, if it could not.
  final String? error;

  DesignPage? get cover => document?.pages.firstOrNull;
  int get pageCount => document?.pages.length ?? 0;
}

/// All file access the app UI needs, behind one seam so screens can be
/// tested without touching the disk.
abstract interface class DesignLibrary {
  /// Designs in [folder], most recently modified first.
  Future<List<DesignSummary>> list(String folder);

  /// Creates and saves a new one-page design; returns its path.
  Future<String> create(
    String folder, {
    required String title,
    required DesignPage page,
  });

  /// Saves [document] (e.g. made from a template) as a new design in
  /// [folder]; returns its path.
  Future<String> createFrom(
    String folder,
    DesignDocument document, {
    Map<String, Uint8List> assets = const {},
  });

  /// Opens a design, with crash recovery (see `openProject`).
  Future<OpenedProject> open(String path);

  /// Project folders in [root] (workspaces, P2.5.3).
  Future<List<String>> listProjectFolders(String root);

  /// Creates a project folder named [name] in [root]; returns its path.
  Future<String> createProjectFolder(String root, String name);

  /// Moves the design at [path] into [folder]; returns its new path.
  Future<String> move(String path, String folder);

  /// Moves the design at [path] to the root's trash (recoverable).
  Future<void> trash(String root, String path);

  /// Copies the design at [path] as "<title> copy"; returns the new path.
  Future<String> duplicate(String path);

  /// Renames the design at [path].
  Future<void> rename(String path, String title);

  /// Saves atomically, with the bytes of the document's assets.
  Future<void> save(
    String path,
    DesignDocument document, {
    Map<String, Uint8List> assets = const {},
  });
}

/// [DesignLibrary] backed by `.opencanvasx` files.
class FileDesignLibrary implements DesignLibrary {
  const FileDesignLibrary();

  @override
  Future<List<DesignSummary>> list(String folder) async {
    final paths = await findProjects(folder);
    final summaries = await Future.wait(paths.map(_summarize));
    return summaries..sort((a, b) => b.modified.compareTo(a.modified));
  }

  Future<DesignSummary> _summarize(String path) async {
    final file = File(path);
    final modified = file.lastModifiedSync();
    try {
      final contents = await readProjectFile(path);
      return DesignSummary(
        path: path,
        title: contents.document.metadata.title,
        modified: modified,
        document: contents.document,
      );
    } on Object catch (error) {
      final name = path.split(Platform.pathSeparator).last;
      return DesignSummary(
        path: path,
        title: name.replaceAll(projectFileExtension, ''),
        modified: modified,
        error: '$error',
      );
    }
  }

  @override
  Future<String> create(
    String folder, {
    required String title,
    required DesignPage page,
  }) async {
    final path = newProjectPath(folder, title);
    final now = DateTime.now();
    await saveProject(
      path,
      DesignDocument(
        id: DocumentId.generate(),
        metadata: DocumentMetadata(
          title: title.trim().isEmpty ? 'Untitled design' : title.trim(),
          createdAt: now,
          modifiedAt: now,
        ),
        pages: [page],
      ),
    );
    return path;
  }

  @override
  Future<String> createFrom(
    String folder,
    DesignDocument document, {
    Map<String, Uint8List> assets = const {},
  }) async {
    final path = newProjectPath(folder, document.metadata.title);
    await saveProject(path, document, assets: assets);
    return path;
  }

  @override
  Future<OpenedProject> open(String path) => openProject(path);

  @override
  Future<List<String>> listProjectFolders(String root) async =>
      listWorkspaceProjects(root);

  @override
  Future<String> createProjectFolder(String root, String name) =>
      createWorkspaceProject(root, name);

  @override
  Future<String> move(String path, String folder) => moveDesign(path, folder);

  @override
  Future<void> trash(String root, String path) => trashDesign(root, path);

  @override
  Future<String> duplicate(String path) => duplicateDesign(path);

  @override
  Future<void> rename(String path, String title) => renameDesign(path, title);

  @override
  Future<void> save(
    String path,
    DesignDocument document, {
    Map<String, Uint8List> assets = const {},
  }) => saveProject(path, document, assets: assets);
}
