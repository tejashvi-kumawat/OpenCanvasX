import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:renderer/renderer.dart';

import '../../theme/ocx_theme.dart';
import '../editor_controller.dart';

/// Pages (P1.2.2): thumbnails of every page and board, to switch, add,
/// duplicate, reorder and delete.
class PagesPanel extends ConsumerWidget {
  const PagesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(editorProvider);
    if (session == null) return const SizedBox.shrink();
    final editor = ref.read(editorProvider.notifier);
    final pages = session.document.pages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, 0),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: editor.addPage,
                  icon: const Icon(Icons.add, size: Chrome.icon),
                  label: const Text('Add page'),
                ),
              ),
              const SizedBox(width: Space.sm),
              Tooltip(
                message: 'Add a board — an unlimited canvas for frames',
                child: OutlinedButton.icon(
                  onPressed: editor.addBoard,
                  icon: const Icon(
                    Icons.dashboard_customize_outlined,
                    size: Chrome.icon,
                  ),
                  label: const Text('Board'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xl),
            itemCount: pages.length,
            onReorderItem: editor.movePage,
            itemBuilder:
                (context, i) => ReorderableDelayedDragStartListener(
                  key: ValueKey(pages[i].id),
                  index: i,
                  child: _PageCard(
                    index: i,
                    page: pages[i],
                    document: session.document,
                    active: pages[i].id == session.state.activePageId,
                    canDelete: pages.length > 1,
                  ),
                ),
          ),
        ),
      ],
    );
  }
}

class _PageCard extends ConsumerWidget {
  const _PageCard({
    required this.index,
    required this.page,
    required this.document,
    required this.active,
    required this.canDelete,
  });

  final int index;
  final DesignPage page;
  final DesignDocument document;
  final bool active;
  final bool canDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.read(editorProvider.notifier);
    final c = context.ocx;
    final name = page.name.isEmpty ? 'Page ${index + 1}' : page.name;
    final ratio = page.isBoard ? 16 / 10 : (page.width / page.height);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: c.surfaceSunken,
            borderRadius: BorderRadius.circular(Radii.md),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => editor.setActivePage(page.id),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: active ? c.accent : c.border,
                    width: active ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                padding: const EdgeInsets.all(Space.sm),
                child: AspectRatio(
                  aspectRatio: ratio.clamp(0.5, 2.4),
                  child:
                      page.isBoard
                          ? Center(
                            child: Icon(
                              Icons.dashboard_outlined,
                              size: 20,
                              color: c.textTertiary,
                            ),
                          )
                          : CustomPaint(
                            painter: PageThumbnailPainter(
                              document: document,
                              page: page,
                              media: ref.watch(mediaCacheProvider),
                            ),
                          ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${index + 1}  ·  $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (active
                          ? OcxText.bodyStrong(context)
                          : OcxText.body(context))
                      .copyWith(color: active ? c.text : c.textSecondary),
                ),
              ),
              MenuAnchor(
                menuChildren: [
                  MenuItemButton(
                    onPressed: () => editor.duplicatePage(page.id),
                    leadingIcon: const Icon(Icons.copy_all_outlined),
                    child: const Text('Duplicate page'),
                  ),
                  MenuItemButton(
                    onPressed:
                        canDelete ? () => editor.deletePage(page.id) : null,
                    leadingIcon: const Icon(Icons.delete_outline),
                    child: const Text('Delete page'),
                  ),
                ],
                builder:
                    (context, controller, _) => IconButton(
                      tooltip: 'Page actions',
                      iconSize: Chrome.icon,
                      visualDensity: VisualDensity.compact,
                      onPressed:
                          () =>
                              controller.isOpen
                                  ? controller.close()
                                  : controller.open(),
                      icon: const Icon(Icons.more_horiz),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
