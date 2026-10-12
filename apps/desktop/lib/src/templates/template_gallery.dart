import 'package:asset_packs/asset_packs.dart';
import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:renderer/renderer.dart';
import 'package:storage/storage.dart';
import 'package:template_engine/template_engine.dart';

import '../theme/ocx_theme.dart';

/// Official templates (P2.2.3), loaded from the bundle once.
final templatesProvider = FutureProvider<List<TemplateInfo>>(
  (ref) => loadBundledTemplates(rootBundle),
);

/// Decoded images of templates, for thumbnails (kept apart from the open
/// design's media).
final templateMediaProvider = Provider<MediaCache>((ref) {
  final cache = MediaCache();
  ref.onDispose(cache.dispose);
  return cache;
});

/// A template's design and asset bytes, decoded and validated (P2.2.5).
final templateContentsProvider =
    FutureProvider.family<ProjectContents, TemplateInfo>((ref, info) async {
      final bytes = await loadTemplateBytes(rootBundle, info);
      final contents = decodeProject(bytes);
      final issues = validateTemplate(contents.document);
      if (issues.isNotEmpty) {
        throw FormatException('Template "${info.name}" is invalid', issues);
      }
      final media = ref.read(templateMediaProvider);
      for (final MapEntry(key: hash, value: info)
          in contents.document.assets.entries) {
        if (contents.assets[hash] case final data?) {
          media.register(hash, data, info.mime);
        }
      }
      return contents;
    });

/// Searchable, filterable grid of templates. [onUse] receives the chosen
/// template with its decoded contents.
class TemplateGallery extends ConsumerStatefulWidget {
  const TemplateGallery({
    required this.onUse,
    this.columns,
    this.tileWidth = 180,
    this.query = '',
    this.shrinkWrap = false,
    this.limit,
    this.showFilters = true,
    super.key,
  });

  final void Function(TemplateInfo info, ProjectContents contents) onUse;

  /// Fixed column count; otherwise as many [tileWidth] columns as fit.
  final int? columns;
  final double tileWidth;
  final String query;
  final bool shrinkWrap;
  final int? limit;
  final bool showFilters;

  @override
  ConsumerState<TemplateGallery> createState() => _TemplateGalleryState();
}

class _TemplateGalleryState extends ConsumerState<TemplateGallery> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final templates = ref.watch(templatesProvider);
    return templates.when(
      loading: () => const SizedBox(height: 120),
      error:
          (e, _) => Text(
            'Templates could not load: $e',
            style: OcxText.caption(context).copyWith(color: c.danger),
          ),
      data: (all) {
        final categories = [
          for (final key in templateCategories.keys)
            if (all.any((t) => t.category == key)) key,
        ];
        var shown = [
          for (final t in all)
            if ((_category == null || t.category == _category) &&
                t.matches(widget.query))
              t,
        ];
        if (widget.limit case final limit?) shown = shown.take(limit).toList();
        final grid =
            shown.isEmpty
                ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.lg),
                  child: Text(
                    'No templates match "${widget.query}".',
                    style: OcxText.caption(context).copyWith(
                      color: c.textTertiary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                )
                : GridView.builder(
                  shrinkWrap: widget.shrinkWrap,
                  physics:
                      widget.shrinkWrap
                          ? const NeverScrollableScrollPhysics()
                          : null,
                  gridDelegate:
                      widget.columns != null
                          ? SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: widget.columns!,
                            mainAxisSpacing: Space.md,
                            crossAxisSpacing: Space.md,
                            childAspectRatio: 0.82,
                          )
                          : SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: widget.tileWidth,
                            mainAxisSpacing: Space.lg,
                            crossAxisSpacing: Space.lg,
                            childAspectRatio: 0.82,
                          ),
                  itemCount: shown.length,
                  itemBuilder:
                      (context, i) => TemplateCard(
                        key: ValueKey(shown[i].id),
                        info: shown[i],
                        onUse: widget.onUse,
                      ),
                );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: widget.shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
          children: [
            if (widget.showFilters)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: [
                    _Chip(
                      label: 'All',
                      selected: _category == null,
                      onTap: () => setState(() => _category = null),
                    ),
                    for (final key in categories)
                      _Chip(
                        label: templateCategories[key]!,
                        selected: _category == key,
                        onTap: () => setState(() => _category = key),
                      ),
                  ],
                ),
              ),
            if (widget.shrinkWrap) grid else Expanded(child: grid),
          ],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
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
    return Material(
      color: selected ? c.accentSubtle : c.surfaceSunken,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: 6,
          ),
          child: Text(
            label,
            style: OcxText.caption(
              context,
            ).copyWith(color: selected ? c.accent : c.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// One template: live thumbnail of its first page (or first frame), name
/// and size; hover lifts the card, click uses the template.
class TemplateCard extends ConsumerStatefulWidget {
  const TemplateCard({required this.info, required this.onUse, super.key});

  final TemplateInfo info;
  final void Function(TemplateInfo info, ProjectContents contents) onUse;

  @override
  ConsumerState<TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends ConsumerState<TemplateCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final info = widget.info;
    final contents = ref.watch(templateContentsProvider(info));
    final media = ref.watch(templateMediaProvider);
    final size =
        info.board
            ? 'Board · ${info.pages} page'
            : '${_fmt(info.width)} × ${_fmt(info.height)} ${info.unit}'
                '${info.pages > 1 ? ' · ${info.pages} pages' : ''}';
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap:
            contents.hasValue
                ? () => widget.onUse(info, contents.requireValue)
                : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                decoration: BoxDecoration(
                  color: c.surfaceSunken,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: _hover ? c.accent : c.border),
                  boxShadow:
                      _hover
                          ? const [
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ]
                          : null,
                ),
                padding: const EdgeInsets.all(Space.sm),
                child: switch (contents) {
                  AsyncData(:final value) => CustomPaint(
                    painter: _TemplateThumbnail(value.document, media),
                  ),
                  AsyncError() => Icon(
                    Icons.broken_image_outlined,
                    color: c.textTertiary,
                  ),
                  _ => const SizedBox.expand(),
                },
              ),
            ),
            const SizedBox(height: Space.sm),
            Text(
              info.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OcxText.bodyStrong(context),
            ),
            Text(
              size,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OcxText.caption(
                context,
              ).copyWith(color: c.textTertiary, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// Draws a template's first page — or, for boards, the content of the
/// board — centred and scaled into the card.
class _TemplateThumbnail extends CustomPainter {
  _TemplateThumbnail(this.document, this.media) : super(repaint: media);

  final DesignDocument document;
  final MediaCache media;

  @override
  void paint(Canvas canvas, Size size) {
    final page = document.pages.first;
    final region =
        page.isBoard
            ? (selectionBounds(document, page.objectIds) ??
                Rect2D.fromLTWH(0, 0, page.width, page.height))
            : Rect2D.fromLTWH(0, 0, page.width, page.height);
    if (region.width <= 0 || region.height <= 0 || size.isEmpty) return;
    final scale = [
      size.width / region.width,
      size.height / region.height,
    ].reduce((a, b) => a < b ? a : b);
    final dx = (size.width - region.width * scale) / 2;
    final dy = (size.height - region.height * scale) / 2;
    canvas
      ..save()
      ..translate(dx, dy)
      ..scale(scale)
      ..translate(-region.left, -region.top)
      ..clipRect(
        Rect.fromLTWH(region.left, region.top, region.width, region.height),
      );
    if (page.isBoard) {
      if (page.background case SolidBackground(:final color)) {
        canvas.drawRect(
          Rect.fromLTWH(region.left, region.top, region.width, region.height),
          Paint()..color = Color(color.value),
        );
      }
    } else {
      paintPageBackground(canvas, page);
    }
    paintPageContent(canvas, document, page, media: media);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TemplateThumbnail oldDelegate) =>
      !identical(oldDelegate.document, document);
}
