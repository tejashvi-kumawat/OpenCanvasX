import 'package:asset_engine/asset_engine.dart';
import 'package:asset_packs/asset_packs.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../providers.dart';
import '../../theme/ocx_theme.dart';
import '../canvas_view.dart';
import '../editor_controller.dart';

/// Colour new monochrome icons get (the default text colour).
const ArgbColor defaultIconTint = ArgbColor.black;

/// Places a pack item on the canvas: loads its bytes from the bundle and
/// inserts it as an image, tinted if the pack is recolourable, with its
/// licence recorded (P2.1.4). Errors are shown as a snack bar.
Future<void> insertAssetItem(
  BuildContext context,
  WidgetRef ref,
  AssetItem item, {
  Point2D? at,
  PageId? pageId,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final catalog = await ref.read(assetCatalogProvider.future);
    final pack = catalog.pack(item.packId);
    final bytes = await loadItemBytes(rootBundle, item);
    ref
        .read(editorProvider.notifier)
        .insertImage(
          bytes,
          name: item.name,
          licenseRef: pack?.licenseRef,
          tint: (pack?.recolorable ?? false) ? defaultIconTint : null,
          sizePx: pack?.kind == AssetKind.sticker ? 200 : 160,
          at: at,
          pageId: pageId,
        );
  } on Object catch (e) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Could not add ${item.name}: $e')),
    );
  }
}

/// A square tile previewing a pack item; click to add, drag onto the
/// canvas to place.
class AssetTile extends ConsumerWidget {
  const AssetTile({
    required this.item,
    required this.recolorable,
    this.size = 56,
    super.key,
  });

  final AssetItem item;
  final bool recolorable;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ocx;
    final picture = SvgPicture.asset(
      packAssetKey(item.packId, item.file),
      width: size * 0.5,
      height: size * 0.5,
      colorFilter:
          recolorable ? ColorFilter.mode(c.text, BlendMode.srcIn) : null,
      placeholderBuilder: (_) => SizedBox.square(dimension: size * 0.5),
    );
    return Draggable<ElementDrag>(
      data: AssetDrag(item),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: SizedBox.square(dimension: size * 0.6, child: picture),
      child: Tooltip(
        message: item.name,
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          color: c.surfaceSunken,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: InkWell(
            onTap: () => insertAssetItem(context, ref, item),
            borderRadius: BorderRadius.circular(Radii.sm),
            child: SizedBox.square(
              dimension: size,
              child: Center(child: picture),
            ),
          ),
        ),
      ),
    );
  }
}

/// A lazily built grid of [items] that fills the panel width.
class AssetGrid extends StatelessWidget {
  const AssetGrid({
    required this.items,
    required this.recolorable,
    this.tile = 56,
    this.shrinkWrap = false,
    super.key,
  });

  final List<AssetItem> items;
  final bool Function(AssetItem item) recolorable;
  final double tile;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: shrinkWrap,
    physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
    padding: const EdgeInsets.symmetric(horizontal: Space.md),
    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: tile,
      mainAxisSpacing: Space.sm,
      crossAxisSpacing: Space.sm,
    ),
    itemCount: items.length,
    itemBuilder:
        (context, i) => AssetTile(
          key: ValueKey(items[i].id),
          item: items[i],
          recolorable: recolorable(items[i]),
          size: tile,
        ),
  );
}

/// Small pill used to filter by category or style.
class FilterChipRow<T> extends StatelessWidget {
  const FilterChipRow({
    required this.options,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    return SizedBox(
      height: 28,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        children: [
          for (final (value, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: Space.xs),
              child: Material(
                color: value == selected ? c.accentSubtle : c.surfaceSunken,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => onSelected(value),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.md,
                      vertical: 6,
                    ),
                    child: Text(
                      label,
                      style: OcxText.caption(context).copyWith(
                        color: value == selected ? c.accent : c.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Section header with an optional "See all" link.
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.onSeeAll, super.key});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.md,
        Space.sm,
        Space.sm,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: OcxText.bodyStrong(context))),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 24),
                padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                foregroundColor: c.accent,
                textStyle: OcxText.caption(context),
              ),
              child: const Text('See all'),
            ),
        ],
      ),
    );
  }
}
