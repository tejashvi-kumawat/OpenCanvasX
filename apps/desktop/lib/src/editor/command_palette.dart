import 'package:design_engine/design_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/ai_panel.dart';
import '../export/export_dialog.dart';
import '../present/present_page.dart';
import '../providers.dart';
import '../theme/ocx_theme.dart';
import 'editor_controller.dart';
import 'editor_shortcuts.dart';
import 'rulers.dart';
import 'shortcuts_dialog.dart';
import 'side_rail.dart';
import 'tools.dart';
import 'viewport.dart';

/// One entry of the command palette (P1.10.5).
@immutable
class PaletteCommand {
  const PaletteCommand(
    this.label,
    this.run, {
    this.group = 'Edit',
    this.icon,
    this.shortcut,
    this.keywords = '',
    this.enabled = true,
  });

  final String label;
  final String group;
  final IconData? icon;
  final String? shortcut;

  /// Extra words to match, e.g. "remove" for Delete.
  final String keywords;
  final bool enabled;
  final VoidCallback run;
}

/// How well [query] matches [text] as a fuzzy subsequence, or `null` if
/// it does not. Higher is better: consecutive letters, word starts and
/// an early first match score more; shorter texts win ties.
int? fuzzyScore(String query, String text) {
  final q = query.toLowerCase().replaceAll(' ', '');
  if (q.isEmpty) return 0;
  final t = text.toLowerCase();
  var score = 0;
  var ti = 0;
  var previous = -2;
  for (var qi = 0; qi < q.length; qi++) {
    final ch = q[qi];
    var found = -1;
    for (var i = ti; i < t.length; i++) {
      if (t[i] == ch) {
        found = i;
        break;
      }
    }
    if (found < 0) return null;
    final wordStart =
        found == 0 || const [' ', '-', '/', '(', '…'].contains(t[found - 1]);
    score += 1;
    if (found == previous + 1) score += 5;
    if (wordStart) score += 8;
    if (qi == 0) score -= found;
    previous = found;
    ti = found + 1;
  }
  return score * 100 - t.length;
}

/// Commands matching [query], best first ([commands] order breaks ties).
List<PaletteCommand> searchCommands(
  List<PaletteCommand> commands,
  String query,
) {
  if (query.trim().isEmpty) return commands;
  final scored = <(int, int, PaletteCommand)>[];
  for (final (i, c) in commands.indexed) {
    final best = [
      fuzzyScore(query, c.label),
      if (c.keywords.isNotEmpty)
        fuzzyScore(query, c.keywords).let((s) => s == null ? null : s - 50),
      fuzzyScore(
        query,
        '${c.group} ${c.label}',
      ).let((s) => s == null ? null : s - 100),
    ].whereType<int>().fold<int?>(null, (a, b) => a == null || b > a ? b : a);
    if (best != null) scored.add((best, i, c));
  }
  scored.sort((a, b) => a.$1 != b.$1 ? b.$1.compareTo(a.$1) : a.$2 - b.$2);
  return [for (final (_, _, c) in scored) c];
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

String _keys(ShortcutActivator a) =>
    a is SingleActivator ? describeActivator(a) : '';

/// Every command, built for the current editor state.
List<PaletteCommand> editorCommands(BuildContext context, WidgetRef ref) {
  final editor = ref.read(editorProvider.notifier);
  final session = ref.read(editorProvider);
  final view = ref.read(viewportProvider.notifier);
  final tools = ref.read(toolProvider.notifier);
  final aids = ref.read(canvasAidsProvider);
  final aidsCtl = ref.read(canvasAidsProvider.notifier);
  final hasSelection = session?.selection.isNotEmpty ?? false;
  final many = (session?.selection.length ?? 0) > 1;
  void tab(RailTab t) => ref.read(railTabProvider.notifier).tab = t;

  return [
    // Insert
    for (final tool in EditorTool.values)
      PaletteCommand(
        tool == EditorTool.move || tool == EditorTool.hand
            ? '${tool.label} tool'
            : 'Draw ${tool.label.toLowerCase()}',
        () => tools.select(tool),
        group: 'Tools',
        icon: tool.icon,
        shortcut: tool.shortcutLabel,
      ),
    PaletteCommand(
      'Add heading',
      () => editor.insertText(TextRole.heading),
      group: 'Insert',
      icon: Icons.title,
      keywords: 'text title',
    ),
    PaletteCommand(
      'Add body text',
      () => editor.insertText(TextRole.body),
      group: 'Insert',
      icon: Icons.notes,
      keywords: 'paragraph',
    ),
    PaletteCommand(
      'Add page',
      editor.addPage,
      group: 'Pages',
      icon: Icons.note_add_outlined,
      shortcut: _keys(EditorKeys.addPage),
    ),
    PaletteCommand(
      'Duplicate page',
      () {
        if (session != null) editor.duplicatePage(session.state.activePageId);
      },
      group: 'Pages',
      icon: Icons.copy_all_outlined,
    ),
    PaletteCommand(
      'Add free canvas (board)',
      editor.addBoard,
      group: 'Pages',
      icon: Icons.all_inclusive,
      keywords: 'infinite whiteboard',
    ),
    // Edit
    PaletteCommand(
      'Undo',
      editor.undo,
      icon: Icons.undo,
      shortcut: _keys(EditorKeys.undo),
      enabled: session?.canUndo ?? false,
    ),
    PaletteCommand(
      'Redo',
      editor.redo,
      icon: Icons.redo,
      shortcut: _keys(EditorKeys.redo),
      enabled: session?.canRedo ?? false,
    ),
    PaletteCommand(
      'Select all',
      editor.selectAll,
      icon: Icons.select_all,
      shortcut: _keys(EditorKeys.selectAll),
    ),
    PaletteCommand(
      'Duplicate',
      editor.duplicateSelection,
      icon: Icons.control_point_duplicate,
      shortcut: _keys(EditorKeys.duplicate),
      enabled: hasSelection,
    ),
    PaletteCommand(
      'Delete',
      editor.deleteSelection,
      icon: Icons.delete_outline,
      shortcut: 'Del',
      keywords: 'remove',
      enabled: hasSelection,
    ),
    PaletteCommand(
      'Copy',
      editor.copySelection,
      icon: Icons.copy,
      shortcut: _keys(EditorKeys.copy),
      enabled: hasSelection,
    ),
    PaletteCommand(
      'Paste',
      editor.paste,
      icon: Icons.paste,
      shortcut: _keys(EditorKeys.paste),
    ),
    // Arrange
    PaletteCommand(
      'Group',
      editor.groupSelection,
      group: 'Arrange',
      icon: Icons.group_work_outlined,
      shortcut: _keys(EditorKeys.group),
      enabled: many,
    ),
    PaletteCommand(
      'Ungroup',
      editor.ungroupSelection,
      group: 'Arrange',
      icon: Icons.workspaces_outline,
      shortcut: _keys(EditorKeys.ungroup),
      enabled: hasSelection,
    ),
    PaletteCommand(
      'Frame selection',
      editor.frameSelection,
      group: 'Arrange',
      icon: Icons.tag,
      shortcut: _keys(EditorKeys.frameSelection),
      enabled: hasSelection,
    ),
    PaletteCommand(
      'Use as mask',
      editor.useSelectionAsMask,
      group: 'Arrange',
      icon: Icons.vignette_outlined,
      shortcut: _keys(EditorKeys.useAsMask),
      keywords: 'clip',
      enabled: many,
    ),
    PaletteCommand(
      'Create component',
      editor.createComponent,
      group: 'Arrange',
      icon: Icons.widgets_outlined,
      shortcut: _keys(EditorKeys.createComponent),
      keywords: 'symbol reusable',
      enabled: hasSelection,
    ),
    for (final (move, label, icon) in const [
      (ZOrderMove.toFront, 'Bring to front', Icons.flip_to_front),
      (ZOrderMove.forward, 'Bring forward', Icons.arrow_upward),
      (ZOrderMove.backward, 'Send backward', Icons.arrow_downward),
      (ZOrderMove.toBack, 'Send to back', Icons.flip_to_back),
    ])
      PaletteCommand(
        label,
        () => editor.arrange(move),
        group: 'Arrange',
        icon: icon,
        keywords: 'order layer z',
        enabled: hasSelection,
      ),
    for (final (edge, label, icon) in const [
      (AlignEdge.left, 'Align left', Icons.align_horizontal_left),
      (
        AlignEdge.centerHorizontal,
        'Align centre',
        Icons.align_horizontal_center,
      ),
      (AlignEdge.right, 'Align right', Icons.align_horizontal_right),
      (AlignEdge.top, 'Align top', Icons.align_vertical_top),
      (AlignEdge.centerVertical, 'Align middle', Icons.align_vertical_center),
      (AlignEdge.bottom, 'Align bottom', Icons.align_vertical_bottom),
    ])
      PaletteCommand(
        label,
        () => editor.align(edge),
        group: 'Arrange',
        icon: icon,
        keywords: 'center',
        enabled: hasSelection,
      ),
    PaletteCommand(
      'Distribute horizontally',
      () => editor.distribute(DistributeAxis.horizontal),
      group: 'Arrange',
      icon: Icons.horizontal_distribute,
      keywords: 'space evenly',
      enabled: (session?.selection.length ?? 0) > 2,
    ),
    PaletteCommand(
      'Distribute vertically',
      () => editor.distribute(DistributeAxis.vertical),
      group: 'Arrange',
      icon: Icons.vertical_distribute,
      keywords: 'space evenly',
      enabled: (session?.selection.length ?? 0) > 2,
    ),
    PaletteCommand(
      'Flip horizontal',
      () => editor.updateSelected(
        (o) =>
            o.copyWith(transform: flipTransform(o.transform, horizontal: true)),
        label: 'Flip',
      ),
      group: 'Arrange',
      icon: Icons.flip,
      keywords: 'mirror',
      enabled: hasSelection,
    ),
    PaletteCommand(
      'Flip vertical',
      () => editor.updateSelected(
        (o) => o.copyWith(
          transform: flipTransform(o.transform, horizontal: false),
        ),
        label: 'Flip',
      ),
      group: 'Arrange',
      icon: Icons.flip,
      keywords: 'mirror',
      enabled: hasSelection,
    ),
    // View
    PaletteCommand(
      'Zoom in',
      view.zoomIn,
      group: 'View',
      icon: Icons.zoom_in,
      shortcut: _keys(EditorKeys.zoomIn),
    ),
    PaletteCommand(
      'Zoom out',
      view.zoomOut,
      group: 'View',
      icon: Icons.zoom_out,
      shortcut: _keys(EditorKeys.zoomOut),
    ),
    PaletteCommand(
      'Zoom to fit page',
      () => fitActivePage(ref),
      group: 'View',
      icon: Icons.fit_screen_outlined,
      shortcut: _keys(EditorKeys.fit),
    ),
    PaletteCommand(
      'Actual size (100%)',
      () => view.setZoom(1),
      group: 'View',
      icon: Icons.crop_free,
      shortcut: _keys(EditorKeys.actualSize),
    ),
    PaletteCommand(
      aids.rulers ? 'Hide rulers' : 'Show rulers',
      aidsCtl.toggleRulers,
      group: 'View',
      icon: Icons.straighten,
      shortcut: _keys(EditorKeys.rulers),
    ),
    PaletteCommand(
      aids.guides ? 'Hide guides' : 'Show guides',
      aidsCtl.toggleGuides,
      group: 'View',
      icon: Icons.border_inner,
      shortcut: _keys(EditorKeys.guides),
    ),
    PaletteCommand(
      aids.grid ? 'Hide grid' : 'Show grid',
      aidsCtl.toggleGrid,
      group: 'View',
      icon: Icons.grid_4x4,
      shortcut: _keys(EditorKeys.grid),
    ),
    for (final (mode, label) in const [
      (ThemeMode.light, 'Light theme'),
      (ThemeMode.dark, 'Dark theme'),
      (ThemeMode.system, 'Theme: match system'),
    ])
      PaletteCommand(
        label,
        () => ref.read(themeModeProvider.notifier).set(mode),
        group: 'View',
        icon: Icons.contrast,
        keywords: 'appearance',
      ),
    // Panels
    for (final t in RailTab.values)
      PaletteCommand(
        'Open ${t.label}',
        () => tab(t),
        group: 'Panels',
        icon: t.icon,
        keywords: 'panel sidebar',
      ),
    // File
    PaletteCommand(
      'Save',
      editor.saveNow,
      group: 'File',
      icon: Icons.save_outlined,
      shortcut: _keys(EditorKeys.save),
    ),
    PaletteCommand(
      'Save version…',
      () => tab(RailTab.history),
      group: 'File',
      icon: Icons.bookmark_add_outlined,
      keywords: 'snapshot checkpoint history',
    ),
    PaletteCommand(
      'Export…',
      () => showExportDialog(context),
      group: 'File',
      icon: Icons.ios_share,
      shortcut: _keys(EditorKeys.export),
      keywords: 'download png jpg pdf svg website html',
    ),
    PaletteCommand(
      'Present',
      () => presentDesign(context),
      group: 'File',
      icon: Icons.slideshow,
      shortcut: 'F5',
      keywords: 'prototype play slideshow',
    ),
    PaletteCommand(
      'Keyboard shortcuts…',
      () => showShortcutsDialog(context),
      group: 'File',
      icon: Icons.keyboard_outlined,
      keywords: 'keys hotkeys customize',
    ),
    PaletteCommand(
      'AI settings…',
      () => showAiSettings(context),
      group: 'File',
      icon: Icons.auto_awesome_outlined,
      keywords: 'provider model key',
    ),
  ];
}

/// Opens the command palette (Ctrl+K).
Future<void> showCommandPalette(BuildContext context, WidgetRef ref) async {
  final commands = editorCommands(context, ref);
  final chosen = await showDialog<PaletteCommand>(
    context: context,
    barrierColor: Colors.black26,
    builder: (_) => _CommandPalette(commands: commands),
  );
  chosen?.run();
}

class _CommandPalette extends StatefulWidget {
  const _CommandPalette({required this.commands});

  final List<PaletteCommand> commands;

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final TextEditingController _query = TextEditingController();
  final ScrollController _scroll = ScrollController();
  int _index = 0;

  static const _rowHeight = 36.0;

  List<PaletteCommand> get _results =>
      searchCommands(widget.commands, _query.text);

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _move(int delta) {
    final results = _results;
    if (results.isEmpty) return;
    setState(() => _index = (_index + delta) % results.length);
    final offset = _index * _rowHeight;
    if (!_scroll.hasClients) return;
    final view = _scroll.position.viewportDimension;
    if (offset < _scroll.offset) {
      _scroll.jumpTo(offset);
    } else if (offset + _rowHeight > _scroll.offset + view) {
      _scroll.jumpTo(offset + _rowHeight - view);
    }
  }

  void _run(PaletteCommand command) {
    if (!command.enabled) return;
    Navigator.pop(context, command);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final results = _results;
    final index = results.isEmpty ? 0 : _index.clamp(0, results.length - 1);
    return Align(
      alignment: const Alignment(0, -0.6),
      child: Material(
        color: c.surface,
        elevation: 12,
        borderRadius: BorderRadius.circular(Radii.lg),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.arrowDown):
                      () => _move(1),
                  const SingleActivator(LogicalKeyboardKey.arrowUp):
                      () => _move(-1),
                  const SingleActivator(LogicalKeyboardKey.enter): () {
                    if (results.isNotEmpty) _run(results[index]);
                  },
                },
                child: TextField(
                  controller: _query,
                  autofocus: true,
                  style: OcxText.body(context).copyWith(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Type a command…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: Space.md,
                    ),
                    suffixText: 'Esc to close',
                    suffixStyle: OcxText.caption(
                      context,
                    ).copyWith(color: c.textTertiary),
                  ),
                  onChanged: (_) => setState(() => _index = 0),
                ),
              ),
              const Divider(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child:
                    results.isEmpty
                        ? Padding(
                          padding: const EdgeInsets.all(Space.lg),
                          child: Text(
                            'No matching commands',
                            style: OcxText.body(
                              context,
                            ).copyWith(color: c.textTertiary),
                          ),
                        )
                        : ListView.builder(
                          controller: _scroll,
                          shrinkWrap: true,
                          itemExtent: _rowHeight,
                          padding: const EdgeInsets.symmetric(
                            vertical: Space.xs,
                          ),
                          itemCount: results.length,
                          itemBuilder: (context, i) {
                            final command = results[i];
                            final selected = i == index;
                            final color =
                                command.enabled ? null : c.textTertiary;
                            return InkWell(
                              onTap: () => _run(command),
                              onHover: (h) {
                                if (h) setState(() => _index = i);
                              },
                              child: Container(
                                color: selected ? c.accentSubtle : null,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Space.md,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      command.icon ?? Icons.bolt,
                                      size: 16,
                                      color: color ?? c.textSecondary,
                                    ),
                                    const SizedBox(width: Space.md),
                                    Expanded(
                                      child: Text(
                                        command.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: OcxText.body(
                                          context,
                                        ).copyWith(color: color),
                                      ),
                                    ),
                                    Text(
                                      command.group,
                                      style: OcxText.caption(
                                        context,
                                      ).copyWith(color: c.textTertiary),
                                    ),
                                    if (command.shortcut case final s?
                                        when s.isNotEmpty) ...[
                                      const SizedBox(width: Space.sm),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: c.surfaceSunken,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          s,
                                          style: OcxText.caption(context),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
