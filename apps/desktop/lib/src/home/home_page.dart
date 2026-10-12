import 'dart:math' as math;

import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:renderer/renderer.dart';

import '../library/design_library.dart';
import '../providers.dart';
import '../theme/ocx_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/controls.dart';
import '../widgets/formatting.dart';
import 'create_design_dialog.dart';
import 'open_design.dart';
import 'preset_frame.dart';

enum _Section { home, all }

/// Presets on the home row, most common first.
const _quickPresetIds = [
  'instagram_post',
  'instagram_story',
  'presentation_16_9',
  'youtube_thumbnail',
  'a4',
  'business_card',
];

/// Home (design-system.md §5 "Home"): start a design or reopen one.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  _Section _section = _Section.home;
  String _query = '';

  Future<void> _create({PagePreset? preset, bool custom = false}) async {
    final request = await showCreateDesignDialog(
      context,
      initial: preset,
      customSize: custom,
    );
    if (request == null || !mounted) return;
    await createDesign(context, ref, title: request.title, page: request.page);
  }

  Future<void> _quickCreate(PagePreset preset) => createDesign(
    context,
    ref,
    title: 'Untitled ${preset.name.toLowerCase()}',
    page: preset.createPage(PageId.generate()),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            section: _section,
            onSection: (s) => setState(() => _section = s),
            onCreate: _create,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _content(context)),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    final designs = ref.watch(designsProvider);
    final folderProblem = ref.watch(projectsFolderStatusProvider).asData?.value;
    final c = context.ocx;

    final header = Row(
      children: [
        Expanded(
          child: Text(
            _section == _Section.home ? 'Home' : 'All designs',
            style: OcxText.display(context),
          ),
        ),
        SizedBox(
          width: 260,
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            style: OcxText.body(context),
            decoration: const InputDecoration(
              hintText: 'Search designs',
              prefixIcon: Icon(Icons.search, size: Chrome.icon),
              prefixIconConstraints: BoxConstraints(minWidth: 28),
            ),
          ),
        ),
      ],
    );

    final list = designs.asData?.value ?? const <DesignSummary>[];
    final shown =
        _query.isEmpty
            ? list
            : list
                .where(
                  (d) => d.title.toLowerCase().contains(_query.toLowerCase()),
                )
                .toList();

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Space.xxl,
                Space.xxl,
                Space.xxl,
                0,
              ),
              sliver: SliverList.list(
                children: [
                  header,
                  if (folderProblem != null) ...[
                    const SizedBox(height: Space.lg),
                    _Notice(
                      message:
                          '${describeFolderProblem(folderProblem)} Choose another '
                          'folder to see your designs.',
                      action: TextButton(
                        onPressed:
                            () =>
                                ref
                                    .read(projectsFolderProvider.notifier)
                                    .choose(),
                        child: const Text('Choose folder'),
                      ),
                    ),
                  ],
                  if (_section == _Section.home) ...[
                    const SizedBox(height: Space.xl),
                    _SectionTitle(
                      title: 'Start a design',
                      action: TextButton(
                        onPressed: _create,
                        child: const Text('More sizes'),
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    _PresetRow(
                      onPreset: _quickCreate,
                      onCustom: () => _create(custom: true),
                    ),
                  ],
                  const SizedBox(height: Space.xl),
                  _SectionTitle(
                    title:
                        _section == _Section.home
                            ? 'Recent designs'
                            : 'Designs in your folder',
                    count: designs.asData?.value.length,
                    action: OcxIconButton(
                      icon: Icons.refresh,
                      tooltip: 'Refresh',
                      onPressed: () => ref.invalidate(designsProvider),
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                ],
              ),
            ),
            if (designs.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(Space.xxxl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (designs.hasError)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
                sliver: SliverToBoxAdapter(
                  child: _Notice(
                    message: 'Could not list your designs. ${designs.error}',
                  ),
                ),
              )
            else if (list.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
                sliver: SliverToBoxAdapter(
                  child: _EmptyDesigns(onCreate: _create),
                ),
              )
            else if (shown.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(Space.xxl),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'No designs match "$_query".',
                    style: OcxText.body(
                      context,
                    ).copyWith(color: c.textSecondary),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisSpacing: Space.lg,
                    crossAxisSpacing: Space.lg,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: shown.length,
                  itemBuilder:
                      (context, i) => _DesignCard(
                        summary: shown[i],
                        onOpen: () => openDesign(context, ref, shown[i].path),
                      ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.xxxl)),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- sidebar

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.section,
    required this.onSection,
    required this.onCreate,
  });

  final _Section section;
  final ValueChanged<_Section> onSection;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Chrome.homeSidebar,
      color: context.ocx.surface,
      padding: const EdgeInsets.all(Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            height: 40,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: Space.xs),
                child: BrandLockup(),
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create design'),
          ),
          const SizedBox(height: Space.md),
          _NavItem(
            icon: Icons.home_outlined,
            label: 'Home',
            selected: section == _Section.home,
            onTap: () => onSection(_Section.home),
          ),
          _NavItem(
            icon: Icons.grid_view_outlined,
            label: 'All designs',
            selected: section == _Section.all,
            onTap: () => onSection(_Section.all),
          ),
          const Spacer(),
          const _StorageStatus(),
          const SizedBox(height: Space.sm),
          const _ThemeSwitch(),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final color = selected ? c.accent : c.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? c.accentSubtle : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: SizedBox(
            height: Chrome.button,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.sm),
              child: Row(
                children: [
                  Icon(icon, size: Chrome.icon, color: color),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (selected
                              ? OcxText.bodyStrong(context)
                              : OcxText.body(context))
                          .copyWith(color: color),
                    ),
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

class _StorageStatus extends ConsumerWidget {
  const _StorageStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ocx;
    final folder = ref.watch(projectsFolderProvider) ?? '';
    return Container(
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, size: 14, color: c.success),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  'Saved on this computer',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OcxText.caption(context).copyWith(color: c.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Tooltip(
            message: folder,
            child: Text(
              shortenPath(folder, maxLength: 30),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OcxText.caption(
                context,
              ).copyWith(color: c.textTertiary, fontWeight: FontWeight.w400),
            ),
          ),
          const SizedBox(height: Space.xs),
          InkWell(
            onTap: () async {
              final problem =
                  await ref.read(projectsFolderProvider.notifier).choose();
              if (problem != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(describeFolderProblem(problem))),
                );
              }
            },
            child: Text(
              'Change folder',
              style: OcxText.caption(context).copyWith(color: c.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeSwitch extends ConsumerWidget {
  const _ThemeSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) => OcxSegmented<ThemeMode>(
    value: ref.watch(themeModeProvider),
    segments: const [
      Segment(ThemeMode.light, Icons.light_mode_outlined, 'Light theme'),
      Segment(ThemeMode.system, Icons.brightness_auto_outlined, 'Match system'),
      Segment(ThemeMode.dark, Icons.dark_mode_outlined, 'Dark theme'),
    ],
    onChanged: ref.read(themeModeProvider.notifier).set,
  );
}

// ------------------------------------------------------------------ content

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.count, this.action});

  final String title;
  final int? count;
  final Widget? action;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: Chrome.button,
    child: Row(
      children: [
        Text(title, style: OcxText.title(context)),
        if (count != null) ...[
          const SizedBox(width: Space.sm),
          Text(
            '$count',
            style: OcxText.caption(
              context,
            ).copyWith(color: context.ocx.textTertiary),
          ),
        ],
        const Spacer(),
        if (action case final widget?) widget,
      ],
    ),
  );
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({required this.onPreset, required this.onCustom});

  final ValueChanged<PagePreset> onPreset;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final presets = [
      for (final id in _quickPresetIds)
        if (presetById(id) case final preset?) preset,
    ];
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final preset in presets)
            _PresetCard(
              title: preset.name,
              subtitle: preset.sizeLabel,
              frame: PresetFrame(
                width: preset.width,
                height: preset.height,
                category: preset.category,
              ),
              onTap: () => onPreset(preset),
            ),
          _PresetCard(
            title: 'Custom size',
            subtitle: 'Any size or unit',
            frame: const PresetFrame(width: 1, height: 1, category: null),
            onTap: onCustom,
          ),
        ],
      ),
    );
  }
}

/// Card with hover state shared by presets and designs.
class _HoverCard extends StatefulWidget {
  const _HoverCard({required this.onTap, required this.child, this.width});

  final VoidCallback onTap;
  final Widget child;
  final double? width;

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: widget.width,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: _hover ? c.borderStrong : c.border),
            boxShadow:
                _hover
                    ? const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ]
                    : const [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.title,
    required this.subtitle,
    required this.frame,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget frame;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: Space.md),
    child: _HoverCard(
      width: 132,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(Space.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.ocx.surfaceSunken,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Center(child: frame),
              ),
            ),
            const SizedBox(height: Space.sm),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OcxText.bodyStrong(context),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OcxText.caption(context).copyWith(
                fontWeight: FontWeight.w400,
                color: context.ocx.textTertiary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DesignCard extends StatelessWidget {
  const _DesignCard({required this.summary, required this.onOpen});

  final DesignSummary summary;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final cover = summary.cover;
    final meta = OcxText.caption(
      context,
    ).copyWith(fontWeight: FontWeight.w400, color: c.textTertiary);
    return _HoverCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(Space.sm),
              padding: const EdgeInsets.all(Space.md),
              decoration: BoxDecoration(
                color: c.surfaceSunken,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Center(
                child:
                    cover == null
                        ? _UnreadableCover(error: summary.error)
                        : AspectRatio(
                          aspectRatio: math.max(
                            cover.width / cover.height,
                            0.2,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(color: c.pageShadow, blurRadius: 6),
                              ],
                            ),
                            child: CustomPaint(
                              painter: PageThumbnailPainter(
                                document: summary.document!,
                                page: cover,
                              ),
                            ),
                          ),
                        ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OcxText.bodyStrong(context),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cover == null
                            ? ''
                            : sizeLabel(
                                  cover.width,
                                  cover.height,
                                  cover.unit.symbol,
                                ) +
                                (summary.pageCount > 1
                                    ? ' · ${summary.pageCount} pages'
                                    : ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: meta,
                      ),
                    ),
                    Tooltip(
                      message: 'Last edited',
                      child: Text(relativeTime(summary.modified), style: meta),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreadableCover extends StatelessWidget {
  const _UnreadableCover({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: error ?? '',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.broken_image_outlined,
          size: 20,
          color: context.ocx.textTertiary,
        ),
        const SizedBox(height: Space.xs),
        Text("Can't read this file", style: OcxText.caption(context)),
      ],
    ),
  );
}

class _EmptyDesigns extends StatelessWidget {
  const _EmptyDesigns({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: Space.xxl,
        horizontal: Space.xl,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
        color: c.surface,
      ),
      child: Column(
        children: [
          Icon(Icons.draw_outlined, size: 32, color: c.textTertiary),
          const SizedBox(height: Space.md),
          Text('No designs yet', style: OcxText.title(context)),
          const SizedBox(height: Space.xs),
          Text(
            'Choose a size above to start. Your designs will appear here.',
            style: OcxText.body(context).copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Space.lg),
          FilledButton(
            onPressed: onCreate,
            child: const Text('Create your first design'),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.sm,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: Chrome.icon,
            color: c.warning,
          ),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(message, style: OcxText.body(context))),
          if (action case final widget?) widget,
        ],
      ),
    );
  }
}
