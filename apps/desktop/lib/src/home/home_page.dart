import 'dart:math' as math;

import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:renderer/renderer.dart';

import '../library/design_library.dart';
import '../providers.dart';
import '../theme/ocx_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/formatting.dart';
import 'create_design_dialog.dart';
import 'open_design.dart';
import 'preset_frame.dart';

enum _HomeSection { home, designs }

/// Presets shown on the home strip, most common first.
const _quickPresetIds = [
  'instagram_post',
  'instagram_story',
  'presentation_16_9',
  'youtube_thumbnail',
  'a4',
  'a3_poster',
  'business_card',
];

/// Home: start a design from a size, or reopen one (Canva-style layout).
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  _HomeSection _section = _HomeSection.home;
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
    title: 'Untitled ${preset.name}',
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
          VerticalDivider(color: context.ocx.border),
          Expanded(child: _content(context)),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final designs = ref.watch(designsProvider);
    final folderProblem = ref.watch(projectsFolderStatusProvider).asData?.value;
    final count = designs.asData?.value.length;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            Space.xxl + 8,
            Space.xxl,
            Space.xxl + 8,
            0,
          ),
          sliver: SliverList.list(
            children: [
              if (_section == _HomeSection.home) ...[
                _Hero(onSearch: (q) => setState(() => _query = q)),
                const SizedBox(height: Space.xxl + 4),
                _SectionTitle(
                  title: 'Start something new',
                  action: TextButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('All sizes'),
                  ),
                ),
                const SizedBox(height: Space.md),
                _PresetStrip(
                  onPreset: _quickCreate,
                  onCustom: () => _create(custom: true),
                ),
                const SizedBox(height: Space.xxl + 8),
              ] else ...[
                Text('Your designs', style: theme.textTheme.headlineMedium),
                const SizedBox(height: Space.lg),
                SizedBox(
                  width: 420,
                  child: _SearchField(
                    onChanged: (q) => setState(() => _query = q),
                    onSurface: true,
                  ),
                ),
                const SizedBox(height: Space.xl),
              ],
              _SectionTitle(
                title:
                    _section == _HomeSection.home
                        ? 'Your designs'
                        : 'All designs',
                count: count,
                action: IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Refresh',
                  onPressed: () => ref.invalidate(designsProvider),
                ),
              ),
              const SizedBox(height: Space.md),
              if (folderProblem != null) ...[
                _Notice(
                  message:
                      '${describeFolderProblem(folderProblem)} '
                      'Choose a projects folder to see your designs.',
                  action: TextButton(
                    onPressed:
                        () =>
                            ref.read(projectsFolderProvider.notifier).choose(),
                    child: const Text('Choose folder'),
                  ),
                ),
                const SizedBox(height: Space.lg),
              ],
            ],
          ),
        ),
        ...designs.when(
          data: (all) {
            final shown =
                _query.isEmpty
                    ? all
                    : all
                        .where(
                          (d) => d.title.toLowerCase().contains(
                            _query.toLowerCase(),
                          ),
                        )
                        .toList();
            if (all.isEmpty) {
              return [
                SliverToBoxAdapter(child: _EmptyDesigns(onCreate: _create)),
              ];
            }
            if (shown.isEmpty) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.xxxl),
                    child: Text(
                      'No designs match "$_query".',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ];
            }
            return [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Space.xxl + 8),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 270,
                    mainAxisSpacing: Space.xl,
                    crossAxisSpacing: Space.xl,
                    childAspectRatio: 0.98,
                  ),
                  itemCount: shown.length,
                  itemBuilder:
                      (context, i) => _DesignCard(
                        summary: shown[i],
                        onOpen: () => openDesign(context, ref, shown[i].path),
                      ),
                ),
              ),
            ];
          },
          loading:
              () => [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(Space.xxxl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
          error:
              (error, _) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.xxl + 8,
                    ),
                    child: _Notice(
                      message: 'Could not list your designs. $error',
                    ),
                  ),
                ),
              ],
        ),
        const SliverToBoxAdapter(child: SizedBox(height: Space.xxxl)),
      ],
    );
  }
}

// ----------------------------------------------------------------- sidebar

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.section,
    required this.onSection,
    required this.onCreate,
  });

  final _HomeSection section;
  final ValueChanged<_HomeSection> onSection;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ocx = context.ocx;
    return Container(
      width: Chrome.homeSidebarWidth,
      color: ocx.panel,
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.xl,
        Space.lg,
        Space.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Space.xs),
            child: BrandLockup(),
          ),
          const SizedBox(height: Space.xxl),
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create a design'),
            ),
          ),
          const SizedBox(height: Space.xl),
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            selected: section == _HomeSection.home,
            onTap: () => onSection(_HomeSection.home),
          ),
          _NavItem(
            icon: Icons.grid_view_rounded,
            label: 'Your designs',
            selected: section == _HomeSection.designs,
            onTap: () => onSection(_HomeSection.designs),
          ),
          const Spacer(),
          const _StorageCard(),
          const SizedBox(height: Space.md),
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
    final theme = Theme.of(context);
    final ocx = context.ocx;
    final color =
        selected ? theme.colorScheme.primary : theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Material(
        color: selected ? ocx.selectedFill : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: 11,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(color: color),
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

class _StorageCard extends ConsumerWidget {
  const _StorageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ocx = context.ocx;
    final folder = ref.watch(projectsFolderProvider) ?? '';
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: ocx.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: ocx.success),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  'Saved on this computer',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Tooltip(
            message: folder,
            child: Text(
              shortenPath(folder, maxLength: 34),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: Space.xs),
          TextButton(
            onPressed: () async {
              final problem =
                  await ref.read(projectsFolderProvider.notifier).choose();
              if (problem != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(describeFolderProblem(problem))),
                );
              }
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Change folder'),
          ),
        ],
      ),
    );
  }
}

class _ThemeSwitch extends ConsumerWidget {
  const _ThemeSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode_outlined, size: 18),
          tooltip: 'Light',
        ),
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto_outlined, size: 18),
          tooltip: 'Match system',
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode_outlined, size: 18),
          tooltip: 'Dark',
        ),
      ],
      selected: {mode},
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      onSelectionChanged:
          (s) => ref.read(themeModeProvider.notifier).set(s.single),
    );
  }
}

// -------------------------------------------------------------------- hero

class _Hero extends StatelessWidget {
  const _Hero({required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.xl),
      child: Container(
        height: 228,
        decoration: const BoxDecoration(gradient: Brand.heroGradient),
        child: Stack(
          children: [
            const Positioned(
              right: -40,
              top: -50,
              child: _Blob(size: 220, alpha: 0.12),
            ),
            const Positioned(
              right: 140,
              bottom: -70,
              child: _Blob(size: 160, alpha: 0.09),
            ),
            Positioned(
              right: 70,
              top: 46,
              child: Transform.rotate(angle: -0.18, child: const _MiniDesign()),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.xxl + 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'What will you design today?',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    'Everything stays on this computer — no account, no uploads.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  SizedBox(
                    width: 460,
                    child: _SearchField(onChanged: onSearch),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
}

/// Decorative miniature "design" card in the hero.
class _MiniDesign extends StatelessWidget {
  const _MiniDesign();

  @override
  Widget build(BuildContext context) => Container(
    width: 150,
    height: 112,
    padding: const EdgeInsets.all(Space.md),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(Radii.md),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: Color(0xFFFFB547),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Container(
                height: 30,
                decoration: BoxDecoration(
                  color: Brand.violet.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        for (final w in const [110.0, 80.0, 96.0])
          Container(
            width: w,
            height: 7,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE3E6ED),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    ),
  );
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged, this.onSurface = false});

  final ValueChanged<String> onChanged;

  /// Normal panel styling instead of the white-on-gradient hero look.
  final bool onSurface;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.pill),
      borderSide:
          onSurface ? BorderSide(color: context.ocx.border) : BorderSide.none,
    );
    return TextField(
      onChanged: (v) => onChanged(v.trim()),
      style: onSurface ? null : const TextStyle(color: Color(0xFF101828)),
      decoration: InputDecoration(
        hintText: 'Search your designs',
        hintStyle: onSurface ? null : const TextStyle(color: Color(0xFF667085)),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: onSurface ? null : const Color(0xFF667085),
        ),
        filled: true,
        fillColor: onSurface ? null : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: 14,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(
            color:
                onSurface
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white,
            width: 2,
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- presets

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.count, this.action});

  final String title;
  final int? count;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        if (count != null) ...[
          const SizedBox(width: Space.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: context.ocx.selectedFill,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (action case final widget?) widget,
      ],
    );
  }
}

class _PresetStrip extends StatelessWidget {
  const _PresetStrip({required this.onPreset, required this.onCustom});

  final ValueChanged<PagePreset> onPreset;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final presets = [
      for (final id in _quickPresetIds)
        if (presetById(id) case final preset?) preset,
    ];
    return SizedBox(
      height: 164,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final preset in presets)
            _PresetTile(
              title: preset.name,
              subtitle: preset.sizeLabel,
              frame: PresetFrame(
                width: preset.width,
                height: preset.height,
                category: preset.category,
              ),
              onTap: () => onPreset(preset),
            ),
          _PresetTile(
            title: 'Custom size',
            subtitle: 'Any width and height',
            frame: const PresetFrame(width: 1, height: 1, category: null),
            onTap: onCustom,
          ),
        ],
      ),
    );
  }
}

class _PresetTile extends StatefulWidget {
  const _PresetTile({
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
  State<_PresetTile> createState() => _PresetTileState();
}

class _PresetTileState extends State<_PresetTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ocx = context.ocx;
    return Padding(
      padding: const EdgeInsets.only(right: Space.md),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: 150,
            transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(
                color:
                    _hover ? ocx.selection.withValues(alpha: 0.6) : ocx.border,
              ),
              boxShadow:
                  _hover
                      ? [
                        BoxShadow(
                          color: ocx.pageShadow,
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                      : const [],
            ),
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    child: Center(child: widget.frame),
                  ),
                ),
                const SizedBox(height: Space.sm),
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
                Text(
                  widget.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ designs

class _DesignCard extends StatefulWidget {
  const _DesignCard({required this.summary, required this.onOpen});

  final DesignSummary summary;
  final VoidCallback onOpen;

  @override
  State<_DesignCard> createState() => _DesignCardState();
}

class _DesignCardState extends State<_DesignCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ocx = context.ocx;
    final summary = widget.summary;
    final cover = summary.cover;
    final size =
        cover == null
            ? ''
            : sizeLabel(cover.width, cover.height, cover.unit.symbol);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(
              color: _hover ? ocx.selection.withValues(alpha: 0.6) : ocx.border,
            ),
            boxShadow:
                _hover
                    ? [
                      BoxShadow(
                        color: ocx.pageShadow,
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                    : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(Space.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  padding: const EdgeInsets.all(Space.lg),
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
                                    BoxShadow(
                                      color: ocx.pageShadow,
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
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
                padding: const EdgeInsets.fromLTRB(
                  Space.md + 2,
                  Space.xs,
                  Space.md,
                  Space.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            summary.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if (summary.pageCount > 1)
                          Tooltip(
                            message: '${summary.pageCount} pages',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome_motion_outlined,
                                  size: 14,
                                  color: ocx.subtleText,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${summary.pageCount}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            size,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Tooltip(
                          message: 'Last edited',
                          child: Text(
                            relativeTime(summary.modified),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
          size: 32,
          color: context.ocx.subtleText,
        ),
        const SizedBox(height: Space.sm),
        Text(
          "Can't read this file",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _EmptyDesigns extends StatelessWidget {
  const _EmptyDesigns({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ocx = context.ocx;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xxl + 8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: Space.xxxl,
          horizontal: Space.xl,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.xl),
          border: Border.all(color: ocx.border),
          color: theme.colorScheme.surface,
        ),
        child: Column(
          children: [
            const SizedBox(
              width: 120,
              height: 84,
              child: Stack(
                children: [
                  Positioned(
                    left: 8,
                    top: 14,
                    child: _EmptyShape(color: Color(0xFFFFB547), circle: true),
                  ),
                  Positioned(
                    left: 40,
                    top: 0,
                    child: _EmptyShape(color: Brand.violet),
                  ),
                  Positioned(
                    left: 70,
                    top: 30,
                    child: _EmptyShape(color: Brand.teal, circle: true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.lg),
            Text('No designs yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: Space.xs),
            Text(
              'Pick a size above or create a design — it will appear here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ocx.subtleText,
              ),
            ),
            const SizedBox(height: Space.xl),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create your first design'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyShape extends StatelessWidget {
  const _EmptyShape({required this.color, this.circle = false});

  final Color color;
  final bool circle;

  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.9),
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(12),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md,
      ),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
          if (action case final widget?) widget,
        ],
      ),
    );
  }
}
