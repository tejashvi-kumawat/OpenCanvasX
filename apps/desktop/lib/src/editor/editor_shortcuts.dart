import 'dart:async';

import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_controller.dart';
import 'tools.dart';
import 'viewport.dart';

bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

/// Ctrl+key on Windows/Linux, ⌘+key on macOS.
SingleActivator cmd(LogicalKeyboardKey key, {bool shift = false}) =>
    SingleActivator(key, control: !_isMac, meta: _isMac, shift: shift);

/// Every editor shortcut (ux-spec.md "Keyboard shortcuts"). Menus show the
/// same activators so labels and behaviour never drift apart.
abstract final class EditorKeys {
  static final undo = cmd(LogicalKeyboardKey.keyZ);
  static final redo = cmd(LogicalKeyboardKey.keyZ, shift: true);
  static final redoAlt = cmd(LogicalKeyboardKey.keyY);
  static final cut = cmd(LogicalKeyboardKey.keyX);
  static final copy = cmd(LogicalKeyboardKey.keyC);
  static final paste = cmd(LogicalKeyboardKey.keyV);
  static final duplicate = cmd(LogicalKeyboardKey.keyD);
  static final selectAll = cmd(LogicalKeyboardKey.keyA);
  static final save = cmd(LogicalKeyboardKey.keyS);
  static const delete = SingleActivator(LogicalKeyboardKey.delete);
  static const backspace = SingleActivator(LogicalKeyboardKey.backspace);
  static const escape = SingleActivator(LogicalKeyboardKey.escape);
  static const editText = SingleActivator(LogicalKeyboardKey.enter);
  static final zoomIn = cmd(LogicalKeyboardKey.equal);
  static final zoomInNumpad = cmd(LogicalKeyboardKey.numpadAdd);
  static final zoomOut = cmd(LogicalKeyboardKey.minus);
  static final zoomOutNumpad = cmd(LogicalKeyboardKey.numpadSubtract);
  static final fit = cmd(LogicalKeyboardKey.digit0);
  static final actualSize = cmd(LogicalKeyboardKey.digit1);
  static final addPage = cmd(LogicalKeyboardKey.enter);
  static final bringForward = cmd(LogicalKeyboardKey.bracketRight);
  static final sendBackward = cmd(LogicalKeyboardKey.bracketLeft);
  static final bringToFront = cmd(LogicalKeyboardKey.bracketRight, shift: true);
  static final sendToBack = cmd(LogicalKeyboardKey.bracketLeft, shift: true);
  static final group = cmd(LogicalKeyboardKey.keyG);
  static final ungroup = cmd(LogicalKeyboardKey.keyG, shift: true);
}

/// Fits the active page in the view.
void fitActivePage(WidgetRef ref) {
  final session = ref.read(editorProvider);
  if (session == null) return;
  final frame =
      layoutPages(session.document.pages)[session.state.activePageIndex];
  ref.read(viewportProvider.notifier).fit(frame.rect);
}

/// Whether keyboard focus is in a text field (single-key shortcuts must not
/// fire while typing).
bool _typing() {
  final focus = FocusManager.instance.primaryFocus?.context;
  return focus != null &&
      (focus.widget is EditableText ||
          focus.findAncestorWidgetOfExactType<EditableText>() != null);
}

/// Key bindings for [CallbackShortcuts] around the editor.
Map<ShortcutActivator, VoidCallback> editorShortcuts(WidgetRef ref) {
  final editor = ref.read(editorProvider.notifier);
  final view = ref.read(viewportProvider.notifier);
  final tools = ref.read(toolProvider.notifier);
  void nudge(int dx, int dy, {bool large = false}) =>
      editor.nudge(dx, dy, large: large);
  VoidCallback unlessTyping(VoidCallback action) => () {
    if (!_typing()) action();
  };
  void editSelectedText() {
    final session = ref.read(editorProvider);
    if (session == null || session.selection.length != 1) return;
    final id = session.selection.first;
    if (session.document.objects[id]?.payload is TextPayload) {
      editor.startTextEdit(id);
    }
  }

  return {
    EditorKeys.undo: editor.undo,
    EditorKeys.redo: editor.redo,
    EditorKeys.redoAlt: editor.redo,
    EditorKeys.cut: editor.cutSelection,
    EditorKeys.copy: editor.copySelection,
    EditorKeys.paste: editor.paste,
    EditorKeys.duplicate: editor.duplicateSelection,
    EditorKeys.selectAll: editor.selectAll,
    EditorKeys.save: () => unawaited(editor.saveNow()),
    EditorKeys.delete: editor.deleteSelection,
    EditorKeys.backspace: editor.deleteSelection,
    EditorKeys.escape: () {
      tools.reset();
      editor.selectParentOrClear();
    },
    EditorKeys.group: editor.groupSelection,
    EditorKeys.ungroup: editor.ungroupSelection,
    EditorKeys.editText: unlessTyping(editSelectedText),
    EditorKeys.zoomIn: view.zoomIn,
    EditorKeys.zoomInNumpad: view.zoomIn,
    EditorKeys.zoomOut: view.zoomOut,
    EditorKeys.zoomOutNumpad: view.zoomOut,
    EditorKeys.fit: () => fitActivePage(ref),
    EditorKeys.actualSize: () => view.setZoom(1),
    EditorKeys.addPage: editor.addPage,
    EditorKeys.bringForward: () => editor.arrange(ZOrderMove.forward),
    EditorKeys.sendBackward: () => editor.arrange(ZOrderMove.backward),
    EditorKeys.bringToFront: () => editor.arrange(ZOrderMove.toFront),
    EditorKeys.sendToBack: () => editor.arrange(ZOrderMove.toBack),
    // Tools (single keys, ignored while typing).
    const SingleActivator(LogicalKeyboardKey.keyV): unlessTyping(
      () => tools.select(EditorTool.move),
    ),
    const SingleActivator(LogicalKeyboardKey.keyH): unlessTyping(
      () => tools.select(EditorTool.hand),
    ),
    const SingleActivator(LogicalKeyboardKey.keyR): unlessTyping(
      () => tools.select(EditorTool.rect),
    ),
    const SingleActivator(LogicalKeyboardKey.keyO): unlessTyping(
      () => tools.select(EditorTool.ellipse),
    ),
    const SingleActivator(LogicalKeyboardKey.keyL): unlessTyping(
      () => tools.select(EditorTool.line),
    ),
    const SingleActivator(LogicalKeyboardKey.keyL, shift: true): unlessTyping(
      () => tools.select(EditorTool.arrow),
    ),
    const SingleActivator(LogicalKeyboardKey.keyT): unlessTyping(
      () => tools.select(EditorTool.text),
    ),
    const SingleActivator(LogicalKeyboardKey.arrowLeft): () => nudge(-1, 0),
    const SingleActivator(LogicalKeyboardKey.arrowRight): () => nudge(1, 0),
    const SingleActivator(LogicalKeyboardKey.arrowUp): () => nudge(0, -1),
    const SingleActivator(LogicalKeyboardKey.arrowDown): () => nudge(0, 1),
    const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
        () => nudge(-1, 0, large: true),
    const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
        () => nudge(1, 0, large: true),
    const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
        () => nudge(0, -1, large: true),
    const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
        () => nudge(0, 1, large: true),
  };
}
