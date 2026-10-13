import 'dart:async';

import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_controller.dart';
import 'rulers.dart';
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
  static final export = cmd(LogicalKeyboardKey.keyE, shift: true);
  static final useAsMask = SingleActivator(
    LogicalKeyboardKey.keyM,
    control: !_isMac,
    meta: _isMac,
    alt: true,
  );
  static final createComponent = SingleActivator(
    LogicalKeyboardKey.keyK,
    control: !_isMac,
    meta: _isMac,
    alt: true,
  );
  static final detachInstance = SingleActivator(
    LogicalKeyboardKey.keyB,
    control: !_isMac,
    meta: _isMac,
    alt: true,
  );
  static const present = SingleActivator(LogicalKeyboardKey.f5);
  static final frameSelection = SingleActivator(
    LogicalKeyboardKey.keyG,
    control: !_isMac,
    meta: _isMac,
    alt: true,
  );
  static final ungroup = cmd(LogicalKeyboardKey.keyG, shift: true);
  static const rulers = SingleActivator(LogicalKeyboardKey.keyR, shift: true);
  static final grid = cmd(LogicalKeyboardKey.quote);
  static final guides = cmd(LogicalKeyboardKey.semicolon);
}

/// Fits the active page in the view.
void fitActivePage(WidgetRef ref) {
  final session = ref.read(editorProvider);
  if (session == null) return;
  final frames = layoutPages(
    session.document.pages,
    active: session.state.activePageId,
  );
  final frame = frames.firstWhere(
    (f) => f.pageId == session.state.activePageId,
  );
  ref.read(viewportProvider.notifier).fit(fitRectFor(session.document, frame));
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
Map<ShortcutActivator, VoidCallback> editorShortcuts(
  WidgetRef ref, {
  VoidCallback? onExport,
  VoidCallback? onPresent,
}) {
  final editor = ref.read(editorProvider.notifier);
  final view = ref.read(viewportProvider.notifier);
  final tools = ref.read(toolProvider.notifier);
  void nudge(int dx, int dy, {bool large = false}) =>
      editor.nudge(dx, dy, large: large);
  VoidCallback unlessTyping(VoidCallback action) => () {
    if (!_typing()) action();
  };
  void editSelectedText() {
    final crop = ref.read(cropModeProvider.notifier);
    if (crop.value != null) {
      crop.value = null;
      return;
    }
    final session = ref.read(editorProvider);
    if (session == null || session.selection.length != 1) return;
    final id = session.selection.first;
    if (session.document.objects[id]?.payload is TextPayload) {
      editor.startTextEdit(id);
    }
  }

  void deleteSelectionOrPoint() {
    final nodes = ref.read(nodeEditProvider);
    if (nodes?.anchor case final anchor?) {
      editor.deletePathAnchor(nodes!.id, anchor);
      ref.read(nodeEditProvider.notifier).value = NodeEdit(nodes.id);
      return;
    }
    editor.deleteSelection();
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
    EditorKeys.delete: deleteSelectionOrPoint,
    EditorKeys.backspace: deleteSelectionOrPoint,
    EditorKeys.escape: () {
      final crop = ref.read(cropModeProvider.notifier);
      if (crop.value != null) {
        crop.value = null;
        return;
      }
      final nodes = ref.read(nodeEditProvider.notifier);
      if (nodes.value != null) {
        nodes.value = null;
        return;
      }
      if (ref.read(toolProvider).active != EditorTool.move) {
        // Leaving the pen finishes the path being drawn.
        tools.reset();
        return;
      }
      editor.selectParentOrClear();
    },
    EditorKeys.group: editor.groupSelection,
    EditorKeys.createComponent: editor.createComponent,
    EditorKeys.useAsMask: editor.useSelectionAsMask,
    EditorKeys.detachInstance: editor.detachSelection,
    if (onExport != null) EditorKeys.export: onExport,
    if (onPresent != null) EditorKeys.present: onPresent,
    EditorKeys.frameSelection: editor.frameSelection,
    EditorKeys.rulers: unlessTyping(
      ref.read(canvasAidsProvider.notifier).toggleRulers,
    ),
    EditorKeys.grid: ref.read(canvasAidsProvider.notifier).toggleGrid,
    EditorKeys.guides: ref.read(canvasAidsProvider.notifier).toggleGuides,
    EditorKeys.ungroup: editor.ungroupSelection,
    EditorKeys.editText: unlessTyping(() {
      if (ref.read(toolProvider).active == EditorTool.pen) {
        tools.reset();
      } else {
        editSelectedText();
      }
    }),
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
    const SingleActivator(LogicalKeyboardKey.keyF): unlessTyping(
      () => tools.select(EditorTool.frame),
    ),
    const SingleActivator(LogicalKeyboardKey.keyP): unlessTyping(
      () => tools.select(EditorTool.pen),
    ),
    const SingleActivator(LogicalKeyboardKey.keyP, shift: true): unlessTyping(
      () => tools.select(EditorTool.pencil),
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
