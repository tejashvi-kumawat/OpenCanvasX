import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// Plugin API version this build speaks.
const int pluginApiVersion = 1;

/// Capabilities a plugin can request (plugin-architecture.md). Default
/// deny: a plugin only gets what it declares and the user approves.
enum PluginPermission {
  /// The selected objects (geometry, style, text) are sent to the plugin.
  readSelection('read_selection', 'See the objects you have selected'),

  /// The whole design is sent to the plugin.
  readDocument('read_document', 'See the whole design'),

  /// The plugin may add, change and delete objects (one undo step).
  writeDocument('write_document', 'Add, change and delete objects'),

  /// Declared network use. Not enforceable for plugin programs yet; shown
  /// to the user as a warning.
  network('network', 'Use the internet');

  const PluginPermission(this.id, this.description);

  final String id;
  final String description;

  static PluginPermission? parse(String id) =>
      values.where((p) => p.id == id).firstOrNull;
}

/// A form field a command asks for before it runs.
@immutable
final class PluginInput {
  const PluginInput({
    required this.id,
    required this.label,
    required this.type,
    this.defaultValue,
    this.options = const [],
    this.min,
    this.max,
  });

  factory PluginInput._parse(Map<String, Object?> json) {
    final id = _string(json, 'id', pattern: _idPattern);
    final type = _string(json, 'type');
    if (!const {'text', 'number', 'select', 'color'}.contains(type)) {
      throw FormatException('input $id: unknown type "$type"');
    }
    final options = json['options'];
    return PluginInput(
      id: id,
      label: _string(json, 'label'),
      type: type,
      defaultValue: json['default'],
      options: [
        if (options is List)
          for (final o in options)
            if (o is String) o,
      ],
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String label;

  /// `text`, `number`, `select` or `color` (hex `#RRGGBB`).
  final String type;
  final Object? defaultValue;
  final List<String> options;
  final double? min;
  final double? max;
}

/// One action a plugin offers.
@immutable
final class PluginCommand {
  const PluginCommand({
    required this.id,
    required this.title,
    this.inputs = const [],
  });

  final String id;
  final String title;
  final List<PluginInput> inputs;
}

/// `plugin.json` (P6.1.1).
@immutable
final class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.api,
    required this.command,
    required this.commands,
    required this.permissions,
    required this.hash,
    this.description = '',
    this.author = '',
    this.unknownPermissions = const [],
  });

  /// Parses and validates a manifest's [source] text.
  factory PluginManifest.parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('plugin.json is not valid JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('plugin.json must be an object');
    }
    final json = decoded;
    final id = _string(
      json,
      'id',
      pattern: RegExp(r'^[a-z0-9]+([._-][a-z0-9]+)*$'),
    );
    final api = json['api'];
    if (api is! int || api < 1) throw const FormatException('missing "api"');
    if (api > pluginApiVersion) {
      throw FormatException(
        'needs plugin API $api; this OpenCanvasX supports $pluginApiVersion',
      );
    }
    final entry = json['entry'];
    final command = entry is Map ? entry['command'] : null;
    if (command is! List ||
        command.isEmpty ||
        command.any((c) => c is! String || c.isEmpty)) {
      throw const FormatException('"entry.command" must list a program');
    }
    for (final part in command.cast<String>()) {
      if (part.contains('..')) {
        throw const FormatException(
          '"entry.command" must not leave the plugin',
        );
      }
    }
    final permissions = <PluginPermission>{};
    final unknown = <String>[];
    for (final p in (json['permissions'] as List?) ?? const []) {
      if (p is! String) continue;
      final parsed = PluginPermission.parse(p);
      if (parsed == null) {
        unknown.add(p);
      } else {
        permissions.add(parsed);
      }
    }
    final rawCommands = json['commands'];
    if (rawCommands is! List || rawCommands.isEmpty) {
      throw const FormatException('"commands" must list at least one command');
    }
    final commands = <PluginCommand>[];
    for (final c in rawCommands) {
      if (c is! Map<String, Object?>) {
        throw const FormatException('command must be an object');
      }
      final inputs = c['inputs'];
      commands.add(
        PluginCommand(
          id: _string(c, 'id', pattern: _idPattern),
          title: _string(c, 'title'),
          inputs: [
            if (inputs is List)
              for (final i in inputs)
                if (i is Map<String, Object?>) PluginInput._parse(i),
          ],
        ),
      );
    }
    return PluginManifest(
      id: id,
      name: _string(json, 'name'),
      version: _string(json, 'version'),
      api: api,
      command: List.unmodifiable(command.cast<String>()),
      commands: List.unmodifiable(commands),
      permissions: Set.unmodifiable(permissions),
      unknownPermissions: List.unmodifiable(unknown),
      description:
          json['description'] is String ? json['description']! as String : '',
      author: json['author'] is String ? json['author']! as String : '',
      hash: sha256.convert(utf8.encode(source)).toString(),
    );
  }

  final String id;
  final String name;
  final String version;
  final int api;

  /// Program and arguments, run in the plugin folder.
  final List<String> command;
  final List<PluginCommand> commands;
  final Set<PluginPermission> permissions;

  /// Permissions this build does not know (refused at install).
  final List<String> unknownPermissions;
  final String description;
  final String author;

  /// SHA-256 of `plugin.json`; approval is tied to it (P6.1.3).
  final String hash;
}

final _idPattern = RegExp(r'^[a-z0-9_-]{1,64}$');

String _string(Map<String, Object?> json, String key, {RegExp? pattern}) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('plugin.json: missing "$key"');
  }
  if (pattern != null && !pattern.hasMatch(value)) {
    throw FormatException('plugin.json: bad "$key" "$value"');
  }
  return value;
}
