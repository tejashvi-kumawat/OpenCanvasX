import 'dart:math' as math;

import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:renderer/renderer.dart';
import 'package:storage/storage.dart';

import '../../templates/template_gallery.dart';
import '../../theme/ocx_theme.dart';
import '../editor_controller.dart';
import 'asset_tiles.dart';

/// The official UI kit (a board of main components in the template
/// repository), if a source provides it.
final uiKitProvider = FutureProvider<ProjectContents?>((ref) async {
  final entries = await ref.watch(templatesProvider.future);
  final kit = entries.where((e) => e.info.id == 'ui-kit').firstOrNull;
  if (kit == null) return null;
  return ref.watch(templateContentsProvider(kit).future);
});

/// "UI kit" in Elements: ready-made components with live previews. Using
/// one copies it into the design as a main component (or adds an instance
/// when it is already there).
class UiKitSection extends ConsumerWidget {
  const UiKitSection({required this.query, super.key});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = ref.watch(uiKitProvider).value;
    if (kit == null) return const SizedBox.shrink();
    final media = ref.watch(templateMediaProvider);
    final components = [
      for (final c in componentsIn(kit.document))
        if (query.isEmpty ||
            (c.name ?? '').toLowerCase().contains(query.toLowerCase()) ||
            'ui kit component'.contains(query.toLowerCase()))
          c,
    ];
    if (components.isEmpty) return const SizedBox.shrink();
    final c = context.ocx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'UI kit'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: Space.sm,
              crossAxisSpacing: Space.sm,
              childAspectRatio: 1.25,
            ),
            itemCount: components.length,
            itemBuilder: (context, i) {
              final component = components[i];
              return Tooltip(
                message: 'Add ${component.name}',
                child: Material(
                  color: c.surfaceSunken,
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Radii.md),
                    onTap:
                        () => ref
                            .read(editorProvider.notifier)
                            .importComponent(kit, component.id),
                    child: Padding(
                      padding: const EdgeInsets.all(Space.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: CustomPaint(
                              painter: _ComponentPreview(
                                kit.document,
                                component,
                                media,
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.xs),
                          Text(
                            component.name ?? 'Component',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OcxText.caption(
                              context,
                            ).copyWith(color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ComponentPreview extends CustomPainter {
  _ComponentPreview(this.document, this.component, this.media)
    : super(repaint: media);

  final DesignDocument document;
  final DesignObject component;
  final MediaCache media;

  @override
  void paint(Canvas canvas, Size size) {
    final t = component.transform;
    if (t.width <= 0 || t.height <= 0 || size.isEmpty) return;
    final scale = math.min(size.width / t.width, size.height / t.height);
    canvas
      ..save()
      ..translate(
        (size.width - t.width * scale) / 2,
        (size.height - t.height * scale) / 2,
      )
      ..scale(scale)
      ..translate(-t.x, -t.y);
    paintObject(canvas, document, component, media: media);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ComponentPreview old) =>
      old.component != component || !identical(old.document, document);
}
