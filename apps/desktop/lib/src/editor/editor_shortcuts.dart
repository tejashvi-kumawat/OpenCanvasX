import 'dart:convert';
import 'dart:async';

import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'editor_controller.dart';
import 'rulers.dart';
import 'tools.dart';
import 'viewport.dart';

bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

/// Ctrl+key on Windows/Linux, ⌘+key on macOS.
SingleActivator cmd(LogicalKeyboardKey key, {bool shift = false}) =>
    SingleActivator(key, control: !_isMac, meta: _isMac, shift: shift);

SingleActivator _cmdAlt(LogicalKeyboardKey key) =>
    SingleActivator(key, control: !_isMac, meta: _isMac, alt: true);

/// Editor shortcuts the user can change (P1.10.4).
enum ShortcutId {
  undo('Undo'),
  redo('Redo'),
  cut('Cut'),
  copy('Copy'),
  paste('Paste'),
  duplicate('Duplicate'),
  selectAll('Select all'),
  save('Save'),
  export('Export'),
  present('Present'),
  commandPalette('Command palette'),
  zoomIn('Zoom in'),
  zoomOut('Zoom out'),
  fit('Zoom to fit page'),
  actualSize('Actual size'),
  rulers('Rulers'),
  guides('Guides'),
  grid('Grid'),
  addPage('Add page'),
  group('Group'),
  ungroup('Ungroup'),
  frameSelection('Frame selection'),
  useAsMask('Use as mask'),
  createComponent('Create component'),
  detachInstance('Detach instance'),
  bringForward('Bring forward'),
  sendBackward('Send backward'),
  bringToFront('Bring to front'),
  sendToBack('Send to back'),
  bold('Bold'),
  italic('Italic'),
  underline('Underline');

  const ShortcutId(this.label);

  final String label;
}

/// Built-in key for each [ShortcutId] (ux-spec.md "Keyboard shortcuts").
final Map<ShortcutId, SingleActivator> defaultShortcuts = {
  ShortcutId.undo: cmd(LogicalKeyboardKey.keyZ),
  ShortcutId.redo: cmd(LogicalKeyboardKey.keyZ, shift: true),
  ShortcutId.cut: cmd(LogicalKeyboardKey.keyX),
  ShortcutId.copy: cmd(LogicalKeyboardKey.keyC),
  ShortcutId.paste: cmd(LogicalKeyboardKey.keyV),
  ShortcutId.duplicate: cmd(LogicalKeyboardKey.keyD),
  ShortcutId.selectAll: cmd(LogicalKeyboardKey.keyA),
  ShortcutId.save: cmd(LogicalKeyboardKey.keyS),
  ShortcutId.export: cmd(LogicalKeyboardKey.keyE, shift: true),
  ShortcutId.present: const SingleActivator(LogicalKeyboardKey.f5),
  ShortcutId.commandPalette: cmd(LogicalKeyboardKey.keyK),
  ShortcutId.zoomIn: cmd(LogicalKeyboardKey.equal),
  ShortcutId.zoomOut: cmd(LogicalKeyboardKey.minus),
  ShortcutId.fit: cmd(LogicalKeyboardKey.digit0),
  ShortcutId.actualSize: cmd(LogicalKeyboardKey.digit1),
  ShortcutId.rulers: const SingleActivator(
    LogicalKeyboardKey.keyR,
    shift: true,
  ),
  ShortcutId.guides: cmd(LogicalKeyboardKey.semicolon),
  ShortcutId.grid: cmd(LogicalKeyboardKey.quote),
  ShortcutId.addPage: cmd(LogicalKeyboardKey.enter),
  ShortcutId.group: cmd(LogicalKeyboardKey.keyG),
  ShortcutId.ungroup: cmd(LogicalKeyboardKey.keyG, shift: true),
  ShortcutId.frameSelection: _cmdAlt(LogicalKeyboardKey.keyG),
  ShortcutId.useAsMask: _cmdAlt(LogicalKeyboardKey.keyM),
  ShortcutId.createComponent: _cmdAlt(LogicalKeyboardKey.keyK),
  ShortcutId.detachInstance: _cmdAlt(LogicalKeyboardKey.keyB),
  ShortcutId.bringForward: cmd(LogicalKeyboardKey.bracketRight),
  ShortcutId.sendBackward: cmd(LogicalKeyboardKey.bracketLeft),
  ShortcutId.bringToFront: cmd(LogicalKeyboardKey.bracketRight, shift: true),
  ShortcutId.sendToBack: cmd(LogicalKeyboardKey.bracketLeft, shift: true),
  ShortcutId.bold: cmd(LogicalKeyboardKey.keyB),
  ShortcutId.italic: cmd(LogicalKeyboardKey.keyI),
  ShortcutId.underline: cmd(LogicalKeyboardKey.keyU),
};

/// Every editor shortcut. Menus show the same activators so labels and
/// behaviour never drift apart; most can be changed by the user.
abstract final class EditorKeys {
  static SingleActivator get undo => _key(ShortcutId.undo);
  static SingleActivator get redo => _key(ShortcutId.redo);
  static SingleActivator get cut => _key(ShortcutId.cut);
  static SingleActivator get copy => _key(ShortcutId.copy);
  static SingleActivator get paste => _key(ShortcutId.paste);
  static SingleActivator get duplicate => _key(ShortcutId.duplicate);
  static SingleActivator get selectAll => _key(ShortcutId.selectAll);
  static SingleActivator get save => _key(ShortcutId.save);
  static SingleActivator get export => _key(ShortcutId.export);
  static SingleActivator get present => _key(ShortcutId.present);
  static SingleActivator get commandPalette => _key(ShortcutId.commandPalette);
  static SingleActivator get zoomIn => _key(ShortcutId.zoomIn);
  static SingleActivator get zoomOut => _key(ShortcutId.zoomOut);
  static SingleActivator get fit => _key(ShortcutId.fit);
  static SingleActivator get actualSize => _key(ShortcutId.actualSize);
  static SingleActivator get rulers => _key(ShortcutId.rulers);
  static SingleActivator get guides => _key(ShortcutId.guides);
  static SingleActivator get grid => _key(ShortcutId.grid);
  static SingleActivator get addPage => _key(ShortcutId.addPage);
  static SingleActivator get group => _key(ShortcutId.group);
  static SingleActivator get ungroup => _key(ShortcutId.ungroup);
  static SingleActivator get frameSelection => _key(ShortcutId.frameSelection);
  static SingleActivator get useAsMask => _key(ShortcutId.useAsMask);
  static SingleActivator get createComponent =>
      _key(ShortcutId.createComponent);
  static SingleActivator get detachInstance => _key(ShortcutId.detachInstance);
  static SingleActivator get bringForward => _key(ShortcutId.bringForward);
  static SingleActivator get sendBackward => _key(ShortcutId.sendBackward);
  static SingleActivator get bringToFront => _key(ShortcutId.bringToFront);
  static SingleActivator get sendToBack => _key(ShortcutId.sendToBack);
  static SingleActivator get bold => _key(ShortcutId.bold);
  static SingleActivator get italic => _key(ShortcutId.italic);
  static SingleActivator get underline => _key(ShortcutId.underline);
  static final redoAlt = cmd(LogicalKeyboardKey.keyY);
  static const delete = SingleActivator(LogicalKeyboardKey.delete);
  static const backspace = SingleActivator(LogicalKeyboardKey.backspace);
  static const escape = SingleActivator(LogicalKeyboardKey.escape);
  static const editText = SingleActivator(LogicalKeyboardKey.enter);
  static final zoomInNumpad = cmd(LogicalKeyboardKey.numpadAdd);
  static final zoomOutNumpad = cmd(LogicalKeyboardKey.numpadSubtract);
}

/// The user's changes to [defaultShortcuts]; kept in sync by
/// [shortcutOverridesProvider].
Map<ShortcutId, SingleActivator> _overrides = const {};

SingleActivator _key(ShortcutId id) => _overrides[id] ?? defaultShortcuts[id]!;

/// The key currently bound to [id].
SingleActivator shortcutFor(ShortcutId id) => _key(id);

/// Writes [a] as e.g. `ctrl+shift+<key id>` for the settings file.
String encodeActivator(SingleActivator a) => [
  if (a.control) 'ctrl',
  if (a.meta) 'meta',
  if (a.alt) 'alt',
  if (a.shift) 'shift',
  a.trigger.keyId.toString(),
].join('+');

/// Reads [encodeActivator]'s output, or `null` if it is not valid.
SingleActivator? decodeActivator(String text) {
  final parts = text.split('+');
  final id = int.tryParse(parts.last);
  final key = id == null ? null : LogicalKeyboardKey.findKeyByKeyId(id);
  if (key == null) return null;
  final mods = parts.sublist(0, parts.length - 1).toSet();
  return SingleActivator(
    key,
    control: mods.contains('ctrl'),
    meta: mods.contains('meta'),
    alt: mods.contains('alt'),
    shift: mods.contains('shift'),
  );
}

/// Human-readable keys, e.g. "Ctrl+Shift+K".
String describeActivator(SingleActivator a) {
  final key = switch (a.trigger) {
    LogicalKeyboardKey.equal => '=',
    LogicalKeyboardKey.minus => '-',
    LogicalKeyboardKey.bracketLeft => '[',
    LogicalKeyboardKey.bracketRight => ']',
    LogicalKeyboardKey.semicolon => ';',
    LogicalKeyboardKey.quote => "'",
    final k => k.keyLabel.length == 1 ? k.keyLabel.toUpperCase() : k.keyLabel,
  };
  return [
    if (a.control) 'Ctrl',
    if (a.meta) '⌘',
    if (a.alt) 'Alt',
    if (a.shift) 'Shift',
    key,
  ].join('+');
}

bool sameActivator(SingleActivator a, SingleActivator b) =>
    a.trigger == b.trigger &&
    a.control == b.control &&
    a.meta == b.meta &&
    a.alt == b.alt &&
    a.shift == b.shift;

/// The user's shortcut changes, saved in settings (`shortcuts`).
final shortcutOverridesProvider = NotifierProvider<
  ShortcutOverridesController,
  Map<ShortcutId, SingleActivator>
>(ShortcutOverridesController.new);

class ShortcutOverridesController
    extends Notifier<Map<ShortcutId, SingleActivator>> {
  static const _settingsKey = 'shortcuts';

  @override
  Map<ShortcutId, SingleActivator> build() {
    final raw = ref.watch(appIndexProvider).settings.get(_settingsKey);
    final map = <ShortcutId, SingleActivator>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, Object?>;
        for (final id in ShortcutId.values) {
          if (json[id.name] case final String text) {
            if (decodeActivator(text) case final a?) map[id] = a;
          }
        }
      } on Object {
        // Damaged setting: fall back to the defaults.
      }
    }
    _overrides = map;
    return map;
  }

  /// The shortcut already using [a], other than [except].
  ShortcutId? conflict(SingleActivator a, {ShortcutId? except}) {
    for (final id in ShortcutId.values) {
      if (id != except && sameActivator(_key(id), a)) return id;
    }
    return null;
  }

  void set(ShortcutId id, SingleActivator a) {
    final next = {...state};
    if (sameActivator(a, defaultShortcuts[id]!)) {
      next.remove(id);
    } else {
      next[id] = a;
    }
    _save(next);
  }

  void resetAll() => _save(const {});

  void _save(Map<ShortcutId, SingleActivator> next) {
    _overrides = next;
    state = next;
    final settings = ref.read(appIndexProvider).settings;
    if (next.isEmpty) {
      settings.remove(_settingsKey);
    } else {
      settings.set(
        _settingsKey,
        jsonEncode({
          for (final MapEntry(:key, :value) in next.entries)
            key.name: encodeActivator(value),
        }),
      );
    }
  }
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
  VoidCallback? onCommandPalette,
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
    if (onCommandPalette != null) EditorKeys.commandPalette: onCommandPalette,
    EditorKeys.frameSelection: editor.frameSelection,
    EditorKeys.bold: () => editor.toggleTextFormat(TextToggle.bold),
    EditorKeys.italic: () => editor.toggleTextFormat(TextToggle.italic),
    EditorKeys.underline: () => editor.toggleTextFormat(TextToggle.underline),
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
