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
  }) : objects = Map.unmodifiable(objects),
       pages = pages == null ? null : List.unmodifiable(pages);

  /// User-facing name, e.g. "Move" — shown as "Undo Move".
  final String label;

  /// Objects to create/replace (non-null) or delete (`null`).
  final Map<ObjectId, DesignObject?> objects;

  /// Full replacement of the page list (order, settings, root order).
  final List<DesignPage>? pages;

  final DocumentMetadata? metadata;

  bool get isEmpty => objects.isEmpty && pages == null && metadata == null;

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
    final next = DesignDocument(
      id: document.id,
      metadata: metadata ?? document.metadata,
      pages: pages ?? document.pages,
      objects: nextObjects,
      styles: document.styles,
      assets: document.assets,
    );
    final undo = Change(
      label: label,
      objects: undoObjects,
      pages: pages == null ? null : document.pages,
      metadata: metadata == null ? null : document.metadata,
    );
    return (next, undo);
  }

  @override
  String toString() =>
      'Change($label: ${objects.length} objects'
      '${pages == null ? '' : ', pages'}'
      '${metadata == null ? '' : ', metadata'})';
}
