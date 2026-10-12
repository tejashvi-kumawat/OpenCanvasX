import 'package:asset_engine/asset_engine.dart';
import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../theme/ocx_theme.dart';
import '../../widgets/shape_preview.dart';
import '../canvas_view.dart';
import '../editor_controller.dart';
import 'asset_tiles.dart';

/// What the Elements panel shows: the overview or one browser.
enum _View { overview, icons, stickers }

/// Elements (P2.1.2, P2.1.3): shapes, lines, frames, icons and stickers in
/// one searchable place. The overview shows a few of each; "See all" opens
/// a browser with filters.
class ElementsPanel extends ConsumerStatefulWidget {
  const ElementsPanel({super.key});

  @override
  ConsumerState<ElementsPanel> createState() => _ElementsPanelState();
}

class _ElementsPanelState extends ConsumerState<ElementsPanel> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  _View _view = _View.overview;
  String _iconPack = 'lucide';
  String? _iconStyle;
  String? _stickerGroup;

  static const _shapes = [
    ObjectType.rect,
    ObjectType.roundedRect,
    ObjectType.ellipse,
    ObjectType.polygon,
    ObjectType.star,
  ];
  static const _lines = [ObjectType.line, ObjectType.arrow];

  /// Popular picks shown before searching.
  static const _featuredIcons = [
    'lucide/heart',
    'lucide/star',
    'lucide/check',
    'lucide/arrow-right',
    'lucide/sparkles',
    'lucide/rocket',
    'lucide/camera',
    'lucide/music',
    'lucide/sun',
    'lucide/leaf',
    'lucide/coffee',
    'lucide/gift',
    'lucide/map-pin',
    'lucide/mail',
    'lucide/phone',
  ];
  static const _featuredStickers = [
    'twemoji/1f600',
    'twemoji/1f60d',
    'twemoji/1f602',
    'twemoji/1f60e',
    'twemoji/1f44d',
    'twemoji/2764',
    'twemoji/1f525',
    'twemoji/2b50',
    'twemoji/1f389',
    'twemoji/1f680',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(String label) =>
      _query.isEmpty || label.toLowerCase().contains(_query.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(assetCatalogProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.sm,
            Space.md,
            Space.xs,
          ),
          child: Row(
            children: [
              if (_view != _View.overview)
                IconButton(
                  tooltip: 'Back to elements',
                  iconSize: Chrome.icon,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _view = _View.overview),
                  icon: const Icon(Icons.arrow_back),
                ),
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  style: OcxText.body(context),
                  decoration: InputDecoration(
                    hintText: switch (_view) {
                      _View.overview => 'Search shapes, icons, stickers',
                      _View.icons => 'Search icons',
                      _View.stickers => 'Search stickers',
                    },
                    prefixIcon: const Icon(Icons.search, size: Chrome.icon),
                    prefixIconConstraints: const BoxConstraints(minWidth: 28),
                    suffixIcon:
                        _query.isEmpty
                            ? null
                            : IconButton(
                              tooltip: 'Clear search',
                              iconSize: 14,
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch ((catalog, _view)) {
            (AsyncData(value: final catalog), _View.icons) => _iconBrowser(
              catalog,
            ),
            (AsyncData(value: final catalog), _View.stickers) =>
              _stickerBrowser(catalog),
            (AsyncError(:final error), _) => _overview(
              null,
              note: 'The icon library could not load: $error',
            ),
            (AsyncData(value: final catalog), _) => _overview(catalog),
            _ => _overview(null, note: 'Loading icons and stickers…'),
          },
        ),
      ],
    );
  }

  bool Function(AssetItem) _recolorable(AssetCatalog catalog) =>
      (item) => catalog.pack(item.packId)?.recolorable ?? false;

  /// Shapes, lines and frames are always available; icons and stickers
  /// appear once [catalog] has loaded.
  Widget _overview(AssetCatalog? catalog, {String? note}) {
    final editor = ref.read(editorProvider.notifier);
    final shapes = _shapes.where((t) => _matches(typeLabel(t))).toList();
    final lines = _lines.where((t) => _matches(typeLabel(t))).toList();
    final frames =
        framePresets.where((p) => _matches('frame ${p.name}')).toList();
    final session = ref.watch(editorProvider);
    final components = [
      if (session != null)
        for (final c in componentsIn(session.document))
          if (_matches('component ${c.name ?? ''}')) c,
    ];
    final icons =
        catalog == null
            ? const <AssetItem>[]
            : _query.isEmpty
            ? catalog.items(_featuredIcons)
            : catalog.search(_query, kind: AssetKind.icon, limit: 60);
    final stickers =
        catalog == null
            ? const <AssetItem>[]
            : _query.isEmpty
            ? catalog.items(_featuredStickers)
            : catalog.search(_query, kind: AssetKind.sticker, limit: 40);
    final nothing =
        shapes.isEmpty &&
        lines.isEmpty &&
        frames.isEmpty &&
        icons.isEmpty &&
        stickers.isEmpty;
    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xl),
      children: [
        if (shapes.isNotEmpty || lines.isNotEmpty) ...[
          const SectionHeader(title: 'Shapes and lines'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final type in [...shapes, ...lines])
                  _ShapeTile(type: type, onTap: () => editor.insertShape(type)),
              ],
            ),
          ),
        ],
        if (components.isNotEmpty) ...[
          const SectionHeader(title: 'Components in this design'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                for (final component in components)
                  ActionChip(
                    avatar: const Icon(Icons.widgets, size: 14),
                    label: Text(component.name ?? 'Component'),
                    tooltip: 'Add an instance',
                    labelStyle: OcxText.caption(context),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => editor.insertInstance(component.id),
                  ),
              ],
            ),
          ),
        ],
        if (frames.isNotEmpty) ...[
          const SectionHeader(title: 'Frames'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                for (final p in frames.take(_query.isEmpty ? 8 : 20))
                  ActionChip(
                    label: Text(p.name),
                    tooltip: 'Add a ${p.sizeLabel} frame',
                    labelStyle: OcxText.caption(context),
                    visualDensity: VisualDensity.compact,
                    onPressed:
                        () => editor.insertFrame(
                          width: p.width,
                          height: p.height,
                          name: p.name,
                        ),
                  ),
              ],
            ),
          ),
        ],
        if (icons.isNotEmpty) ...[
          SectionHeader(
            title: 'Icons',
            onSeeAll: () => setState(() => _view = _View.icons),
          ),
          AssetGrid(
            items: icons,
            recolorable: _recolorable(catalog!),
            tile: 48,
            shrinkWrap: true,
          ),
        ],
        if (stickers.isNotEmpty) ...[
          SectionHeader(
            title: 'Stickers',
            onSeeAll: () => setState(() => _view = _View.stickers),
          ),
          AssetGrid(
            items: stickers,
            recolorable: _recolorable(catalog!),
            tile: 52,
            shrinkWrap: true,
          ),
        ],
        if (note != null) _Message(note),
        if (nothing && catalog != null) _Message('Nothing matches "$_query".'),
        const _Message(
          'Click to add, or drag onto the canvas. Icons take the fill '
          'colour you pick in the inspector.',
        ),
      ],
    );
  }

  Widget _iconBrowser(AssetCatalog catalog) {
    final packs = catalog.packs.where((p) => p.kind == AssetKind.icon).toList();
    final pack = catalog.pack(_iconPack) ?? packs.first;
    final styles =
        {
          for (final item in pack.items)
            if (item.style != null) item.style!,
        }.toList();
    final items = catalog.search(
      _query,
      packId: pack.id,
      style: styles.contains(_iconStyle) ? _iconStyle : null,
      limit: 2000,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Space.xs),
        FilterChipRow<String>(
          options: [for (final p in packs) (p.id, p.name)],
          selected: pack.id,
          onSelected:
              (id) => setState(() {
                _iconPack = id;
                _iconStyle = null;
              }),
        ),
        if (styles.isNotEmpty) ...[
          const SizedBox(height: Space.xs),
          FilterChipRow<String?>(
            options: [
              (null, 'All styles'),
              for (final s in styles) (s, s[0].toUpperCase() + s.substring(1)),
            ],
            selected: _iconStyle,
            onSelected: (s) => setState(() => _iconStyle = s),
          ),
        ],
        const SizedBox(height: Space.sm),
        Expanded(
          child:
              items.isEmpty
                  ? _Message('No ${pack.name} icons match "$_query".')
                  : AssetGrid(
                    items: items,
                    recolorable: _recolorable(catalog),
                    tile: 48,
                  ),
        ),
        _LicenseFooter(pack: pack),
      ],
    );
  }

  Widget _stickerBrowser(AssetCatalog catalog) {
    final packs =
        catalog.packs.where((p) => p.kind == AssetKind.sticker).toList();
    if (packs.isEmpty) return const _Message('No sticker packs installed.');
    final pack = packs.first;
    final groups = pack.categories;
    final items = catalog.search(
      _query,
      packId: pack.id,
      category: _query.isEmpty ? (_stickerGroup ?? groups.first) : null,
      limit: 2000,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Space.xs),
        if (_query.isEmpty)
          FilterChipRow<String>(
            options: [for (final g in groups) (g, g)],
            selected: _stickerGroup ?? groups.first,
            onSelected: (g) => setState(() => _stickerGroup = g),
          ),
        const SizedBox(height: Space.sm),
        Expanded(
          child:
              items.isEmpty
                  ? _Message('No stickers match "$_query".')
                  : AssetGrid(
                    items: items,
                    recolorable: (_) => false,
                    tile: 52,
                  ),
        ),
        _LicenseFooter(pack: pack),
      ],
    );
  }
}

/// Licence and credit line of the pack being browsed (P2.1.4).
class _LicenseFooter extends StatelessWidget {
  const _LicenseFooter({required this.pack});

  final AssetPack pack;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final license = pack.license;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.all(Space.md),
      child: Text(
        license.attributionRequired
            ? '${license.attribution}.'
            : '${pack.name} ${pack.version} · ${license.spdx} · '
                '${license.author}',
        style: OcxText.caption(
          context,
        ).copyWith(color: c.textTertiary, fontWeight: FontWeight.w400),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Space.md),
    child: Text(
      text,
      style: OcxText.caption(
        context,
      ).copyWith(color: context.ocx.textTertiary, fontWeight: FontWeight.w400),
    ),
  );
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
