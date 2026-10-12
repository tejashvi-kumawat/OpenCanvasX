import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plugins_sdk/plugins_sdk.dart';

import '../editor/editor_controller.dart';
import '../editor/panels/asset_tiles.dart';
import '../providers.dart';
import '../theme/ocx_theme.dart';
import 'plugins.dart';

/// Apps (P6.1): installed plugins and their commands, plugins available to
/// install, install from a folder, and developer mode.
class AppsPanel extends ConsumerWidget {
  const AppsPanel({super.key});

  Future<void> _installFromFolder(BuildContext context, WidgetRef ref) async {
    final path = await ref.read(folderPickerProvider)();
    if (path == null || !context.mounted) return;
    try {
      await showInstallDialog(context, ref, loadPlugin(path));
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Not a plugin: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ocx;
    final installed = ref.watch(installedPluginsProvider);
    final installedPaths = {for (final p in installed) p.path};
    final available = [
      for (final path in ref.watch(bundledPluginsProvider))
        if (!installedPaths.contains(path)) path,
    ];
    final developer = ref.watch(developerModeProvider);
    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xl),
      children: [
        Container(
          margin: const EdgeInsets.all(Space.md),
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: c.surfaceSunken,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.science_outlined,
                    size: 16,
                    color: c.textSecondary,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      'Developer mode',
                      style: OcxText.bodyStrong(context),
                    ),
                  ),
                  Switch(
                    value: developer,
                    onChanged:
                        (v) =>
                            ref.read(developerModeProvider.notifier).enabled =
                                v,
                  ),
                ],
              ),
              Text(
                'Plugins are programs. They run outside OpenCanvasX with no '
                'access to your designs beyond what you approve, but your '
                'computer does not yet stop them from reading files or using '
                'the internet. Only turn this on for plugins you trust.',
                style: OcxText.caption(
                  context,
                ).copyWith(color: c.textSecondary, fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'Installed'),
        if (installed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: Text(
              'No plugins yet. Install one below.',
              style: OcxText.caption(
                context,
              ).copyWith(color: c.textTertiary, fontWeight: FontWeight.w400),
            ),
          ),
        for (final plugin in installed) _InstalledCard(plugin: plugin),
        if (available.isNotEmpty) ...[
          const SectionHeader(title: 'Available'),
          for (final path in available) _AvailableRow(path: path),
        ],
        Padding(
          padding: const EdgeInsets.all(Space.md),
          child: OutlinedButton.icon(
            onPressed: () => _installFromFolder(context, ref),
            icon: const Icon(Icons.create_new_folder_outlined, size: 16),
            label: const Text('Install from folder'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          child: Text(
            'A plugin is a folder with plugin.json. See '
            'docs/architecture/plugin-architecture.md and the examples in '
            'plugins/.',
            style: OcxText.caption(
              context,
            ).copyWith(color: c.textTertiary, fontWeight: FontWeight.w400),
          ),
        ),
      ],
    );
  }
}

class _AvailableRow extends ConsumerWidget {
  const _AvailableRow({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ocx;
    PluginBundle? bundle;
    String? error;
    try {
      bundle = loadPlugin(path);
    } on Object catch (e) {
      error = '$e';
    }
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.md),
        leading: Icon(
          Icons.extension_outlined,
          size: 18,
          color: c.textSecondary,
        ),
        title: Text(
          bundle?.manifest.name ?? path.split(RegExp(r'[\\/]')).last,
          style: OcxText.bodyStrong(context),
        ),
        subtitle: Text(
          error ?? bundle!.manifest.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: OcxText.caption(
            context,
          ).copyWith(color: c.textTertiary, fontWeight: FontWeight.w400),
        ),
        trailing:
            bundle == null
                ? null
                : TextButton(
                  onPressed: () => showInstallDialog(context, ref, bundle!),
                  child: const Text('Install'),
                ),
      ),
    );
  }
}

class _InstalledCard extends ConsumerWidget {
  const _InstalledCard({required this.plugin});

  final InstalledPlugin plugin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ocx;
    final bundle = plugin.bundle;
    return Container(
      margin: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.sm),
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.extension, size: 16, color: c.accent),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  bundle?.manifest.name ?? plugin.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OcxText.bodyStrong(context),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Plugin options',
                iconSize: 16,
                onSelected: (v) {
                  if (v == 'remove') {
                    ref
                        .read(installedPluginsProvider.notifier)
                        .remove(plugin.path);
                  }
                },
                itemBuilder:
                    (_) => const [
                      PopupMenuItem(value: 'remove', child: Text('Uninstall')),
                    ],
              ),
            ],
          ),
          if (plugin.problem case final problem?) ...[
            Text(
              problem,
              style: OcxText.caption(context).copyWith(color: c.warning),
            ),
            if (bundle != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => showInstallDialog(context, ref, bundle),
                  child: const Text('Review again'),
                ),
              ),
          ] else if (bundle != null)
            for (final command in bundle.manifest.commands)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: OutlinedButton(
                  onPressed:
                      () => runPluginCommand(context, ref, plugin, command),
                  child: Text(command.title),
                ),
              ),
        ],
      ),
    );
  }
}

/// Shows what [bundle] asks for and installs it when approved (P6.1.3).
Future<void> showInstallDialog(
  BuildContext context,
  WidgetRef ref,
  PluginBundle bundle,
) => showDialog<void>(
  context: context,
  builder: (context) {
    final c = context.ocx;
    final m = bundle.manifest;
    final refused = m.unknownPermissions.isNotEmpty;
    return AlertDialog(
      icon: const Icon(Icons.extension_outlined),
      title: Text('Install ${m.name}?'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${m.author.isEmpty ? 'Unknown author' : m.author} · version '
              '${m.version} · unsigned',
              style: OcxText.caption(context).copyWith(color: c.textSecondary),
            ),
            if (m.description.isNotEmpty) ...[
              const SizedBox(height: Space.sm),
              Text(m.description, style: OcxText.body(context)),
            ],
            const SizedBox(height: Space.md),
            Text('It will be able to:', style: OcxText.bodyStrong(context)),
            const SizedBox(height: Space.xs),
            if (m.permissions.isEmpty)
              Text('Only show messages.', style: OcxText.body(context)),
            for (final p in m.permissions)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Icon(
                      p == PluginPermission.network
                          ? Icons.public
                          : Icons.check,
                      size: 14,
                      color:
                          p == PluginPermission.network ? c.warning : c.success,
                    ),
                    const SizedBox(width: Space.xs),
                    Expanded(
                      child: Text(p.description, style: OcxText.body(context)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Space.sm),
            Text(
              'Runs: ${m.command.join(' ')}',
              style: OcxText.caption(context).copyWith(color: c.textTertiary),
            ),
            if (refused) ...[
              const SizedBox(height: Space.sm),
              Text(
                'It also asks for permissions this version does not know '
                '(${m.unknownPermissions.join(', ')}), so it cannot be '
                'installed.',
                style: OcxText.caption(context).copyWith(color: c.danger),
              ),
            ],
            const SizedBox(height: Space.sm),
            Text(
              'Only install plugins you trust. Plugins run as programs on '
              'this computer and need developer mode.',
              style: OcxText.caption(context).copyWith(color: c.warning),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              refused
                  ? null
                  : () {
                    ref.read(installedPluginsProvider.notifier).approve(bundle);
                    Navigator.pop(context);
                  },
          child: const Text('Install'),
        ),
      ],
    );
  },
);

/// Asks for [command]'s inputs, runs the plugin and applies its result as
/// one undo step; messages are shown afterwards.
Future<void> runPluginCommand(
  BuildContext context,
  WidgetRef ref,
  InstalledPlugin plugin,
  PluginCommand command,
) async {
  final bundle = plugin.bundle;
  if (bundle == null) return;
  final messenger = ScaffoldMessenger.of(context);
  if (!ref.read(developerModeProvider)) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Turn on developer mode in Apps to run plugins.'),
      ),
    );
    return;
  }
  final inputs =
      command.inputs.isEmpty
          ? <String, Object?>{}
          : await showDialog<Map<String, Object?>>(
            context: context,
            builder:
                (_) =>
                    _InputsDialog(title: command.title, inputs: command.inputs),
          );
  if (inputs == null) return;
  final session = ref.read(editorProvider);
  if (session == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text('Running ${bundle.manifest.name}…'),
      duration: const Duration(seconds: 1),
    ),
  );
  try {
    final request = buildPluginRequest(
      manifest: _withApproved(bundle.manifest, plugin.approved),
      command: command.id,
      inputs: inputs,
      document: session.document,
      pageId: session.state.activePageId,
      selection: session.selection,
    );
    final response = await runPlugin(bundle, request);
    final current = ref.read(editorProvider);
    if (current == null) return;
    final effect = applyPluginResponse(
      current.document,
      current.state.activePageId,
      response,
      permissions: plugin.approved,
      measure: ref.read(textMeasurerProvider),
    );
    ref
        .read(editorProvider.notifier)
        .applyPluginEffect(effect, name: bundle.manifest.name);
    for (final message in effect.messages) {
      messenger.showSnackBar(
        SnackBar(content: Text('${bundle.manifest.name}: $message')),
      );
    }
  } on Object catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e')));
  }
}

/// [manifest] restricted to the permissions the user approved.
PluginManifest _withApproved(
  PluginManifest manifest,
  Set<PluginPermission> approved,
) => PluginManifest(
  id: manifest.id,
  name: manifest.name,
  version: manifest.version,
  api: manifest.api,
  command: manifest.command,
  commands: manifest.commands,
  permissions: manifest.permissions.intersection(approved),
  hash: manifest.hash,
  description: manifest.description,
  author: manifest.author,
);

class _InputsDialog extends StatefulWidget {
  const _InputsDialog({required this.title, required this.inputs});

  final String title;
  final List<PluginInput> inputs;

  @override
  State<_InputsDialog> createState() => _InputsDialogState();
}

class _InputsDialogState extends State<_InputsDialog> {
  late final Map<String, Object?> _values = {
    for (final i in widget.inputs) i.id: i.defaultValue,
  };

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final input in widget.inputs)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: switch (input.type) {
                'select' => DropdownButtonFormField<String>(
                  initialValue:
                      input.options.contains(_values[input.id])
                          ? _values[input.id]! as String
                          : input.options.firstOrNull,
                  decoration: InputDecoration(labelText: input.label),
                  items: [
                    for (final o in input.options)
                      DropdownMenuItem(value: o, child: Text(o)),
                  ],
                  onChanged: (v) => _values[input.id] = v,
                ),
                _ => TextFormField(
                  initialValue: '${_values[input.id] ?? ''}',
                  decoration: InputDecoration(
                    labelText: input.label,
                    hintText: input.type == 'color' ? '#3256F0' : null,
                  ),
                  keyboardType:
                      input.type == 'number'
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                  onChanged: (v) {
                    if (input.type == 'number') {
                      final n = num.tryParse(v);
                      if (n == null) return;
                      _values[input.id] = n.clamp(
                        input.min ?? double.negativeInfinity,
                        input.max ?? double.infinity,
                      );
                    } else {
                      _values[input.id] = v;
                    }
                  },
                ),
              },
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _values),
        child: const Text('Run'),
      ),
    ],
  );
}
