import 'package:document_model/document_model.dart';

import 'change.dart';

/// Undo/redo stacks of inverse changes (P1.8.1).
///
/// Every entry is the change that reverts one user action; applying it
/// yields the change that re-does the action, which moves to the other
/// stack. Named checkpoints and snapshots (P1.8.3) are separate and live in
/// `storage`.
final class History {
  History({this.limit = 200}) : assert(limit > 0, 'limit must be positive');

  /// Maximum undo steps kept; the oldest are dropped first.
  final int limit;

  final List<Change> _undo = [];
  final List<Change> _redo = [];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Label of the action [undo] would revert, e.g. "Move".
  String? get undoLabel => canUndo ? _undo.last.label : null;
  String? get redoLabel => canRedo ? _redo.last.label : null;

  /// Applies [change] to [document], records it and clears redo.
  DesignDocument apply(DesignDocument document, Change change) {
    if (change.isEmpty) return document;
    final (next, inverse) = change.applyTo(document);
    _push(_undo, inverse);
    _redo.clear();
    return next;
  }

  /// Records a change that was already applied, given its [inverse].
  /// Used when an edit was previewed live (e.g. while dragging).
  void recordApplied(Change inverse) {
    if (inverse.isEmpty) return;
    _push(_undo, inverse);
    _redo.clear();
  }

  /// Reverts the last action; returns [document] unchanged if none.
  DesignDocument undo(DesignDocument document) {
    if (!canUndo) return document;
    final (previous, redo) = _undo.removeLast().applyTo(document);
    _push(_redo, redo);
    return previous;
  }

  /// Re-applies the last undone action; returns [document] if none.
  DesignDocument redo(DesignDocument document) {
    if (!canRedo) return document;
    final (next, undo) = _redo.removeLast().applyTo(document);
    _push(_undo, undo);
    return next;
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }

  void _push(List<Change> stack, Change change) {
    stack.add(change);
    if (stack.length > limit) stack.removeAt(0);
  }
}
