import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plugins_sdk/plugins_sdk.dart';

import '../providers.dart';

/// An installed plugin and whether it may run.
typedef InstalledPlugin =
    ({
      String path,
      PluginBundle? bundle,

      /// Permissions the user approved for the manifest with [hash].
      Set<PluginPermission> approved,
      String hash,

      /// Why the plugin cannot run (broken, or changed since approval).
      String? problem,
    });

/// Plugin folders shipped with the app (`plugins/` next to it, or in a
/// source checkout); offered under "Available".
List<String> discoverBundledPlugins() {
  final sep = Platform.pathSeparator;
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 9; i++) {
    final candidate = Directory('${dir.path}${sep}plugins');
    if (candidate.existsSync()) {
      final found = [
        for (final d in candidate.listSync().whereType<Directory>())
          if (File('${d.path}${sep}plugin.json').existsSync()) d.path,
      ]..sort();
      if (found.isNotEmpty) return found;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return const [];
}

/// Bundled plugin folders; tests replace it.
final bundledPluginsProvider = Provider<List<String>>(
  (ref) => discoverBundledPlugins(),
);

/// Developer mode (plugin-architecture.md "Sandboxing"): code plugins run
/// only when it is on, because the OS does not yet sandbox them.
final developerModeProvider = NotifierProvider<DeveloperModeController, bool>(
  DeveloperModeController.new,
);

class DeveloperModeController extends Notifier<bool> {
  static const _key = 'plugins.developer_mode';

  @override
  bool build() => ref.watch(appIndexProvider).settings.get(_key) == 'on';

  bool get enabled => state;
  set enabled(bool value) {
    ref.read(appIndexProvider).settings.set(_key, value ? 'on' : 'off');
    state = value;
  }
}

/// Installed plugins with their approvals (P6.1.3), stored in the app
/// index. A plugin whose manifest changed must be approved again.
final installedPluginsProvider =
    NotifierProvider<InstalledPluginsController, List<InstalledPlugin>>(
      InstalledPluginsController.new,
    );

class InstalledPluginsController extends Notifier<List<InstalledPlugin>> {
  static const _key = 'plugins.installed';

  @override
  List<InstalledPlugin> build() {
    final raw = ref.watch(appIndexProvider).settings.get(_key);
    final list = raw == null ? const <Object?>[] : jsonDecode(raw) as List;
    return [
      for (final item in list.whereType<Map<String, Object?>>())
        if (item['path'] is String) _load(item),
    ];
  }

  InstalledPlugin _load(Map<String, Object?> item) {
    final path = item['path']! as String;
    final hash = item['hash'] is String ? item['hash']! as String : '';
    final approved = {
      for (final p in (item['approved'] as List?) ?? const [])
        if (p is String)
          if (PluginPermission.parse(p) case final perm?) perm,
    };
    try {
      final bundle = loadPlugin(path);
      final changed = bundle.manifest.hash != hash;
      return (
        path: path,
        bundle: bundle,
        approved: approved,
        hash: hash,
        problem:
            changed
                ? 'The plugin changed since you approved it. Review it again.'
                : null,
      );
    } on Object catch (e) {
      return (
        path: path,
        bundle: null,
        approved: approved,
        hash: hash,
        problem: '$e',
      );
    }
  }

  void _save(List<InstalledPlugin> plugins) {
    ref
        .read(appIndexProvider)
        .settings
        .set(
          _key,
          jsonEncode([
            for (final p in plugins)
              {
                'path': p.path,
                'hash': p.hash,
                'approved': [for (final perm in p.approved) perm.id],
              },
          ]),
        );
    ref.invalidateSelf();
  }

  /// Records the user's approval of [bundle] as it is now.
  void approve(PluginBundle bundle) {
    final others = [
      for (final p in state)
        if (p.path != bundle.path) p,
    ];
    _save([
      ...others,
      (
        path: bundle.path,
        bundle: bundle,
        approved: bundle.manifest.permissions,
        hash: bundle.manifest.hash,
        problem: null,
      ),
    ]);
  }

  void remove(String path) => _save([
    for (final p in state)
      if (p.path != path) p,
  ]);
}
