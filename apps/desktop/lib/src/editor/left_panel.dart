import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/ocx_theme.dart';
import '../widgets/controls.dart';
import '../widgets/object_icons.dart';
import 'editor_controller.dart';

// ------------------------------------------------------------------ layers

/// Layers (P1.4.1): the active page's layer tree — groups and frames
/// expand, rows rename, hide, lock and reorder.
class LayersPanel extends ConsumerStatefulWidget {
  const LayersPanel({super.key});

  @override
  ConsumerState<LayersPanel> createState() => _LayersPanelState();
}

class _LayersPanelState extends ConsumerState<LayersPanel> {
  /// Groups opened in the tree; groups holding the selection open too.
  final Set<ObjectId> _expanded = {};

  /// Visible tree rows, topmost first, with their nesting depth.
  List<_TreeRow> _rows(EditorSession session) {
    final document = session.document;
    final open = {
      ..._expanded,
      for (final id in session.selection)
        for (final ancestor in ancestorPath(document, id))
          if (ancestor != id) ancestor,
    };
    final rows = <_TreeRow>[];
    void visit(List<ObjectId> ids, int depth) {
      for (final id in ids.reversed) {
        final object = document.objects[id];
        if (object == null) continue;
        rows.add((object: object, depth: depth));
        if (object.type.isContainer && open.contains(id)) {
          visit(object.childIds, depth + 1);
        }
      }
    }

    visit(session.activePage.objectIds, 0);
    return rows;
  }

  /// Reorders a top-level layer dropped at [to] in the visible rows.
  void _moveRoot(List<_TreeRow> rows, int from, int to) {
    final moved = rows[from].object.id;
    final rest = [...rows]..removeAt(from);
    var slot = 0;
    for (final row in rest.take(to)) {
      if (row.depth == 0) slot++;
    }
    final topFirst = [
      for (final row in rest)
        if (row.depth == 0) row.object.id,
    ]..insert(slot, moved);
    ref.read(editorProvider.notifier).setLayerOrder(topFirst.reversed.toList());
  }

  void _toggle(EditorSession session, ObjectId group, {required bool open}) {
    setState(() {
      if (!open) {
        _expanded.add(group);
        return;
      }
      _expanded.remove(group);
      // Collapsing a group that holds the selection selects the group.
      final inside = session.selection.any(
        (id) =>
            id != group && ancestorPath(session.document, id).contains(group),
      );
      if (inside) ref.read(editorProvider.notifier).select({group});
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(editorProvider);
    if (session == null) return const SizedBox.shrink();
    final page = session.activePage;
    final rows = _rows(session);
    final c = context.ocx;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelSection(
          title:
              page.name.isEmpty
                  ? 'Page ${session.state.activePageIndex + 1}'
                  : page.name,
          divider: false,
          trailing: [
            Padding(
              padding: const EdgeInsets.only(right: Space.xs),
              child: Text(
                '${page.objectIds.length}',
                style: OcxText.caption(context).copyWith(color: c.textTertiary),
              ),
            ),
          ],
        ),
        Expanded(
          child:
              rows.isEmpty
                  ? Padding(
                    padding: const EdgeInsets.all(Space.md),
                    child: Text(
                      'No layers on this page yet. Pick a tool in the toolbar '
                      'or add something from Elements.',
                      style: OcxText.caption(context).copyWith(
                        color: c.textTertiary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  )
                  : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.fromLTRB(
                      Space.sm,
                      0,
                      Space.sm,
                      Space.md,
                    ),
                    itemCount: rows.length,
                    onReorderItem: (from, to) {
                      if (rows[from].depth == 0) _moveRoot(rows, from, to);
                    },
                    itemBuilder: (context, index) {
                      final (:object, :depth) = rows[index];
                      final open =
                          index + 1 < rows.length &&
                          rows[index + 1].depth > depth;
                      final isGroup = object.type.isContainer;
                      return _LayerRow(
                        key: ValueKey(object.id),
                        index: index,
                        depth: depth,
                        object: object,
                        name: layerName(session.document, page, object),
                        selected: session.selection.contains(object.id),
                        expanded: isGroup ? open : null,
                        onToggle:
                            isGroup
                                ? () => _toggle(session, object.id, open: open)
                                : null,
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

/// A visible layer row and how deeply it is nested.
typedef _TreeRow = ({DesignObject object, int depth});

/// Shared look of a 28 px list row (pages, layers).
class _RowShell extends StatefulWidget {
  const _RowShell({
    required this.selected,
    required this.onTap,
    required this.builder,
    this.dragIndex,
  });

  final bool selected;
  final VoidCallback? onTap;
  final Widget Function(BuildContext context, {required bool hover}) builder;

  /// Index for drag-to-reorder from anywhere on the row.
  final int? dragIndex;

  @override
  State<_RowShell> createState() => _RowShellState();
}

class _RowShellState extends State<_RowShell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    Widget row = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color:
            widget.selected
                ? c.accentSubtle
                : (_hover ? c.hover : Colors.transparent),
        borderRadius: BorderRadius.circular(Radii.xs),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(Radii.xs),
          child: SizedBox(
            height: Chrome.control,
            child: widget.builder(context, hover: _hover),
          ),
        ),
      ),
    );
    if (widget.dragIndex case final index?) {
      row = ReorderableDelayedDragStartListener(index: index, child: row);
    }
    return row;
  }
}

class _LayerRow extends ConsumerStatefulWidget {
  const _LayerRow({
    required this.index,
    required this.object,
    required this.name,
    required this.selected,
    this.depth = 0,
    this.expanded,
    this.onToggle,
    super.key,
  });

  final int index;
  final DesignObject object;
  final String name;
  final bool selected;

  /// Nesting level; only top-level rows can be dragged.
  final int depth;

  /// Open state of a group row (`null` for other objects).
  final bool? expanded;
  final VoidCallback? onToggle;

  @override
  ConsumerState<_LayerRow> createState() => _LayerRowState();
}

class _LayerRowState extends ConsumerState<_LayerRow> {
  bool _editing = false;
  late final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _startRename() {
    _name.text = widget.name;
    setState(() => _editing = true);
  }

  void _finishRename() {
    if (!_editing) return;
    setState(() => _editing = false);
    final text = _name.text.trim();
    if (text.isEmpty || text == widget.name) return;
    ref
        .read(editorProvider.notifier)
        .updateObject(
          widget.object.id,
          (o) => o.copyWith(name: text),
          label: 'Rename',
        );
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.read(editorProvider.notifier);
    final o = widget.object;
    final c = context.ocx;
    final dimmed = o.hidden;
    return _RowShell(
      selected: widget.selected,
      dragIndex: _editing || widget.depth > 0 ? null : widget.index,
      onTap:
          o.locked || o.hidden
              ? null
              : () {
                final keys = HardwareKeyboard.instance;
                if (keys.isShiftPressed || keys.isControlPressed) {
                  editor.toggleSelected(o.id);
                } else {
                  editor.select({o.id});
                }
              },
      builder:
          (context, {required hover}) => Row(
            children: [
              SizedBox(width: Space.xs + widget.depth * Space.md),
              SizedBox(
                width: 16,
                child:
                    widget.expanded == null
                        ? null
                        : InkResponse(
                          onTap: widget.onToggle,
                          radius: 10,
                          child: Icon(
                            widget.expanded!
                                ? Icons.keyboard_arrow_down
                                : Icons.chevron_right,
                            size: 14,
                            color: c.textTertiary,
                          ),
                        ),
              ),
              const SizedBox(width: Space.xs),
              Icon(
                isComponent(o) ? Icons.widgets : objectIcon(o.type),
                size: 14,
                color: dimmed ? c.textTertiary : c.textSecondary,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child:
                    _editing
                        ? TextField(
                          controller: _name,
                          autofocus: true,
                          style: OcxText.body(context),
                          onSubmitted: (_) => _finishRename(),
                          onTapOutside: (_) => _finishRename(),
                        )
                        // Double-tap only on the name, so the row's buttons respond
                        // to single taps instantly.
                        : GestureDetector(
                          onDoubleTap: _startRename,
                          child: Text(
                            widget.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OcxText.body(
                              context,
                            ).copyWith(color: dimmed ? c.textTertiary : null),
                          ),
                        ),
              ),
              if (hover || o.locked)
                OcxIconButton(
                  icon:
                      o.locked ? Icons.lock_outline : Icons.lock_open_outlined,
                  iconSize: 14,
                  size: 24,
                  tooltip: o.locked ? 'Unlock' : 'Lock',
                  color: c.textSecondary,
                  onPressed:
                      () => editor.updateObject(
                        o.id,
                        (x) => x.copyWith(locked: !x.locked),
                        label: o.locked ? 'Unlock' : 'Lock',
                      ),
                ),
              if (hover || o.hidden)
                OcxIconButton(
                  icon:
                      o.hidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                  iconSize: 14,
                  size: 24,
                  tooltip: o.hidden ? 'Show' : 'Hide',
                  color: c.textSecondary,
                  onPressed:
                      () => editor.updateObject(
                        o.id,
                        (x) => x.copyWith(hidden: !x.hidden),
                        label: o.hidden ? 'Show' : 'Hide',
                      ),
                ),
              const SizedBox(width: Space.xs),
            ],
          ),
    );
  }
}
