import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storage/storage.dart';

import '../../providers.dart';
import '../../theme/ocx_theme.dart';
import '../editor_controller.dart';
import 'asset_tiles.dart';

/// History (P1.8.2) and named versions (P1.8.3): every step since the
/// design was opened, clickable to jump back or forward, and saved
/// versions that can be restored.
class HistoryPanel extends ConsumerWidget {
  const HistoryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild whenever the document changes (every edit, undo and redo).
    ref.watch(editorProvider.select((s) => s?.document));
    final editor = ref.read(editorProvider.notifier);
    final undo = editor.undoLabels;
    final redo = editor.redoLabels;
    final versions = ref.watch(designVersionsProvider);
    final c = context.ocx;

    Widget step(String label, int index, {required bool future}) {
      final current = index == undo.length;
      return InkWell(
        onTap: current ? null : () => editor.stepHistory(index - undo.length),
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          color: current ? c.accentSubtle : null,
          child: Row(
            children: [
              Icon(
                index == 0 ? Icons.folder_open_outlined : Icons.circle,
                size: index == 0 ? 14 : 6,
                color: future ? c.textTertiary : c.textSecondary,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OcxText.body(context).copyWith(
                    color: future ? c.textTertiary : null,
                    fontWeight: current ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xl),
      children: [
        const SectionHeader(title: 'Versions'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          child: OutlinedButton.icon(
            onPressed: () => _saveVersion(context, ref),
            icon: const Icon(Icons.bookmark_add_outlined, size: 16),
            label: const Text('Save version'),
          ),
        ),
        const SizedBox(height: Space.xs),
        ...switch (versions) {
          AsyncData(:final value) when value.isEmpty => [
            Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Text(
                'Save a version before big changes to come back to it '
                'later. Versions are kept next to the design.',
                style: OcxText.caption(
                  context,
                ).copyWith(color: c.textTertiary, fontWeight: FontWeight.w400),
              ),
            ),
          ],
          AsyncData(:final value) => [
            for (final v in value) _VersionTile(version: v),
          ],
          AsyncError() => [
            Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Text(
                'Could not read versions.',
                style: OcxText.caption(context),
              ),
            ),
          ],
          _ => [const LinearProgressIndicator(minHeight: 2)],
        },
        const SectionHeader(title: 'History'),
        if (undo.isEmpty && redo.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: Text(
              'Your changes since opening the design appear here. Click a '
              'step to go back to it.',
              style: OcxText.caption(
                context,
              ).copyWith(color: c.textTertiary, fontWeight: FontWeight.w400),
            ),
          ),
        if (undo.isNotEmpty || redo.isNotEmpty) ...[
          step('Opened', 0, future: false),
          for (final (i, label) in undo.indexed)
            step(label, i + 1, future: false),
          for (final (i, label) in redo.indexed)
            step(label, undo.length + i + 1, future: true),
        ],
      ],
    );
  }

  Future<void> _saveVersion(BuildContext context, WidgetRef ref) async {
    final label = await showDialog<String>(
      context: context,
      builder: (_) => const _VersionNameDialog(),
    );
    if (label == null) return;
    await ref.read(editorProvider.notifier).saveVersion(label);
    ref.invalidate(designVersionsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Version saved')));
    }
  }
}

class _VersionNameDialog extends StatefulWidget {
  const _VersionNameDialog();

  @override
  State<_VersionNameDialog> createState() => _VersionNameDialogState();
}

class _VersionNameDialogState extends State<_VersionNameDialog> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Save version'),
    content: SizedBox(
      width: 360,
      child: TextField(
        controller: _name,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'e.g. Before new colours',
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _name.text),
        child: const Text('Save'),
      ),
    ],
  );
}

class _VersionTile extends ConsumerWidget {
  const _VersionTile({required this.version});

  final DesignVersion version;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ocx;
    final t = version.createdAt;
    String two(int n) => n.toString().padLeft(2, '0');
    final when =
        '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, 2, Space.xs, 2),
      child: Row(
        children: [
          Icon(Icons.bookmark_outline, size: 16, color: c.textSecondary),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  version.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OcxText.body(context),
                ),
                Text(
                  when,
                  style: OcxText.caption(context).copyWith(
                    color: c.textTertiary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref.read(editorProvider.notifier).restoreVersion(version);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Restored "${version.label}". Undo to go back.',
                    ),
                  ),
                );
              } on Object catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Could not restore: $e')),
                );
              }
            },
            child: const Text('Restore'),
          ),
          IconButton(
            tooltip: 'Delete version',
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await ref.read(designLibraryProvider).deleteVersion(version);
              ref.invalidate(designVersionsProvider);
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
