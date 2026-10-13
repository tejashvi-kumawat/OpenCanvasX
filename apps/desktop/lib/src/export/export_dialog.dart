import 'package:export_engine/export_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/editor_controller.dart';
import '../theme/ocx_theme.dart';
import 'exporter.dart';

/// Opens the export dialog for the open design (P1.9).
Future<void> showExportDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _ExportDialog());

class _ExportDialog extends ConsumerStatefulWidget {
  const _ExportDialog();

  @override
  ConsumerState<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<_ExportDialog> {
  ExportOptions _options = const ExportOptions();
  bool _busy = false;
  String? _error;
  (int, int)? _progress;

  @override
  void initState() {
    super.initState();
    final session = ref.read(editorProvider);
    if (session != null && session.selection.isNotEmpty) {
      _options = _options.copyWith(scope: ExportScope.selection);
    }
  }

  Future<void> _export() async {
    final session = ref.read(editorProvider);
    if (session == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final files = await buildExport(
        session.document,
        options: _options,
        activePage: session.state.activePageId,
        selection: session.selection,
        media: ref.read(mediaCacheProvider),
        onProgress: (done, total) {
          if (mounted) setState(() => _progress = (done, total));
        },
      );
      if (files.isEmpty) {
        setState(() => _error = 'There is nothing to export here.');
        return;
      }
      final where = await ref.read(exportSaverProvider)(files, _options.format);
      if (where == null) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            files.length == 1
                ? 'Exported to $where'
                : 'Exported ${files.length} files to $where',
          ),
        ),
      );
    } on Object catch (e) {
      setState(() => _error = 'Export failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(editorProvider);
    final c = context.ocx;
    if (session == null) return const SizedBox.shrink();
    final targets = exportTargets(
      session.document,
      scope: _options.scope,
      activePage: session.state.activePageId,
      selection: session.selection,
    );
    final format = _options.format;
    final first = targets.firstOrNull;
    final firstPage =
        first == null
            ? null
            : session.document.pages.firstWhere((p) => p.id == first.pageId);
    final pixels =
        first == null || firstPage == null
            ? null
            : exportPixelSize(firstPage, first, scale: _options.scale);
    final summary = switch (targets.length) {
      0 => 'Nothing to export',
      _ when format == ExportFormat.pdf =>
        '1 PDF · ${targets.length} page${targets.length == 1 ? '' : 's'}',
      _ when format == ExportFormat.html =>
        'Website · ${targets.length} HTML page${targets.length == 1 ? '' : 's'}',
      1 => '1 file · ${first!.name}',
      _ => '${targets.length} files',
    };

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Export', style: OcxText.heading(context)),
              const SizedBox(height: Space.lg),
              const _Label('File type'),
              SegmentedButton<ExportFormat>(
                showSelectedIcon: false,
                segments: [
                  for (final f in ExportFormat.values)
                    ButtonSegment(value: f, label: Text(f.label)),
                ],
                selected: {format},
                onSelectionChanged:
                    (v) => setState(
                      () => _options = _options.copyWith(format: v.single),
                    ),
              ),
              const SizedBox(height: Space.xs),
              Text(
                format.hint,
                style: OcxText.caption(
                  context,
                ).copyWith(color: c.textTertiary, fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: Space.lg),
              const _Label('What to export'),
              DropdownButtonFormField<ExportScope>(
                initialValue: _options.scope,
                items: [
                  DropdownMenuItem(
                    value: ExportScope.currentPage,
                    child: Text(
                      session.activePage.isBoard
                          ? 'Frames on this board'
                          : 'Current page',
                    ),
                  ),
                  const DropdownMenuItem(
                    value: ExportScope.allPages,
                    child: Text('All pages and frames'),
                  ),
                  DropdownMenuItem(
                    value: ExportScope.selection,
                    enabled: session.selection.isNotEmpty,
                    child: Text(
                      session.selection.isEmpty
                          ? 'Selection (nothing selected)'
                          : 'Selection',
                    ),
                  ),
                ],
                onChanged:
                    (v) =>
                        setState(() => _options = _options.copyWith(scope: v)),
              ),
              if (!format.isVector) ...[
                const SizedBox(height: Space.lg),
                _Label(format == ExportFormat.pdf ? 'Quality' : 'Size'),
                SegmentedButton<double>(
                  showSelectedIcon: false,
                  segments:
                      format == ExportFormat.pdf
                          ? const [
                            ButtonSegment(value: 1, label: Text('Screen')),
                            ButtonSegment(value: 2, label: Text('Standard')),
                            ButtonSegment(value: 3.125, label: Text('Print')),
                          ]
                          : const [
                            ButtonSegment(value: 0.5, label: Text('0.5×')),
                            ButtonSegment(value: 1, label: Text('1×')),
                            ButtonSegment(value: 2, label: Text('2×')),
                            ButtonSegment(value: 3, label: Text('3×')),
                            ButtonSegment(value: 4, label: Text('4×')),
                          ],
                  selected: {
                    if (format == ExportFormat.pdf &&
                        ![1.0, 2.0, 3.125].contains(_options.scale))
                      2.0
                    else
                      _options.scale,
                  },
                  onSelectionChanged:
                      (v) => setState(
                        () => _options = _options.copyWith(scale: v.single),
                      ),
                ),
                if (pixels != null) ...[
                  const SizedBox(height: Space.xs),
                  Text(
                    format == ExportFormat.pdf
                        ? 'About ${(96 * _options.scale).round()} dpi'
                        : '${pixels.width} × ${pixels.height} px'
                            '${targets.length > 1 ? ' (first file)' : ''}',
                    style: OcxText.caption(context).copyWith(
                      color: c.textTertiary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
              if (format == ExportFormat.jpg) ...[
                const SizedBox(height: Space.md),
                _Label('Quality ${_options.jpegQuality}'),
                Slider(
                  value: _options.jpegQuality.toDouble(),
                  min: 40,
                  max: 100,
                  divisions: 12,
                  label: '${_options.jpegQuality}',
                  onChanged:
                      (v) => setState(
                        () =>
                            _options = _options.copyWith(
                              jpegQuality: v.round(),
                            ),
                      ),
                ),
              ],
              if (format.supportsTransparency) ...[
                const SizedBox(height: Space.sm),
                CheckboxListTile(
                  value: _options.transparent,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'Transparent background',
                    style: OcxText.body(context),
                  ),
                  onChanged:
                      (v) => setState(
                        () =>
                            _options = _options.copyWith(
                              transparent: v ?? false,
                            ),
                      ),
                ),
              ],
              if (_error case final error?) ...[
                const SizedBox(height: Space.sm),
                Text(
                  error,
                  style: OcxText.caption(context).copyWith(color: c.danger),
                ),
              ],
              const SizedBox(height: Space.xl),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      switch (_progress) {
                        (final done, final total) when _busy && total > 1 =>
                          done < total
                              ? 'Rendering page ${done + 1} of $total…'
                              : 'Encoding…',
                        _ when _busy => 'Exporting…',
                        _ => summary,
                      },
                      style: OcxText.caption(context).copyWith(
                        color: c.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: Space.sm),
                  FilledButton.icon(
                    onPressed: _busy || targets.isEmpty ? null : _export,
                    icon:
                        _busy
                            ? const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.download, size: Chrome.icon),
                    label: const Text('Export'),
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: Text(text, style: OcxText.bodyStrong(context)),
  );
}
