import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/ocx_theme.dart';
import 'editor_controller.dart';
import 'editor_shortcuts.dart';
import 'viewport.dart';

/// Editor top bar (ux-spec.md "Top"): home, menus, history, save state,
/// document title.
class EditorTopBar extends ConsumerWidget {
  const EditorTopBar({required this.onHome, super.key});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(editorProvider);
    if (session == null) return const SizedBox(height: Chrome.topBarHeight);
    final editor = ref.read(editorProvider.notifier);
    final page = session.activePage;
    return Container(
      height: Chrome.topBarHeight,
      decoration: const BoxDecoration(gradient: Brand.gradient),
      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Narrow windows keep the essentials: menus, history, title.
          final compact = constraints.maxWidth < 1100;
          return Row(
            children: [
              _BarIconButton(
                icon: Icons.home_outlined,
                tooltip: 'Back to home',
                onPressed: onHome,
              ),
              const SizedBox(width: Space.xs),
              _EditorMenuBar(onHome: onHome),
              const _BarDivider(),
              _BarIconButton(
                icon: Icons.undo,
                tooltip:
                    session.canUndo
                        ? 'Undo ${session.undoLabel!.toLowerCase()}'
                        : 'Nothing to undo',
                onPressed: session.canUndo ? editor.undo : null,
              ),
              _BarIconButton(
                icon: Icons.redo,
                tooltip:
                    session.canRedo
                        ? 'Redo ${session.redoLabel!.toLowerCase()}'
                        : 'Nothing to redo',
                onPressed: session.canRedo ? editor.redo : null,
              ),
              const SizedBox(width: Space.sm),
              _SaveStatus(status: session.saveStatus, compact: compact),
              Expanded(
                child: Center(
                  child: _TitleField(
                    title: session.document.metadata.title,
                    onSubmitted: editor.rename,
                  ),
                ),
              ),
              if (!compact) ...[
                Text(
                  '${_fmt(page.width)} × ${_fmt(page.height)} ${page.unit.symbol}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(width: Space.md),
              ],
              const _ThemeToggle(),
              const SizedBox(width: Space.xs),
            ],
          );
        },
      ),
    );
  }
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

class _BarIconButton extends StatelessWidget {
  const _BarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 21),
    tooltip: tooltip,
    onPressed: onPressed,
    color: Colors.white,
    disabledColor: Colors.white.withValues(alpha: 0.4),
    hoverColor: Colors.white.withValues(alpha: 0.12),
  );
}

class _BarDivider extends StatelessWidget {
  const _BarDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 24,
    margin: const EdgeInsets.symmetric(horizontal: Space.sm),
    color: Colors.white.withValues(alpha: 0.25),
  );
}

class _SaveStatus extends StatelessWidget {
  const _SaveStatus({required this.status, this.compact = false});

  final SaveStatus status;

  /// Icon only; the text moves into the tooltip.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (status) {
      SaveStatus.saved => (Icons.check_circle_outline, 'All changes saved'),
      SaveStatus.pending || SaveStatus.saving => (null, 'Saving…'),
      SaveStatus.failed => (Icons.error_outline, 'Not saved — will retry'),
    };
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Colors.white.withValues(alpha: 0.85),
    );
    return Tooltip(
      message:
          compact
              ? '$text — designs are saved automatically to this computer.'
              : 'Designs are saved automatically to this computer.',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.85))
          else
            const SizedBox.square(
              dimension: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: Colors.white,
              ),
            ),
          if (!compact) ...[const SizedBox(width: 6), Text(text, style: style)],
        ],
      ),
    );
  }
}

/// Document title that turns into a text field on click.
class _TitleField extends StatefulWidget {
  const _TitleField({required this.title, required this.onSubmitted});

  final String title;
  final ValueChanged<String> onSubmitted;

  @override
  State<_TitleField> createState() => _TitleFieldState();
}

class _TitleFieldState extends State<_TitleField> {
  bool _editing = false;
  bool _hover = false;
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    _controller
      ..text = widget.title
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.title.length,
      );
    setState(() => _editing = true);
  }

  void _finish() {
    if (!_editing) return;
    setState(() => _editing = false);
    widget.onSubmitted(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(color: Colors.white);
    if (_editing) {
      return SizedBox(
        width: 320,
        child: TextField(
          controller: _controller,
          autofocus: true,
          textAlign: TextAlign.center,
          style: style,
          cursorColor: Colors.white,
          onSubmitted: (_) => _finish(),
          onTapOutside: (_) => _finish(),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.16),
            enabledBorder: InputBorder.none,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.sm),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      );
    }
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _start,
        child: Tooltip(
          message: 'Rename design',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color:
                  _hover
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _BarIconButton(
      icon: dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      tooltip: dark ? 'Switch to light theme' : 'Switch to dark theme',
      onPressed:
          () => ref
              .read(themeModeProvider.notifier)
              .set(dark ? ThemeMode.light : ThemeMode.dark),
    );
  }
}

class _EditorMenuBar extends ConsumerWidget {
  const _EditorMenuBar({required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(editorProvider)!;
    final editor = ref.read(editorProvider.notifier);
    final view = ref.read(viewportProvider.notifier);
    final hasSelection = session.selection.isNotEmpty;
    final themeMode = ref.watch(themeModeProvider);

    Widget item(
      String label,
      VoidCallback? onPressed, {
      MenuSerializableShortcut? shortcut,
      IconData? icon,
    }) => MenuItemButton(
      onPressed: onPressed,
      shortcut: shortcut,
      leadingIcon:
          icon == null ? const SizedBox(width: 18) : Icon(icon, size: 18),
      child: Text(label),
    );

    final topStyle = ButtonStyle(
      // The theme gives menu items a wide minimum; top-level titles hug text.
      minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      foregroundColor: const WidgetStatePropertyAll(Colors.white),
      overlayColor: WidgetStatePropertyAll(
        Colors.white.withValues(alpha: 0.14),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: Space.md),
      ),
      textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.labelLarge),
    );

    return MenuBar(
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        shadowColor: WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      children: [
        SubmenuButton(
          style: topStyle,
          menuChildren: [
            item(
              'Save',
              editor.saveNow,
              shortcut: EditorKeys.save,
              icon: Icons.save_outlined,
            ),
            const Divider(),
            item('Close design', onHome, icon: Icons.close),
          ],
          child: const Text('File'),
        ),
        SubmenuButton(
          style: topStyle,
          menuChildren: [
            item(
              session.canUndo
                  ? 'Undo ${session.undoLabel!.toLowerCase()}'
                  : 'Undo',
              session.canUndo ? editor.undo : null,
              shortcut: EditorKeys.undo,
              icon: Icons.undo,
            ),
            item(
              session.canRedo
                  ? 'Redo ${session.redoLabel!.toLowerCase()}'
                  : 'Redo',
              session.canRedo ? editor.redo : null,
              shortcut: EditorKeys.redo,
              icon: Icons.redo,
            ),
            const Divider(),
            item(
              'Cut',
              hasSelection ? editor.cutSelection : null,
              shortcut: EditorKeys.cut,
              icon: Icons.content_cut,
            ),
            item(
              'Copy',
              hasSelection ? editor.copySelection : null,
              shortcut: EditorKeys.copy,
              icon: Icons.content_copy,
            ),
            item(
              'Paste',
              ref.watch(clipboardProvider).isEmpty ? null : editor.paste,
              shortcut: EditorKeys.paste,
              icon: Icons.content_paste,
            ),
            item(
              'Duplicate',
              hasSelection ? editor.duplicateSelection : null,
              shortcut: EditorKeys.duplicate,
              icon: Icons.copy_all_outlined,
            ),
            item(
              'Delete',
              hasSelection ? editor.deleteSelection : null,
              shortcut: EditorKeys.delete,
              icon: Icons.delete_outline,
            ),
            const Divider(),
            item(
              'Select all',
              editor.selectAll,
              shortcut: EditorKeys.selectAll,
              icon: Icons.select_all,
            ),
          ],
          child: const Text('Edit'),
        ),
        SubmenuButton(
          style: topStyle,
          menuChildren: [
            item(
              'Zoom in',
              view.zoomIn,
              shortcut: EditorKeys.zoomIn,
              icon: Icons.zoom_in,
            ),
            item(
              'Zoom out',
              view.zoomOut,
              shortcut: EditorKeys.zoomOut,
              icon: Icons.zoom_out,
            ),
            item(
              'Fit page',
              () => fitActivePage(ref),
              shortcut: EditorKeys.fit,
              icon: Icons.fit_screen_outlined,
            ),
            item(
              'Actual size',
              () => view.setZoom(1),
              shortcut: EditorKeys.actualSize,
              icon: Icons.crop_free,
            ),
            const Divider(),
            SubmenuButton(
              leadingIcon: const Icon(Icons.contrast, size: 18),
              menuChildren: [
                for (final (mode, label) in const [
                  (ThemeMode.system, 'Match system'),
                  (ThemeMode.light, 'Light'),
                  (ThemeMode.dark, 'Dark'),
                ])
                  MenuItemButton(
                    onPressed:
                        () => ref.read(themeModeProvider.notifier).set(mode),
                    leadingIcon: Icon(
                      Icons.check,
                      size: 18,
                      color: mode == themeMode ? null : Colors.transparent,
                    ),
                    child: Text(label),
                  ),
              ],
              child: const Text('Theme'),
            ),
          ],
          child: const Text('View'),
        ),
        SubmenuButton(
          style: topStyle,
          menuChildren: [
            for (final type in insertableShapes)
              item(
                typeLabel(type),
                () => editor.insertShape(type),
                icon: _insertIcon(type),
              ),
            const Divider(),
            item(
              'Page',
              editor.addPage,
              shortcut: EditorKeys.addPage,
              icon: Icons.note_add_outlined,
            ),
          ],
          child: const Text('Insert'),
        ),
        SubmenuButton(
          style: topStyle,
          menuChildren: [
            item(
              'Bring to front',
              hasSelection ? () => editor.arrange(ZOrderMove.toFront) : null,
              shortcut: EditorKeys.bringToFront,
              icon: Icons.vertical_align_top,
            ),
            item(
              'Bring forward',
              hasSelection ? () => editor.arrange(ZOrderMove.forward) : null,
              shortcut: EditorKeys.bringForward,
              icon: Icons.arrow_upward,
            ),
            item(
              'Send backward',
              hasSelection ? () => editor.arrange(ZOrderMove.backward) : null,
              shortcut: EditorKeys.sendBackward,
              icon: Icons.arrow_downward,
            ),
            item(
              'Send to back',
              hasSelection ? () => editor.arrange(ZOrderMove.toBack) : null,
              shortcut: EditorKeys.sendToBack,
              icon: Icons.vertical_align_bottom,
            ),
            const Divider(),
            SubmenuButton(
              leadingIcon: const Icon(Icons.align_horizontal_center, size: 18),
              menuChildren: [
                for (final (edge, label) in const [
                  (AlignEdge.left, 'Left'),
                  (AlignEdge.centerHorizontal, 'Centre'),
                  (AlignEdge.right, 'Right'),
                  (AlignEdge.top, 'Top'),
                  (AlignEdge.centerVertical, 'Middle'),
                  (AlignEdge.bottom, 'Bottom'),
                ])
                  MenuItemButton(
                    onPressed: hasSelection ? () => editor.align(edge) : null,
                    child: Text(label),
                  ),
              ],
              child: const Text('Align'),
            ),
          ],
          child: const Text('Arrange'),
        ),
      ],
    );
  }
}

IconData _insertIcon(ObjectType type) => switch (type) {
  ObjectType.rect => Icons.crop_square,
  ObjectType.roundedRect => Icons.rounded_corner,
  ObjectType.ellipse => Icons.circle_outlined,
  ObjectType.line => Icons.horizontal_rule,
  ObjectType.arrow => Icons.arrow_right_alt,
  ObjectType.text => Icons.title,
  ObjectType.image => Icons.image_outlined,
  ObjectType.path => Icons.gesture,
  ObjectType.group => Icons.folder_copy_outlined,
};
