import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/ocx_theme.dart';
import '../widgets/controls.dart';
import '../widgets/object_icons.dart';
import '../widgets/shape_preview.dart';
import 'canvas_view.dart';
import 'editor_controller.dart';
import 'viewport.dart';

/// Tabs of the left sidebar (design-system.md §5).
enum LeftTab { layers, elements }

final leftTabProvider = NotifierProvider<LeftTabController, LeftTab>(
  LeftTabController.new,
);

class LeftTabController extends Notifier<LeftTab> {
  @override
  LeftTab build() => LeftTab.layers;

  LeftTab get tab => state;
  set tab(LeftTab value) => state = value;
}

/// Left sidebar: Layers (pages + layers) and Elements.
class LeftSidebar extends ConsumerWidget {
  const LeftSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(leftTabProvider);
    final c = context.ocx;
    return Container(
      width: Chrome.leftSidebar,
      color: c.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.sm),
              child: Row(
                children: [
                  for (final (value, label) in const [
                    (LeftTab.layers, 'Layers'),
                    (LeftTab.elements, 'Elements'),
                  ])
                    _Tab(
                      label: label,
                      selected: tab == value,
                      onTap:
                          () => ref.read(leftTabProvider.notifier).tab = value,
                    ),
                ],
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: switch (tab) {
              LeftTab.layers => const _LayersTab(),
              LeftTab.elements => const _ElementsTab(),
            },
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.xs),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 2),
            Text(
              label,
              style: OcxText.bodyStrong(
                context,
              ).copyWith(color: selected ? c.text : c.textSecondary),
            ),
            const SizedBox(height: 6),
            Container(
              height: 2,
              width: 24,
              color: selected ? c.accent : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ layers

class _LayersTab extends ConsumerStatefulWidget {
  const _LayersTab();

  @override
  ConsumerState<_LayersTab> createState() => _LayersTabState();
}

class _LayersTabState extends ConsumerState<_LayersTab> {
  bool _pagesOpen = true;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(editorProvider);
    if (session == null) return const SizedBox.shrink();
    final editor = ref.read(editorProvider.notifier);
    final pages = session.document.pages;
    final page = session.activePage;
    final topFirst = page.objectIds.reversed.toList();
    final c = context.ocx;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelSection(
          title: 'Pages',
          divider: false,
          trailing: [
            OcxIconButton(
              icon: Icons.add,
              tooltip: 'Add page  (Ctrl+Enter)',
              onPressed: editor.addPage,
            ),
            OcxIconButton(
              icon: _pagesOpen ? Icons.expand_less : Icons.expand_more,
              tooltip: _pagesOpen ? 'Collapse pages' : 'Expand pages',
              onPressed: () => setState(() => _pagesOpen = !_pagesOpen),
            ),
          ],
        ),
        if (_pagesOpen)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 168),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(
                Space.sm,
                0,
                Space.sm,
                Space.sm,
              ),
              itemCount: pages.length,
              onReorderItem: editor.movePage,
              itemBuilder:
                  (context, i) => _PageRow(
                    key: ValueKey(pages[i].id),
                    index: i,
                    page: pages[i],
                    active: pages[i].id == session.state.activePageId,
                    canDelete: pages.length > 1,
                  ),
            ),
          ),
        const Divider(),
        PanelSection(
          title: 'Layers',
          divider: false,
          trailing: [
            Padding(
              padding: const EdgeInsets.only(right: Space.xs),
              child: Text(
                '${topFirst.length}',
                style: OcxText.caption(context).copyWith(color: c.textTertiary),
              ),
            ),
          ],
        ),
        Expanded(
          child:
              topFirst.isEmpty
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
                    itemCount: topFirst.length,
                    onReorderItem: (from, to) {
                      final list = [...topFirst];
                      final moved = list.removeAt(from);
                      list.insert(to, moved);
                      editor.setLayerOrder(list.reversed.toList());
                    },
                    itemBuilder: (context, index) {
                      final id = topFirst[index];
                      final object = session.document.objects[id]!;
                      return _LayerRow(
                        key: ValueKey(id),
                        index: index,
                        object: object,
                        name: layerName(session.document, page, object),
                        selected: session.selection.contains(id),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

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

class _PageRow extends ConsumerWidget {
  const _PageRow({
    required this.index,
    required this.page,
    required this.active,
    required this.canDelete,
    super.key,
  });

  final int index;
  final DesignPage page;
  final bool active;
  final bool canDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.read(editorProvider.notifier);
    final c = context.ocx;
    return _RowShell(
      selected: active,
      dragIndex: index,
      onTap: () {
        editor
          ..setActivePage(page.id)
          ..clearSelection();
        final session = ref.read(editorProvider);
        if (session != null) {
          ref
              .read(viewportProvider.notifier)
              .reveal(layoutPages(session.document.pages)[index].rect);
        }
      },
      builder:
          (context, {required hover}) => Row(
            children: [
              const SizedBox(width: Space.sm),
              Icon(
                Icons.insert_drive_file_outlined,
                size: 14,
                color: active ? c.accent : c.textSecondary,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  page.name.isEmpty ? 'Page ${index + 1}' : page.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      active
                          ? OcxText.bodyStrong(context)
                          : OcxText.body(context),
                ),
              ),
              if (hover) ...[
                OcxIconButton(
                  icon: Icons.content_copy_outlined,
                  iconSize: 14,
                  size: 24,
                  tooltip: 'Duplicate page',
                  onPressed: () => editor.duplicatePage(page.id),
                ),
                OcxIconButton(
                  icon: Icons.delete_outline,
                  iconSize: 14,
                  size: 24,
                  tooltip: 'Delete page',
                  onPressed:
                      canDelete ? () => editor.deletePage(page.id) : null,
                ),
              ],
              const SizedBox(width: Space.xs),
            ],
          ),
    );
  }
}

class _LayerRow extends ConsumerStatefulWidget {
  const _LayerRow({
    required this.index,
    required this.object,
    required this.name,
    required this.selected,
    super.key,
  });

  final int index;
  final DesignObject object;
  final String name;
  final bool selected;

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
      dragIndex: _editing ? null : widget.index,
      onTap: o.locked || o.hidden ? null : () => editor.select({o.id}),
      builder:
          (context, {required hover}) => Row(
            children: [
              const SizedBox(width: Space.sm),
              Icon(
                objectIcon(o.type),
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

// ---------------------------------------------------------------- elements

class _ElementsTab extends ConsumerStatefulWidget {
  const _ElementsTab();

  @override
  ConsumerState<_ElementsTab> createState() => _ElementsTabState();
}

class _ElementsTabState extends ConsumerState<_ElementsTab> {
  String _query = '';

  static const _shapes = [
    ObjectType.rect,
    ObjectType.roundedRect,
    ObjectType.ellipse,
    ObjectType.polygon,
    ObjectType.star,
  ];
  static const _lines = [ObjectType.line, ObjectType.arrow];

  bool _matches(String label) =>
      _query.isEmpty || label.toLowerCase().contains(_query.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final editor = ref.read(editorProvider.notifier);
    final texts = TextRole.values.where((r) => _matches(r.label)).toList();
    final shapes = _shapes.where((t) => _matches(typeLabel(t))).toList();
    final lines = _lines.where((t) => _matches(typeLabel(t))).toList();
    final c = context.ocx;
    return ListView(
      padding: const EdgeInsets.only(bottom: Space.lg),
      children: [
        Padding(
          padding: const EdgeInsets.all(Space.md),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            style: OcxText.body(context),
            decoration: const InputDecoration(
              hintText: 'Search elements',
              prefixIcon: Icon(Icons.search, size: Chrome.icon),
              prefixIconConstraints: BoxConstraints(minWidth: 28),
            ),
          ),
        ),
        if (texts.isNotEmpty)
          PanelSection(
            title: 'Text',
            child: FieldColumn(
              children: [
                for (final role in texts)
                  _TextElement(
                    role: role,
                    onTap: () => editor.insertText(role),
                  ),
              ],
            ),
          ),
        if (shapes.isNotEmpty)
          PanelSection(
            title: 'Shapes',
            child: _TileGrid(
              children: [
                for (final type in shapes)
                  _ShapeTile(type: type, onTap: () => editor.insertShape(type)),
              ],
            ),
          ),
        if (lines.isNotEmpty)
          PanelSection(
            title: 'Lines',
            child: _TileGrid(
              children: [
                for (final type in lines)
                  _ShapeTile(type: type, onTap: () => editor.insertShape(type)),
              ],
            ),
          ),
        if (texts.isEmpty && shapes.isEmpty && lines.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Text(
              'Nothing matches "$_query".',
              style: OcxText.caption(context).copyWith(color: c.textTertiary),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Text(
            'Click to add to the current page, or drag onto the canvas.',
            style: OcxText.caption(
              context,
            ).copyWith(color: c.textTertiary, fontWeight: FontWeight.w400),
          ),
        ),
      ],
    );
  }
}

class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: Space.sm, runSpacing: Space.sm, children: children);
}

class _ShapeTile extends StatelessWidget {
  const _ShapeTile({required this.type, required this.onTap});

  final ObjectType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final isLine = type == ObjectType.line || type == ObjectType.arrow;
    final color = isLine ? c.text : c.textTertiary;
    return Draggable<ElementDrag>(
      data: ShapeDrag(type),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: ShapePreview(type: type, color: color),
      child: Tooltip(
        message: typeLabel(type),
        child: Material(
          color: c.surfaceSunken,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.sm),
            child: SizedBox.square(
              dimension: 48,
              child: Center(
                child: ShapePreview(type: type, color: color, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextElement extends StatelessWidget {
  const _TextElement({required this.role, required this.onTap});

  final TextRole role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final style = switch (role) {
      TextRole.heading => const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      TextRole.subheading => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      TextRole.body => const TextStyle(fontSize: 12),
    }.copyWith(color: c.text);
    return Draggable<ElementDrag>(
      data: TextDrag(role),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Text(role.label, style: style),
      ),
      child: Material(
        color: c.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: Container(
            height: 40,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: Text('Add ${role.label.toLowerCase()}', style: style),
          ),
        ),
      ),
    );
  }
}
