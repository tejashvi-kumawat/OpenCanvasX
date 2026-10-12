import 'dart:convert';
import 'dart:io';

import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:renderer/renderer.dart';
import 'package:storage/storage.dart';
import 'package:template_engine/template_engine.dart';

import '../providers.dart';
import '../theme/ocx_theme.dart';

/// Called when the user picks a template and its contents are ready.
typedef UseTemplate =
    void Function(TemplateInfo info, ProjectContents contents);

// ------------------------------------------------------------ repositories

/// The official templates folder: `templates/official` next to the app,
/// or — when running from a source checkout — in the repository root.
String? discoverOfficialTemplates() {
  final exe = File(Platform.resolvedExecutable).parent;
  final sep = Platform.pathSeparator;
  var dir = exe;
  for (var i = 0; i < 9; i++) {
    final candidate = '${dir.path}${sep}templates${sep}official';
    if (File('$candidate${sep}index.json').existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

/// Where downloaded templates are cached.
final templateCacheDirProvider = FutureProvider<String>((ref) async {
  final support = await getApplicationSupportDirectory();
  return '${support.path}${Platform.pathSeparator}template-cache';
});

/// Built-in template sources (official folder, the projects folder's
/// `Templates`); tests replace it.
final defaultTemplateRepositoriesProvider = Provider<List<TemplateRepository>>((
  ref,
) {
  final official = discoverOfficialTemplates();
  final projects = ref.watch(projectsFolderProvider);
  final mine =
      projects == null ? null : '$projects${Platform.pathSeparator}Templates';
  return [
    if (official != null)
      FolderTemplateRepository(official, label: 'OpenCanvasX'),
    if (mine != null && Directory(mine).existsSync())
      FolderTemplateRepository(mine, label: 'My templates'),
  ];
});

/// Template repositories the user added (P6.2.2): folders and index URLs,
/// stored in the app index.
final templateSourcesProvider =
    NotifierProvider<TemplateSourcesController, List<TemplateRepository>>(
      TemplateSourcesController.new,
    );

class TemplateSourcesController extends Notifier<List<TemplateRepository>> {
  static const _key = 'templates.sources';

  @override
  List<TemplateRepository> build() {
    final cache = ref.watch(templateCacheDirProvider).value ?? '';
    final raw = ref.watch(appIndexProvider).settings.get(_key);
    final list = raw == null ? const <Object?>[] : jsonDecode(raw) as List;
    return [
      for (final item in list.whereType<Map<String, Object?>>())
        if (item['type'] == 'folder' && item['path'] is String)
          FolderTemplateRepository(item['path']! as String)
        else if (item['type'] == 'url' && item['url'] is String)
          HttpTemplateRepository(item['url']! as String, cacheDir: cache),
    ];
  }

  void _save(List<TemplateRepository> next) {
    ref
        .read(appIndexProvider)
        .settings
        .set(
          _key,
          jsonEncode([
            for (final r in next)
              switch (r) {
                FolderTemplateRepository(:final path) => {
                  'type': 'folder',
                  'path': path,
                },
                HttpTemplateRepository(:final indexUrl) => {
                  'type': 'url',
                  'url': indexUrl,
                },
              },
          ]),
        );
    ref.invalidateSelf();
  }

  void addFolder(String path) {
    if (state.any((r) => r.key == path)) return;
    _save([...state, FolderTemplateRepository(path)]);
  }

  /// Adds an index URL and downloads its index (user-initiated).
  Future<void> addUrl(String url) async {
    final trimmed = url.trim();
    if (state.any((r) => r.key == trimmed)) return;
    final cache = await ref.read(templateCacheDirProvider.future);
    final repo = HttpTemplateRepository(trimmed, cacheDir: cache);
    await repo.refresh();
    _save([...state, repo]);
  }

  void remove(TemplateRepository repo) => _save([
    for (final r in state)
      if (r.key != repo.key) r,
  ]);
}

/// Every template from every source, in source order. Sources that fail
/// are skipped so one broken source cannot hide the others.
final templatesProvider = FutureProvider<List<TemplateEntry>>((ref) async {
  final repos = [
    ...ref.watch(defaultTemplateRepositoriesProvider),
    ...ref.watch(templateSourcesProvider),
  ];
  final entries = <TemplateEntry>[];
  final seen = <String>{};
  for (final repo in repos) {
    try {
      for (final entry in await repo.list()) {
        if (seen.add('${repo.key}#${entry.info.id}')) entries.add(entry);
      }
    } on Object {
      // A broken source must not hide the others.
    }
  }
  return entries;
});

/// Decoded images of templates, for thumbnails.
final templateMediaProvider = Provider<MediaCache>((ref) {
  final cache = MediaCache();
  ref.onDispose(cache.dispose);
  return cache;
});

/// A template's design and asset bytes, fetched (downloaded if remote),
/// checksum-verified, decoded and validated (P2.2.5). Only requested for
/// cards on screen or when used.
final templateContentsProvider =
    FutureProvider.family<ProjectContents, TemplateEntry>((ref, entry) async {
      final bytes = await entry.repository.fetch(entry.info);
      final contents = decodeProject(bytes);
      final issues = validateTemplate(contents.document);
      if (issues.isNotEmpty) {
        throw FormatException(
          'Template "${entry.info.name}" is invalid',
          issues,
        );
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

/// Whether [entry] can be shown without downloading.
bool isLocal(TemplateEntry entry) => switch (entry.repository) {
  FolderTemplateRepository() => true,
  final HttpTemplateRepository r => r.isCached(entry.info),
};

/// Templates matching [query] and [category].
List<TemplateEntry> filterTemplates(
  List<TemplateEntry> all, {
  String query = '',
  String? category,
}) => [
  for (final e in all)
    if ((category == null || e.info.category == category) &&
        e.info.matches(query))
      e,
];

// ----------------------------------------------------------------- widgets

/// Category chips ("All", then categories present in [entries]).
class TemplateCategoryChips extends StatelessWidget {
  const TemplateCategoryChips({
    required this.entries,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<TemplateEntry> entries;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final categories = [
      for (final key in templateCategories.keys)
        if (entries.any((e) => e.info.category == key)) key,
    ];
    return Wrap(
      spacing: Space.xs,
      runSpacing: Space.xs,
      children: [
        _Chip(
          label: 'All',
          selected: selected == null,
          onTap: () => onSelected(null),
        ),
        for (final key in categories)
          _Chip(
            label: templateCategories[key]!,
            selected: selected == key,
            onTap: () => onSelected(key),
          ),
      ],
    );
  }
}

/// A lazily built grid of template cards (only visible cards load their
/// file).
class SliverTemplateGrid extends StatelessWidget {
  const SliverTemplateGrid({
    required this.entries,
    required this.onUse,
    this.columns,
    this.tileWidth = 200,
    super.key,
  });

  final List<TemplateEntry> entries;
  final UseTemplate onUse;
  final int? columns;
  final double tileWidth;

  @override
  Widget build(BuildContext context) => SliverGrid.builder(
    gridDelegate:
        columns != null
            ? SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns!,
              mainAxisSpacing: Space.md,
              crossAxisSpacing: Space.md,
              childAspectRatio: 0.8,
            )
            : SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: tileWidth,
              mainAxisSpacing: Space.lg,
              crossAxisSpacing: Space.lg,
              childAspectRatio: 0.82,
            ),
    itemCount: entries.length,
    itemBuilder:
        (context, i) => TemplateCard(
          key: ValueKey('${entries[i].repository.key}#${entries[i].info.id}'),
          entry: entries[i],
          onUse: onUse,
        ),
  );
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

/// One template: live thumbnail (local templates) or a download badge
/// (remote ones not yet downloaded); click uses it.
class TemplateCard extends ConsumerStatefulWidget {
  const TemplateCard({required this.entry, required this.onUse, super.key});

  final TemplateEntry entry;
  final UseTemplate onUse;

  @override
  ConsumerState<TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends ConsumerState<TemplateCard> {
  bool _hover = false;
  bool _requested = false;

  Future<void> _use() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _requested = true);
    try {
      final contents = await ref.read(
        templateContentsProvider(widget.entry).future,
      );
      if (mounted) widget.onUse(widget.entry.info, contents);
    } on Object catch (e) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Could not open "${widget.entry.info.name}": $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final info = widget.entry.info;
    final local = isLocal(widget.entry) || _requested;
    final contents =
        local ? ref.watch(templateContentsProvider(widget.entry)) : null;
    final media = ref.watch(templateMediaProvider);
    final size =
        info.board
            ? 'Board'
            : '${_fmt(info.width)} × ${_fmt(info.height)} ${info.unit}'
                '${info.pages > 1 ? ' · ${info.pages} pages' : ''}';
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _use,
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
                  null => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_download_outlined,
                          size: 20,
                          color: c.textTertiary,
                        ),
                        const SizedBox(height: Space.xs),
                        Text(
                          widget.entry.repository.label,
                          style: OcxText.caption(
                            context,
                          ).copyWith(color: c.textTertiary),
                        ),
                      ],
                    ),
                  ),
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

/// Button that opens [showTemplateSources].
class TemplateSourcesButton extends StatelessWidget {
  const TemplateSourcesButton({super.key});

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => showTemplateSources(context),
    icon: const Icon(Icons.source_outlined, size: Chrome.icon),
    label: const Text('Sources'),
  );
}

/// Manage template sources (P6.2.2): built-in folders, folders and index
/// URLs the user added. Downloads only happen from here or when a remote
/// template is used.
Future<void> showTemplateSources(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _SourcesDialog());

class _SourcesDialog extends ConsumerStatefulWidget {
  const _SourcesDialog();

  @override
  ConsumerState<_SourcesDialog> createState() => _SourcesDialogState();
}

class _SourcesDialogState extends ConsumerState<_SourcesDialog> {
  final TextEditingController _url = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _addUrl() async {
    final url = _url.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(templateSourcesProvider.notifier).addUrl(url);
      _url.clear();
      ref.invalidate(templatesProvider);
    } on Object catch (e) {
      setState(() => _error = 'Could not add this repository: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addFolder() async {
    final path = await ref.read(folderPickerProvider)();
    if (path == null) return;
    ref.read(templateSourcesProvider.notifier).addFolder(path);
    ref.invalidate(templatesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final builtIn = ref.watch(defaultTemplateRepositoriesProvider);
    final added = ref.watch(templateSourcesProvider);
    Widget row(TemplateRepository r, {required bool removable}) => ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        r is HttpTemplateRepository ? Icons.public : Icons.folder_outlined,
        size: 18,
        color: c.textSecondary,
      ),
      title: Text(r.label, style: OcxText.bodyStrong(context)),
      subtitle: Text(
        r.key,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: OcxText.caption(context).copyWith(color: c.textTertiary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (r is HttpTemplateRepository)
            IconButton(
              tooltip: 'Check for new templates',
              iconSize: Chrome.icon,
              onPressed: () async {
                await r.refresh();
                ref.invalidate(templatesProvider);
              },
              icon: const Icon(Icons.refresh),
            ),
          if (removable)
            IconButton(
              tooltip: 'Remove source',
              iconSize: Chrome.icon,
              onPressed: () {
                ref.read(templateSourcesProvider.notifier).remove(r);
                ref.invalidate(templatesProvider);
              },
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Template sources', style: OcxText.heading(context)),
              const SizedBox(height: Space.sm),
              Text(
                'Templates are read from folders and repositories. A '
                'repository is a folder or web address with an index.json '
                '(see docs/architecture/template-architecture.md). Web '
                'repositories are only contacted when you add or refresh '
                'them, or use one of their templates.',
                style: OcxText.caption(
                  context,
                ).copyWith(color: c.textSecondary, fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: Space.md),
              for (final r in builtIn) row(r, removable: false),
              for (final r in added) row(r, removable: true),
              if (builtIn.isEmpty && added.isEmpty)
                Text(
                  'No sources yet.',
                  style: OcxText.body(context).copyWith(color: c.textTertiary),
                ),
              const Divider(height: Space.xl),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _url,
                      style: OcxText.body(context),
                      onSubmitted: (_) => _addUrl(),
                      decoration: const InputDecoration(
                        hintText: 'https://…/index.json',
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  FilledButton(
                    onPressed: _busy ? null : _addUrl,
                    child: const Text('Add URL'),
                  ),
                ],
              ),
              if (_error case final error?) ...[
                const SizedBox(height: Space.sm),
                Text(
                  error,
                  style: OcxText.caption(context).copyWith(color: c.danger),
                ),
              ],
              const SizedBox(height: Space.md),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _addFolder,
                    icon: const Icon(
                      Icons.create_new_folder_outlined,
                      size: 16,
                    ),
                    label: const Text('Add folder'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
