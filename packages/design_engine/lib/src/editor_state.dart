import 'package:document_model/document_model.dart';
import 'package:meta/meta.dart';

import 'groups.dart';

/// What the editor shows: the document, the page being edited and the
/// selected objects. Selection is ephemeral and never saved
/// (document-model.md "Selection and hit-testing").
@immutable
final class EditorState {
  EditorState({
    required this.document,
    required this.activePageId,
    Set<ObjectId> selection = const {},
  }) : selection = Set.unmodifiable(selection);

  /// Starts on the first page with nothing selected.
  factory EditorState.initial(DesignDocument document) {
    if (document.pages.isEmpty) {
      throw ArgumentError.value(document, 'document', 'has no pages');
    }
    return EditorState(
      document: document,
      activePageId: document.pages.first.id,
    );
  }

  final DesignDocument document;
  final PageId activePageId;

  /// Selected objects on the active page: roots, or objects inside groups
  /// (entered with a double-click).
  final Set<ObjectId> selection;

  DesignPage get activePage => document.pages.firstWhere(
    (p) => p.id == activePageId,
    orElse: () => document.pages.first,
  );

  int get activePageIndex {
    final index = document.pages.indexWhere((p) => p.id == activePageId);
    return index < 0 ? 0 : index;
  }

  /// Selected objects in z-order (back to front).
  List<DesignObject> get selectedObjects => [
    for (final id in pageObjectsInOrder(document, activePage))
      if (selection.contains(id))
        if (document.objects[id] case final object?) object,
  ];

  EditorState copyWith({
    DesignDocument? document,
    PageId? activePageId,
    Set<ObjectId>? selection,
  }) =>
      EditorState(
        document: document ?? this.document,
        activePageId: activePageId ?? this.activePageId,
        selection: selection ?? this.selection,
      ).normalized();

  /// Repairs the state after an edit or undo: the active page must exist and
  /// the selection may only hold existing objects on that page.
  EditorState normalized() {
    final page = activePage;
    final valid =
        selection
            .where(
              (id) =>
                  document.objects.containsKey(id) &&
                  rootOf(document, id)?.pageId == page.id,
            )
            .toSet();
    if (page.id == activePageId && valid.length == selection.length) {
      return this;
    }
    return EditorState(
      document: document,
      activePageId: page.id,
      selection: valid,
    );
  }
}
