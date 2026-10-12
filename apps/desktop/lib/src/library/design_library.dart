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

  /// Opens a design, with crash recovery (see `openProject`).
  Future<OpenedProject> open(String path);

  /// Saves atomically.
  Future<void> save(String path, DesignDocument document);
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
  Future<OpenedProject> open(String path) => openProject(path);

  @override
  Future<void> save(String path, DesignDocument document) =>
      saveProject(path, document);
}
