import 'dart:math' as math;

import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:renderer/renderer.dart';

import '../theme/ocx_theme.dart';
import '../widgets/shape_preview.dart';
import 'editor_controller.dart';
import 'viewport.dart';

/// Panels reachable from the left rail (ux-spec.md "Left").
enum LeftPanel {
  elements('Elements', Icons.category_outlined, Icons.category),
  layers('Layers', Icons.layers_outlined, Icons.layers),
  pages('Pages', Icons.auto_awesome_motion_outlined, Icons.auto_awesome_motion);

  const LeftPanel(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Open panel, or `null` when collapsed.
final leftPanelProvider = NotifierProvider<LeftPanelController, LeftPanel?>(
  LeftPanelController.new,
);

class LeftPanelController extends Notifier<LeftPanel?> {
  @override
  LeftPanel? build() => LeftPanel.elements;

  /// Opens [panel], or collapses it if it is already open.
  void toggle(LeftPanel panel) => state = state == panel ? null : panel;
}

/// Rail plus the open panel.
class LeftSide extends ConsumerWidget {
  const LeftSide({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(leftPanelProvider);
    final ocx = context.ocx;
    return ColoredBox(
      color: ocx.panel,
      child: Row(
        children: [
          SizedBox(
            width: Chrome.railWidth,
            child: Column(
              children: [
                const SizedBox(height: Space.sm),
                for (final panel in LeftPanel.values)
                  _RailItem(
                    panel: panel,
                    selected: panel == open,
                    onTap:
                        () =>
                            ref.read(leftPanelProvider.notifier).toggle(panel),
                  ),
              ],
            ),
          ),
          if (open != null) ...[
            VerticalDivider(color: ocx.border),
            SizedBox(
              width: Chrome.sidePanelWidth,
              child: switch (open) {
                LeftPanel.elements => const _ElementsPanel(),
                LeftPanel.layers => const _LayersPanel(),
                LeftPanel.pages => const _PagesPanel(),
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.panel,
    required this.selected,
    required this.onTap,
  });

  final LeftPanel panel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ocx = context.ocx;
    final color = selected ? theme.colorScheme.primary : ocx.subtleText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 3),
      child: Material(
        color: selected ? ocx.selectedFill : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.md),
          child: SizedBox(
            height: 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(selected ? panel.selectedIcon : panel.icon, color: color),
                const SizedBox(height: 4),
                Text(
                  panel.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.sm, Space.sm),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (trailing case final widget?) widget,
      ],
    ),
  );
}

// ---------------------------------------------------------------- elements

class _ElementsPanel extends StatefulWidget {
  const _ElementsPanel();

  @override
  State<_ElementsPanel> createState() => _ElementsPanelState();
}

class _ElementsPanelState extends State<_ElementsPanel> {
  String _query = '';

  static const _shapes = [
    ObjectType.rect,
    ObjectType.roundedRect,
    ObjectType.ellipse,
  ];
  static const _lines = [ObjectType.line, ObjectType.arrow];

  bool _matches(ObjectType type) =>
      _query.isEmpty ||
      typeLabel(type).toLowerCase().contains(_query.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final shapes = _shapes.where(_matches).toList();
    final lines = _lines.where(_matches).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PanelHeader(title: 'Elements'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: const InputDecoration(
              hintText: 'Search elements',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Space.lg),
            children: [
              if (shapes.isNotEmpty) ...[
                const _GroupTitle('Shapes'),
                _ElementGrid(types: shapes),
                const SizedBox(height: Space.xl),
              ],
              if (lines.isNotEmpty) ...[
                const _GroupTitle('Lines'),
                _ElementGrid(types: lines),
              ],
              if (shapes.isEmpty && lines.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xl),
                  child: Text(
                    'No elements match "$_query".',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: Space.xl),
              Text(
                'Click to add to the page, or drag onto the canvas.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _ElementGrid extends ConsumerWidget {
  const _ElementGrid({required this.types});

  final List<ObjectType> types;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Space.sm,
      crossAxisSpacing: Space.sm,
      childAspectRatio: 0.92,
      children: [
        for (final type in types)
          _ElementTile(
            type: type,
            onTap: () => ref.read(editorProvider.notifier).insertShape(type),
          ),
      ],
    );
  }
}

class _ElementTile extends StatefulWidget {
  const _ElementTile({required this.type, required this.onTap});

  final ObjectType type;
  final VoidCallback onTap;

  @override
  State<_ElementTile> createState() => _ElementTileState();
}

class _ElementTileState extends State<_ElementTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ocx = context.ocx;
    final theme = Theme.of(context);
    final isLine =
        widget.type == ObjectType.line || widget.type == ObjectType.arrow;
    final color =
        isLine ? theme.colorScheme.onSurface : toUiColor(defaultShapeFill);
    final preview = ShapePreview(type: widget.type, color: color);
    return Draggable<ObjectType>(
      data: widget.type,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Opacity(
        opacity: 0.85,
        child: ShapePreview(type: widget.type, color: color, size: 64),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Tooltip(
          message: 'Add ${typeLabel(widget.type).toLowerCase()}',
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(Radii.md),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                color:
                    _hover ? ocx.hover : theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                  color:
                      _hover
                          ? ocx.selection.withValues(alpha: 0.5)
                          : ocx.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  preview,
                  const SizedBox(height: Space.sm),
                  Text(
                    _tileLabel(widget.type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
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

/// Short labels that fit element tiles.
String _tileLabel(ObjectType type) =>
    type == ObjectType.roundedRect ? 'Rounded' : typeLabel(type);

// ------------------------------------------------------------------ layers

class _LayersPanel extends ConsumerWidget {
  const _LayersPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(editorProvider);
    if (session == null) return const SizedBox.shrink();
    final page = session.activePage;
    final topFirst = page.objectIds.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(
          title: 'Layers',
          trailing: Text(
            'Page ${session.state.activePageIndex + 1}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (topFirst.isEmpty)
          const _EmptyHint(
            icon: Icons.layers_clear_outlined,
            text:
                'Elements you add to this page will be listed here, '
                'top to bottom.',
          )
        else
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.sm,
                vertical: Space.xs,
              ),
              buildDefaultDragHandles: false,
              itemCount: topFirst.length,
              onReorderItem: (from, to) {
                final list = [...topFirst];
                final moved = list.removeAt(from);
                list.insert(to, moved);
                ref
                    .read(editorProvider.notifier)
                    .setLayerOrder(list.reversed.toList());
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
  bool _hover = false;
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
    final ocx = context.ocx;
    final theme = Theme.of(context);
    final fill = switch (o.style?.fill) {
      SolidFill(:final color) => toUiColor(color),
      _ => switch (o.style?.stroke) {
        final s? => toUiColor(s.color),
        null => ocx.subtleText,
      },
    };
    final dimmed = o.hidden;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Material(
          color:
              widget.selected
                  ? ocx.selectedFill
                  : (_hover ? ocx.hover : Colors.transparent),
          borderRadius: BorderRadius.circular(Radii.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.sm),
            onTap: o.locked || o.hidden ? null : () => editor.select({o.id}),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: widget.index,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 18,
                        color: ocx.subtleText.withValues(
                          alpha: _hover ? 1 : 0.4,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(Radii.sm),
                      border: Border.all(color: ocx.border),
                    ),
                    child: Opacity(
                      opacity: dimmed ? 0.35 : 1,
                      child: ShapePreview(type: o.type, color: fill, size: 22),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child:
                        _editing
                            ? TextField(
                              controller: _name,
                              autofocus: true,
                              style: theme.textTheme.bodyMedium,
                              onSubmitted: (_) => _finishRename(),
                              onTapOutside: (_) => _finishRename(),
                            )
                            // Double-tap only on the name, so the row's
                            // buttons respond to single taps instantly.
                            : GestureDetector(
                              onDoubleTap: _startRename,
                              child: Text(
                                widget.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: dimmed ? ocx.subtleText : null,
                                ),
                              ),
                            ),
                  ),
                  _RowToggle(
                    visible: _hover || o.hidden,
                    icon:
                        o.hidden
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                    tooltip: o.hidden ? 'Show' : 'Hide',
                    onPressed:
                        () => editor.updateObject(
                          o.id,
                          (x) => x.copyWith(hidden: !x.hidden),
                          label: o.hidden ? 'Show' : 'Hide',
                        ),
                  ),
                  _RowToggle(
                    visible: _hover || o.locked,
                    icon:
                        o.locked
                            ? Icons.lock_outline
                            : Icons.lock_open_outlined,
                    tooltip: o.locked ? 'Unlock' : 'Lock',
                    onPressed:
                        () => editor.updateObject(
                          o.id,
                          (x) => x.copyWith(locked: !x.locked),
                          label: o.locked ? 'Unlock' : 'Lock',
                        ),
                  ),
                  const SizedBox(width: Space.xs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RowToggle extends StatelessWidget {
  const _RowToggle({
    required this.visible,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final bool visible;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: visible ? 1 : 0,
    child: IconButton(
      icon: Icon(icon, size: 17),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      color: context.ocx.subtleText,
    ),
  );
}

// ------------------------------------------------------------------- pages

class _PagesPanel extends ConsumerWidget {
  const _PagesPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(editorProvider);
    if (session == null) return const SizedBox.shrink();
    final pages = session.document.pages;
    final editor = ref.read(editorProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(
          title: 'Pages',
          trailing: Text(
            '${pages.length} ${pages.length == 1 ? 'page' : 'pages'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            buildDefaultDragHandles: false,
            itemCount: pages.length,
            onReorderItem: editor.movePage,
            itemBuilder:
                (context, index) => _PageCard(
                  key: ValueKey(pages[index].id),
                  index: index,
                  document: session.document,
                  page: pages[index],
                  active: pages[index].id == session.state.activePageId,
                  canDelete: pages.length > 1,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: FilledButton.tonalIcon(
            onPressed: editor.addPage,
            icon: const Icon(Icons.add),
            label: const Text('Add page'),
          ),
        ),
      ],
    );
  }
}

class _PageCard extends ConsumerStatefulWidget {
  const _PageCard({
    required this.index,
    required this.document,
    required this.page,
    required this.active,
    required this.canDelete,
    super.key,
  });

  final int index;
  final DesignDocument document;
  final DesignPage page;
  final bool active;
  final bool canDelete;

  @override
  ConsumerState<_PageCard> createState() => _PageCardState();
}

class _PageCardState extends ConsumerState<_PageCard> {
  bool _hover = false;

  void _open() {
    final editor = ref.read(editorProvider.notifier)
      ..setActivePage(widget.page.id);
    final session = ref.read(editorProvider);
    if (session == null) return;
    final frame = layoutPages(session.document.pages)[widget.index];
    ref.read(viewportProvider.notifier).reveal(frame.rect);
    editor.clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final ocx = context.ocx;
    final theme = Theme.of(context);
    final editor = ref.read(editorProvider.notifier);
    final page = widget.page;
    final aspect = page.width / page.height;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: Space.md),
        child: ReorderableDragStartListener(
          index: widget.index,
          child: GestureDetector(
            onTap: _open,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 132,
                      padding: const EdgeInsets.all(Space.sm),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(
                          color: widget.active ? ocx.selection : ocx.border,
                          width: widget.active ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: math.max(aspect, 0.2),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(color: ocx.pageShadow, blurRadius: 6),
                              ],
                            ),
                            child: CustomPaint(
                              painter: PageThumbnailPainter(
                                document: widget.document,
                                page: page,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_hover)
                      Positioned(
                        top: Space.xs,
                        right: Space.xs,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(Radii.sm),
                            border: Border.all(color: ocx.border),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.copy_all_outlined,
                                  size: 16,
                                ),
                                tooltip: 'Duplicate page',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => editor.duplicatePage(page.id),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                ),
                                tooltip: 'Delete page',
                                visualDensity: VisualDensity.compact,
                                onPressed:
                                    widget.canDelete
                                        ? () => editor.deletePage(page.id)
                                        : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text(
                  page.name.isEmpty
                      ? '${widget.index + 1}'
                      : '${widget.index + 1}  ·  ${page.name}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: widget.active ? theme.colorScheme.primary : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Space.xl),
    child: Column(
      children: [
        Icon(icon, size: 36, color: context.ocx.subtleText),
        const SizedBox(height: Space.md),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
