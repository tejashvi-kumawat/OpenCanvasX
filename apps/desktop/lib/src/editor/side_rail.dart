import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:template_engine/template_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/preset_frame.dart';
import '../plugins/apps_panel.dart';
import '../templates/template_gallery.dart';
import '../theme/ocx_theme.dart';
import 'editor_controller.dart';
import 'left_panel.dart';
import 'panels/asset_tiles.dart';
import 'panels/elements_panel.dart';
import 'panels/pages_panel.dart';
import 'panels/text_panel.dart';
import 'panels/uploads_panel.dart';

/// Content rail entries (design-system.md §5 "Editor", ux-spec.md §74
/// "Left").
enum RailTab {
  templates('Design', Icons.space_dashboard_outlined),
  elements('Elements', Icons.category_outlined),
  text('Text', Icons.text_fields),
  uploads('Uploads', Icons.cloud_upload_outlined),
  layers('Layers', Icons.layers_outlined),
  pages('Pages', Icons.auto_awesome_motion_outlined),
  apps('Apps', Icons.extension_outlined);

  const RailTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The open rail panel, or `null` when the panel is collapsed.
final railTabProvider = NotifierProvider<RailTabController, RailTab?>(
  RailTabController.new,
);

class RailTabController extends Notifier<RailTab?> {
  @override
  RailTab? build() => RailTab.elements;

  RailTab? get tab => state;

  /// Opens [value]; choosing the open tab again collapses the panel.
  void toggle(RailTab value) => state = state == value ? null : value;

  set tab(RailTab? value) => state = value;
}

/// Width of the panel next to the rail.
const double railPanelWidth = 300;

/// Left side of the editor: a 72 px rail of content tabs and the panel of
/// the selected tab.
class SideRail extends ConsumerWidget {
  const SideRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(railTabProvider);
    final c = context.ocx;
    return Row(
      children: [
        Container(
          width: 72,
          color: c.surface,
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: Column(
            children: [
              for (final value in RailTab.values)
                _RailButton(
                  tab: value,
                  selected: tab == value,
                  onTap: () => ref.read(railTabProvider.notifier).toggle(value),
                ),
            ],
          ),
        ),
        if (tab != null) ...[
          VerticalDivider(width: 1, color: c.border),
          Container(
            width: railPanelWidth,
            color: c.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 44,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: Space.md,
                      right: Space.xs,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _title(tab),
                            style: OcxText.title(context),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Hide panel',
                          iconSize: Chrome.icon,
                          visualDensity: VisualDensity.compact,
                          onPressed:
                              () => ref
                                  .read(railTabProvider.notifier)
                                  .toggle(tab),
                          icon: const Icon(Icons.keyboard_double_arrow_left),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: c.border),
                Expanded(
                  child: switch (tab) {
                    RailTab.templates => const TemplatesPanel(),
                    RailTab.elements => const ElementsPanel(),
                    RailTab.text => const TextPanel(),
                    RailTab.uploads => const UploadsPanel(),
                    RailTab.layers => const LayersPanel(),
                    RailTab.pages => const PagesPanel(),
                    RailTab.apps => const AppsPanel(),
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _title(RailTab tab) => switch (tab) {
    RailTab.templates => 'Design',
    RailTab.elements => 'Elements',
    RailTab.text => 'Text',
    RailTab.uploads => 'Uploads',
    RailTab.layers => 'Layers',
    RailTab.pages => 'Pages',
    RailTab.apps => 'Apps',
  };
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final RailTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final color = selected ? c.accent : c.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: 2),
      child: Semantics(
        selected: selected,
        button: true,
        label: tab.label,
        child: Material(
          color: selected ? c.accentSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.md),
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tab.icon, size: 20, color: color),
                  const SizedBox(height: Space.xs),
                  Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: OcxText.caption(context).copyWith(
                      color: selected ? c.accent : c.textSecondary,
                      fontSize: 10.5,
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

/// Design: the template library (P2.2.3) and page or frame sizes. On a
/// board, templates and sizes arrive as frames; otherwise as new pages.
class TemplatesPanel extends ConsumerStatefulWidget {
  const TemplatesPanel({super.key});

  @override
  ConsumerState<TemplatesPanel> createState() => _TemplatesPanelState();
}

class _TemplatesPanelState extends ConsumerState<TemplatesPanel> {
  String _query = '';
  String? _category;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(editorProvider);
    final editor = ref.read(editorProvider.notifier);
    final c = context.ocx;
    final board = session?.activePage.isBoard ?? false;
    final presets = board ? framePresets : pagePresets;
    final all = ref.watch(templatesProvider).value ?? const <TemplateEntry>[];
    final shown = filterTemplates(all, query: _query, category: _category);
    return CustomScrollView(
      slivers: [
        SliverList.list(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.sm,
                Space.md,
                0,
              ),
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim()),
                style: OcxText.body(context),
                decoration: const InputDecoration(
                  hintText: 'Search templates',
                  prefixIcon: Icon(Icons.search, size: Chrome.icon),
                  prefixIconConstraints: BoxConstraints(minWidth: 28),
                ),
              ),
            ),
            const Row(
              children: [
                Expanded(child: SectionHeader(title: 'Templates')),
                Padding(
                  padding: EdgeInsets.only(right: Space.xs, top: Space.xs),
                  child: TemplateSourcesButton(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                0,
                Space.md,
                Space.md,
              ),
              child: TemplateCategoryChips(
                entries: all,
                selected: _category,
                onSelected: (v) => setState(() => _category = v),
              ),
            ),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: Text(
                  all.isEmpty
                      ? 'No template sources yet. Use Sources to add a '
                          'folder or repository.'
                      : 'No templates match "$_query".',
                  style: OcxText.caption(context).copyWith(
                    color: c.textTertiary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          sliver: SliverTemplateGrid(
            entries: shown,
            columns: 2,
            onUse: (_, contents) => editor.insertTemplate(contents),
          ),
        ),
        SliverList.list(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.md,
                Space.md,
                0,
              ),
              child: Text(
                board
                    ? 'Templates and sizes are added to this board as frames.'
                    : 'Templates are added as new pages after this one.',
                style: OcxText.caption(
                  context,
                ).copyWith(color: c.textTertiary, fontWeight: FontWeight.w400),
              ),
            ),
            for (final category in PresetCategory.values)
              if (presets.any((p) => p.category == category)) ...[
                SectionHeader(title: '${category.label}: blank'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.md),
                  child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: Space.sm,
                    crossAxisSpacing: Space.sm,
                    childAspectRatio: 0.82,
                    children: [
                      for (final p in presets)
                        if (p.category == category)
                          _PresetCard(
                            preset: p,
                            onTap:
                                () =>
                                    board
                                        ? editor.insertFrame(
                                          width: p.width,
                                          height: p.height,
                                          name: p.name,
                                        )
                                        : editor.addPageFromPreset(p),
                          ),
                    ],
                  ),
                ),
              ],
            const SizedBox(height: Space.xl),
          ],
        ),
      ],
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({required this.preset, required this.onTap});

  final PagePreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    return Tooltip(
      message: '${preset.name} · ${preset.sizeLabel}',
      child: Material(
        color: c.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.md),
          child: Padding(
            padding: const EdgeInsets.all(Space.sm),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: PresetFrame(
                      width: preset.width,
                      height: preset.height,
                      category: preset.category,
                      box: 40,
                    ),
                  ),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  preset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OcxText.caption(context).copyWith(color: c.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
