import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/ocx_theme.dart';
import 'editor_controller.dart';
import 'editor_shortcuts.dart';
import 'viewport.dart';

/// Bottom bar (ux-spec.md "Bottom"): page navigation and zoom (P1.2.5).
class EditorBottomBar extends ConsumerWidget {
  const EditorBottomBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(editorProvider);
    if (session == null) return const SizedBox.shrink();
    final zoom = ref.watch(viewportProvider.select((v) => v.zoom));
    final view = ref.read(viewportProvider.notifier);
    final editor = ref.read(editorProvider.notifier);
    final ocx = context.ocx;
    final theme = Theme.of(context);
    final pages = session.document.pages;
    final index = session.state.activePageIndex;

    void goTo(int i) {
      editor.setActivePage(pages[i].id);
      final frame = layoutPages(pages)[i];
      view.reveal(frame.rect);
    }

    final selected = session.selection.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Narrow canvases drop the slider and the selection hint.
        final narrow = constraints.maxWidth < 760;
        return Container(
          height: Chrome.bottomBarHeight,
          decoration: BoxDecoration(
            color: ocx.panel,
            border: Border(top: BorderSide(color: ocx.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: Space.sm),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                tooltip: 'Previous page',
                visualDensity: VisualDensity.compact,
                onPressed: index > 0 ? () => goTo(index - 1) : null,
              ),
              Text(
                'Page ${index + 1} of ${pages.length}',
                style: theme.textTheme.labelLarge,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                tooltip: 'Next page',
                visualDensity: VisualDensity.compact,
                onPressed:
                    index < pages.length - 1 ? () => goTo(index + 1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                tooltip: 'Add page',
                visualDensity: VisualDensity.compact,
                onPressed: editor.addPage,
              ),
              const Spacer(),
              if (selected > 0 && !narrow)
                Padding(
                  padding: const EdgeInsets.only(right: Space.lg),
                  child: Text(
                    selected == 1
                        ? '1 element selected'
                        : '$selected elements selected',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                tooltip: 'Zoom out',
                visualDensity: VisualDensity.compact,
                onPressed: view.zoomOut,
              ),
              if (!narrow)
                SizedBox(
                  width: 150,
                  child: Slider(
                    value: _toSlider(zoom),
                    onChanged: (t) => view.setZoom(_fromSlider(t)),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'Zoom in',
                visualDensity: VisualDensity.compact,
                onPressed: view.zoomIn,
              ),
              _ZoomMenu(zoom: zoom),
              IconButton(
                icon: const Icon(Icons.fit_screen_outlined, size: 20),
                tooltip: 'Fit page',
                visualDensity: VisualDensity.compact,
                onPressed: () => fitActivePage(ref),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Logarithmic slider so 10 %–100 % gets as much travel as 100 %–800 %.
double _toSlider(double zoom) =>
    (math.log(zoom / minZoom) / math.log(maxZoom / minZoom)).clamp(0.0, 1.0);

double _fromSlider(double t) => minZoom * math.pow(maxZoom / minZoom, t);

class _ZoomMenu extends ConsumerWidget {
  const _ZoomMenu({required this.zoom});

  final double zoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.read(viewportProvider.notifier);
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          onPressed: () => fitActivePage(ref),
          shortcut: EditorKeys.fit,
          child: const Text('Fit page'),
        ),
        const Divider(),
        for (final level in const [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0])
          MenuItemButton(
            onPressed: () => view.setZoom(level),
            shortcut: level == 1 ? EditorKeys.actualSize : null,
            child: Text('${(level * 100).round()}%'),
          ),
      ],
      builder:
          (context, controller, _) => TextButton(
            onPressed:
                () =>
                    controller.isOpen ? controller.close() : controller.open(),
            style: TextButton.styleFrom(
              minimumSize: const Size(64, 32),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            child: Text('${(zoom * 100).round()}%'),
          ),
    );
  }
}
