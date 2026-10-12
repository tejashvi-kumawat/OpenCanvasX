import 'package:document_model/document_model.dart';
import 'package:meta/meta.dart';

/// One undoable edit to a [DesignDocument].
///
/// A change is data, not code: it lists objects to put (or delete, with a
/// `null` value), optionally a replacement page list and metadata. Applying
/// a change returns the new document **and its exact inverse**, so the
/// history never needs per-command undo logic (document-model.md
/// "Undo / redo"). The object-level shape also maps directly onto the
/// collaboration operations planned for Phase 4 (`ObjectCreated`,
/// `ObjectUpdated`, `ObjectDeleted`, `PageAdded`, …).
@immutable
final class Change {
  Change({
    required this.label,
    Map<ObjectId, DesignObject?> objects = const {},
    List<DesignPage>? pages,
    this.metadata,
    Map<String, AssetInfo?> assets = const {},
  }) : objects = Map.unmodifiable(objects),
       pages = pages == null ? null : List.unmodifiable(pages),
       assets = Map.unmodifiable(assets);

  /// User-facing name, e.g. "Move" — shown as "Undo Move".
  final String label;

  /// Objects to create/replace (non-null) or delete (`null`).
  final Map<ObjectId, DesignObject?> objects;

  /// Full replacement of the page list (order, settings, root order).
  final List<DesignPage>? pages;

  final DocumentMetadata? metadata;

  /// Asset index entries to add (non-null) or remove (`null`), by hash.
  /// The bytes themselves live outside the document (file-format.md).
  final Map<String, AssetInfo?> assets;

  bool get isEmpty =>
      objects.isEmpty && pages == null && metadata == null && assets.isEmpty;

  /// Applies this change to [document].
  ///
  /// Returns the edited document and the change that restores [document].
  (DesignDocument, Change) applyTo(DesignDocument document) {
    final nextObjects = Map<ObjectId, DesignObject>.of(document.objects);
    final undoObjects = <ObjectId, DesignObject?>{};
    for (final MapEntry(key: id, value: object) in objects.entries) {
      undoObjects[id] = document.objects[id];
      if (object == null) {
        nextObjects.remove(id);
      } else {
        nextObjects[id] = object;
      }
    }
    final nextAssets = Map<String, AssetInfo>.of(document.assets);
    final undoAssets = <String, AssetInfo?>{};
    for (final MapEntry(key: hash, value: info) in assets.entries) {
      undoAssets[hash] = document.assets[hash];
      if (info == null) {
        nextAssets.remove(hash);
      } else {
        nextAssets[hash] = info;
      }
    }
    final next = DesignDocument(
      id: document.id,
      metadata: metadata ?? document.metadata,
      pages: pages ?? document.pages,
      objects: nextObjects,
      styles: document.styles,
      assets: nextAssets,
    );
    final undo = Change(
      label: label,
      objects: undoObjects,
      pages: pages == null ? null : document.pages,
      metadata: metadata == null ? null : document.metadata,
      assets: undoAssets,
    );
    return (next, undo);
  }

  @override
  String toString() =>
      'Change($label: ${objects.length} objects'
      '${pages == null ? '' : ', pages'}'
      '${metadata == null ? '' : ', metadata'}'
      '${assets.isEmpty ? '' : ', ${assets.length} assets'})';
}
