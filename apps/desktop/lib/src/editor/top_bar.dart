import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/ocx_theme.dart';
import '../widgets/brand_mark.dart';
import '../export/export_dialog.dart';
import '../present/present_page.dart';
import '../widgets/controls.dart';
import 'editor_controller.dart';
import 'editor_shortcuts.dart';
import 'viewport.dart';

/// Editor toolbar (design-system.md §5): menu and tools on the left, title
/// and save state in the centre, history and zoom on the right.
class EditorToolbar extends ConsumerWidget {
  const EditorToolbar({required this.onHome, super.key});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(editorProvider);
    if (session == null) return const SizedBox(height: Chrome.toolbar);
    final editor = ref.read(editorProvider.notifier);
    final c = context.ocx;
    return Container(
      height: Chrome.toolbar,
      color: c.surface,
      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
      child: Row(
        children: [
          OcxIconButton(
            icon: Icons.home_outlined,
            tooltip: 'Home',
            onPressed: onHome,
            iconSize: Chrome.toolbarIcon,
          ),
          const SizedBox(width: Space.xs),
          _MainMenu(onHome: onHome),
          Expanded(
            child: Center(
              child: _TitleAndStatus(
                title: session.document.metadata.title,
                status: session.saveStatus,
                onRename: editor.rename,
              ),
            ),
          ),
          OcxIconButton(
            icon: Icons.undo,
            iconSize: Chrome.toolbarIcon,
            tooltip:
                session.canUndo
                    ? 'Undo ${session.undoLabel!.toLowerCase()}  (Ctrl+Z)'
                    : 'Nothing to undo',
            onPressed: session.canUndo ? editor.undo : null,
          ),
          OcxIconButton(
            icon: Icons.redo,
            iconSize: Chrome.toolbarIcon,
            tooltip:
                session.canRedo
                    ? 'Redo ${session.redoLabel!.toLowerCase()}  (Ctrl+Shift+Z)'
                    : 'Nothing to redo',
            onPressed: session.canRedo ? editor.redo : null,
          ),
          const _ToolbarDivider(),
          const _ZoomMenu(),
          const SizedBox(width: Space.xs),
          const _ThemeToggle(),
          const SizedBox(width: Space.sm),
          Tooltip(
            message: 'Present  (F5)',
            child: OutlinedButton.icon(
              onPressed: () => presentDesign(context),
              icon: const Icon(Icons.play_arrow_outlined, size: Chrome.icon),
              label: const Text('Present'),
            ),
          ),
          const SizedBox(width: Space.sm),
          Tooltip(
            message: 'Export  (Ctrl+Shift+E)',
            child: FilledButton.icon(
              onPressed: () => showExportDialog(context),
              icon: const Icon(Icons.ios_share, size: Chrome.icon),
              label: const Text('Export'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 20,
    margin: const EdgeInsets.symmetric(horizontal: Space.sm),
    color: context.ocx.border,
  );
}

class _TitleAndStatus extends StatefulWidget {
  const _TitleAndStatus({
    required this.title,
    required this.status,
    required this.onRename,
  });

  final String title;
  final SaveStatus status;
  final ValueChanged<String> onRename;

  @override
  State<_TitleAndStatus> createState() => _TitleAndStatusState();
}

class _TitleAndStatusState extends State<_TitleAndStatus> {
  bool _editing = false;
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
    widget.onRename(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final (icon, text, color) = switch (widget.status) {
      SaveStatus.saved => (Icons.check, 'Saved', c.textTertiary),
      SaveStatus.pending ||
      SaveStatus.saving => (Icons.sync, 'Saving…', c.textTertiary),
      SaveStatus.failed => (Icons.error_outline, 'Not saved', c.danger),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child:
              _editing
                  ? SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: OcxText.bodyStrong(context),
                      onSubmitted: (_) => _finish(),
                      onTapOutside: (_) => _finish(),
                    ),
                  )
                  : Tooltip(
                    message: 'Rename design',
                    child: InkWell(
                      onTap: _start,
                      borderRadius: BorderRadius.circular(Radii.xs),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.sm,
                          vertical: Space.xs,
                        ),
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OcxText.bodyStrong(context),
                        ),
                      ),
                    ),
                  ),
        ),
        Tooltip(
          message:
              widget.status == SaveStatus.failed
                  ? 'The last save failed; OpenCanvasX keeps your changes and retries.'
                  : 'Changes are saved automatically to this computer.',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: Space.xs),
              Text(
                text,
                style: OcxText.caption(context).copyWith(color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- right side

class _ZoomMenu extends ConsumerWidget {
  const _ZoomMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoom = ref.watch(viewportProvider.select((v) => v.zoom));
    final view = ref.read(viewportProvider.notifier);
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          onPressed: view.zoomIn,
          shortcut: EditorKeys.zoomIn,
          child: const Text('Zoom in'),
        ),
        MenuItemButton(
          onPressed: view.zoomOut,
          shortcut: EditorKeys.zoomOut,
          child: const Text('Zoom out'),
        ),
        MenuItemButton(
          onPressed: () => fitActivePage(ref),
          shortcut: EditorKeys.fit,
          child: const Text('Zoom to fit page'),
        ),
        const Divider(),
        for (final level in const [0.5, 1.0, 2.0])
          MenuItemButton(
            onPressed: () => view.setZoom(level),
            shortcut: level == 1 ? EditorKeys.actualSize : null,
            child: Text('${(level * 100).round()}%'),
          ),
      ],
      builder:
          (context, controller, _) => Tooltip(
            message: 'Zoom',
            child: InkWell(
              onTap:
                  () =>
                      controller.isOpen
                          ? controller.close()
                          : controller.open(),
              borderRadius: BorderRadius.circular(Radii.xs),
              child: SizedBox(
                height: Chrome.control,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                  child: Row(
                    children: [
                      Text(
                        '${(zoom * 100).round()}%',
                        style: OcxText.body(context),
                      ),
                      Icon(
                        Icons.expand_more,
                        size: 14,
                        color: context.ocx.textSecondary,
                      ),
                    ],
                  ),
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
    return OcxIconButton(
      icon: dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      tooltip: dark ? 'Light theme' : 'Dark theme',
      onPressed:
          () => ref
              .read(themeModeProvider.notifier)
              .set(dark ? ThemeMode.light : ThemeMode.dark),
    );
  }
}

// --------------------------------------------------------------- main menu

class _MainMenu extends ConsumerWidget {
  const _MainMenu({required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(editorProvider)!;
    final editor = ref.read(editorProvider.notifier);
    final view = ref.read(viewportProvider.notifier);
    final sel = session.selection;
    final hasSelection = sel.isNotEmpty;
    final themeMode = ref.watch(themeModeProvider);

    MenuItemButton item(
      String label,
      VoidCallback? onPressed, {
      MenuSerializableShortcut? shortcut,
    }) => MenuItemButton(
      onPressed: onPressed,
      shortcut: shortcut,
      child: Text(label),
    );

    return MenuAnchor(
      menuChildren: [
        SubmenuButton(
          menuChildren: [
            item('Save', editor.saveNow, shortcut: EditorKeys.save),
            item(
              'Export…',
              () => showExportDialog(context),
              shortcut: EditorKeys.export,
            ),
            const Divider(),
            item('Close design', onHome),
          ],
          child: const Text('File'),
        ),
        SubmenuButton(
          menuChildren: [
            item(
              session.canUndo
                  ? 'Undo ${session.undoLabel!.toLowerCase()}'
                  : 'Undo',
              session.canUndo ? editor.undo : null,
              shortcut: EditorKeys.undo,
            ),
            item(
              session.canRedo
                  ? 'Redo ${session.redoLabel!.toLowerCase()}'
                  : 'Redo',
              session.canRedo ? editor.redo : null,
              shortcut: EditorKeys.redo,
            ),
            const Divider(),
            item(
              'Cut',
              hasSelection ? editor.cutSelection : null,
              shortcut: EditorKeys.cut,
            ),
            item(
              'Copy',
              hasSelection ? editor.copySelection : null,
              shortcut: EditorKeys.copy,
            ),
            item(
              'Paste',
              ref.watch(clipboardProvider).isEmpty ? null : editor.paste,
              shortcut: EditorKeys.paste,
            ),
            item(
              'Duplicate',
              hasSelection ? editor.duplicateSelection : null,
              shortcut: EditorKeys.duplicate,
            ),
            item(
              'Delete',
              hasSelection ? editor.deleteSelection : null,
              shortcut: EditorKeys.delete,
            ),
            const Divider(),
            item(
              'Select all',
              editor.selectAll,
              shortcut: EditorKeys.selectAll,
            ),
          ],
          child: const Text('Edit'),
        ),
        SubmenuButton(
          menuChildren: [
            item('Zoom in', view.zoomIn, shortcut: EditorKeys.zoomIn),
            item('Zoom out', view.zoomOut, shortcut: EditorKeys.zoomOut),
            item(
              'Zoom to fit page',
              () => fitActivePage(ref),
              shortcut: EditorKeys.fit,
            ),
            item(
              'Actual size',
              () => view.setZoom(1),
              shortcut: EditorKeys.actualSize,
            ),
            const Divider(),
            SubmenuButton(
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
          menuChildren: [
            for (final role in TextRole.values)
              item(role.label, () => editor.insertText(role)),
            const Divider(),
            for (final type in insertableShapes)
              item(typeLabel(type), () => editor.insertShape(type)),
            const Divider(),
            item('Page', editor.addPage, shortcut: EditorKeys.addPage),
          ],
          child: const Text('Insert'),
        ),
        SubmenuButton(
          menuChildren: [
            item(
              'Group',
              editor.canGroup ? editor.groupSelection : null,
              shortcut: EditorKeys.group,
            ),
            item(
              'Ungroup',
              editor.canUngroup ? editor.ungroupSelection : null,
              shortcut: EditorKeys.ungroup,
            ),
            item(
              'Frame selection',
              hasSelection ? editor.frameSelection : null,
              shortcut: EditorKeys.frameSelection,
            ),
            const Divider(),
            item(
              'Bring to front',
              hasSelection ? () => editor.arrange(ZOrderMove.toFront) : null,
              shortcut: EditorKeys.bringToFront,
            ),
            item(
              'Bring forward',
              hasSelection ? () => editor.arrange(ZOrderMove.forward) : null,
              shortcut: EditorKeys.bringForward,
            ),
            item(
              'Send backward',
              hasSelection ? () => editor.arrange(ZOrderMove.backward) : null,
              shortcut: EditorKeys.sendBackward,
            ),
            item(
              'Send to back',
              hasSelection ? () => editor.arrange(ZOrderMove.toBack) : null,
              shortcut: EditorKeys.sendToBack,
            ),
            const Divider(),
            for (final (edge, label) in const [
              (AlignEdge.left, 'Align left'),
              (AlignEdge.centerHorizontal, 'Align centre'),
              (AlignEdge.right, 'Align right'),
              (AlignEdge.top, 'Align top'),
              (AlignEdge.centerVertical, 'Align middle'),
              (AlignEdge.bottom, 'Align bottom'),
            ])
              item(label, hasSelection ? () => editor.align(edge) : null),
            const Divider(),
            item(
              'Distribute horizontally',
              sel.length >= 3
                  ? () => editor.distribute(DistributeAxis.horizontal)
                  : null,
            ),
            item(
              'Distribute vertically',
              sel.length >= 3
                  ? () => editor.distribute(DistributeAxis.vertical)
                  : null,
            ),
          ],
          child: const Text('Arrange'),
        ),
      ],
      builder:
          (context, controller, _) => Tooltip(
            message: 'Menu',
            child: InkWell(
              onTap:
                  () =>
                      controller.isOpen
                          ? controller.close()
                          : controller.open(),
              borderRadius: BorderRadius.circular(Radii.xs),
              child: SizedBox(
                height: Chrome.control,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                  child: Row(
                    children: [
                      const BrandMark(size: 20),
                      Icon(
                        Icons.expand_more,
                        size: 14,
                        color: context.ocx.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }
}

/// Shapes offered in the Insert menu and Elements panel, in order.
const insertableShapes = [
  ObjectType.rect,
  ObjectType.roundedRect,
  ObjectType.ellipse,
  ObjectType.polygon,
  ObjectType.star,
  ObjectType.line,
  ObjectType.arrow,
];
