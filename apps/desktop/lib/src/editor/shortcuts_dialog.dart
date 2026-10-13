import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/ocx_theme.dart';
import 'editor_shortcuts.dart';
import 'tools.dart';

/// Keyboard shortcuts (P1.10.4): every shortcut, with the changeable ones
/// rebindable by clicking them and pressing new keys.
Future<void> showShortcutsDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _ShortcutsDialog(),
);

class _ShortcutsDialog extends ConsumerStatefulWidget {
  const _ShortcutsDialog();

  @override
  ConsumerState<_ShortcutsDialog> createState() => _ShortcutsDialogState();
}

class _ShortcutsDialogState extends ConsumerState<_ShortcutsDialog> {
  ShortcutId? _recording;
  String? _message;
  final FocusNode _capture = FocusNode(debugLabel: 'shortcut capture');

  static final _modifiers = {
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  };

  @override
  void dispose() {
    _capture.dispose();
    super.dispose();
  }

  void _record(ShortcutId id) {
    setState(() {
      _recording = id;
      _message = 'Press the new keys for ${id.label} (Esc to cancel)';
    });
    _capture.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final id = _recording;
    if (id == null || event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (_modifiers.contains(key)) return KeyEventResult.handled;
    if (key == LogicalKeyboardKey.escape) {
      setState(() {
        _recording = null;
        _message = null;
      });
      return KeyEventResult.handled;
    }
    final keyboard = HardwareKeyboard.instance;
    final activator = SingleActivator(
      key,
      control: keyboard.isControlPressed,
      meta: keyboard.isMetaPressed,
      alt: keyboard.isAltPressed,
      shift: keyboard.isShiftPressed,
    );
    final hasModifier = activator.control || activator.meta || activator.alt;
    final isFunctionKey =
        key.keyLabel.length > 1 && key.keyLabel.startsWith('F');
    if (!hasModifier && !activator.shift && !isFunctionKey) {
      setState(
        () =>
            _message =
                'Use Ctrl, Alt or Shift with a letter so it does not clash '
                'with typing and tool keys.',
      );
      return KeyEventResult.handled;
    }
    final controller = ref.read(shortcutOverridesProvider.notifier);
    final taken = controller.conflict(activator, except: id);
    if (taken != null) {
      setState(
        () =>
            _message =
                '${describeActivator(activator)} is already used by '
                '${taken.label}.',
      );
      return KeyEventResult.handled;
    }
    controller.set(id, activator);
    setState(() {
      _recording = null;
      _message = '${id.label} is now ${describeActivator(activator)}.';
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final overrides = ref.watch(shortcutOverridesProvider);
    final c = context.ocx;

    Widget keys(String text, {bool active = false, bool changed = false}) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: active ? c.accentSubtle : c.surfaceSunken,
            border: Border.all(color: active ? c.accent : c.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            text,
            style: OcxText.caption(
              context,
            ).copyWith(fontWeight: changed ? FontWeight.w700 : FontWeight.w500),
          ),
        );

    return AlertDialog(
      title: const Text('Keyboard shortcuts'),
      content: Focus(
        focusNode: _capture,
        onKeyEvent: _onKey,
        child: SizedBox(
          width: 480,
          height: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Click a shortcut to change it.',
                style: OcxText.caption(
                  context,
                ).copyWith(color: c.textSecondary, fontWeight: FontWeight.w400),
              ),
              if (_message case final m?)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xs),
                  child: Text(
                    m,
                    style: OcxText.caption(context).copyWith(color: c.accent),
                  ),
                ),
              const SizedBox(height: Space.sm),
              Expanded(
                child: ListView(
                  children: [
                    for (final id in ShortcutId.values)
                      InkWell(
                        onTap: () => _record(id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 5,
                            horizontal: 4,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  id.label,
                                  style: OcxText.body(context),
                                ),
                              ),
                              keys(
                                _recording == id
                                    ? 'Press keys…'
                                    : describeActivator(shortcutFor(id)),
                                active: _recording == id,
                                changed: overrides.containsKey(id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const Divider(height: Space.lg),
                    Text(
                      'Fixed',
                      style: OcxText.caption(
                        context,
                      ).copyWith(color: c.textTertiary),
                    ),
                    for (final (label, text) in [
                      for (final tool in EditorTool.values)
                        if (tool.shortcutLabel case final s?)
                          ('${tool.label} tool', s),
                      ('Delete', 'Del / Backspace'),
                      ('Edit text', 'Enter'),
                      ('Deselect / leave group', 'Esc'),
                      ('Nudge (10× with Shift)', 'Arrow keys'),
                      ('Pan', 'Space + drag'),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 5,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: OcxText.body(
                                  context,
                                ).copyWith(color: c.textSecondary),
                              ),
                            ),
                            keys(text),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (overrides.isNotEmpty)
          TextButton(
            onPressed: () {
              ref.read(shortcutOverridesProvider.notifier).resetAll();
              setState(() => _message = 'All shortcuts reset.');
            },
            child: const Text('Reset all'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
