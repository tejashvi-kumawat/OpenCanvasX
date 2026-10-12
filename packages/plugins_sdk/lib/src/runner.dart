import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'manifest.dart';

/// Longest a plugin run may take.
const Duration pluginTimeout = Duration(seconds: 15);

/// Most output a plugin may write.
const int maxPluginOutput = 10 * 1024 * 1024;

/// A plugin folder and its parsed manifest.
typedef PluginBundle = ({String path, PluginManifest manifest});

/// Reads `plugin.json` in [folder].
PluginBundle loadPlugin(String folder) {
  final file = File('$folder${Platform.pathSeparator}plugin.json');
  if (!file.existsSync()) {
    throw const FormatException('This folder has no plugin.json.');
  }
  if (file.lengthSync() > 256 * 1024) {
    throw const FormatException('plugin.json is too large.');
  }
  return (
    path: folder,
    manifest: PluginManifest.parse(file.readAsStringSync()),
  );
}

/// Runs [plugin] once (P6.1.2): starts its program in the plugin folder
/// with an empty environment (only what is needed to start a program),
/// writes [request] as JSON to stdin and reads one JSON object from
/// stdout. Fails on timeout, oversized output, a non-zero exit or
/// invalid JSON; the process is killed when it overruns.
///
/// This isolates the plugin from OpenCanvasX's memory and secrets, but
/// not from the file system or network: the operating system would have
/// to sandbox it for that, which is why code plugins need developer mode.
Future<Object?> runPlugin(
  PluginBundle plugin,
  Map<String, Object?> request, {
  Duration timeout = pluginTimeout,
}) async {
  final command = plugin.manifest.command;
  final env = <String, String>{
    for (final key in const ['PATH', 'SYSTEMROOT', 'SystemRoot', 'WINDIR'])
      if (Platform.environment[key] case final value?) key: value,
    'OPENCANVASX_PLUGIN_API': '$pluginApiVersion',
    'PYTHONIOENCODING': 'utf-8',
    'PYTHONDONTWRITEBYTECODE': '1',
  };
  final Process process;
  try {
    process = await Process.start(
      command.first,
      command.skip(1).toList(),
      workingDirectory: plugin.path,
      environment: env,
      includeParentEnvironment: false,
    );
  } on ProcessException catch (e) {
    throw PluginException(
      'Could not start "${command.first}". Is it installed? (${e.message})',
    );
  }

  final out = BytesBuilder(copy: false);
  final err = BytesBuilder(copy: false);
  var tooLarge = false;
  final outDone =
      process.stdout.listen((chunk) {
        if (out.length + chunk.length > maxPluginOutput) {
          tooLarge = true;
          process.kill(ProcessSignal.sigkill);
          return;
        }
        out.add(chunk);
      }).asFuture<void>();
  final errDone =
      process.stderr.listen((chunk) {
        if (err.length < 16 * 1024) err.add(chunk);
      }).asFuture<void>();

  try {
    process.stdin.add(utf8.encode(jsonEncode(request)));
    await process.stdin.close();
  } on Object {
    // The plugin may exit without reading; its exit code tells.
  }

  final int code;
  try {
    code = await process.exitCode.timeout(timeout);
  } on TimeoutException {
    process.kill(ProcessSignal.sigkill);
    throw PluginException(
      '${plugin.manifest.name} took longer than ${timeout.inSeconds} s and '
      'was stopped.',
    );
  }
  await Future.wait([
    outDone,
    errDone,
  ]).timeout(const Duration(seconds: 2), onTimeout: () => const []);
  if (tooLarge) {
    throw PluginException('${plugin.manifest.name} wrote too much output.');
  }
  if (code != 0) {
    final message = utf8.decode(err.takeBytes(), allowMalformed: true).trim();
    throw PluginException(
      '${plugin.manifest.name} failed (exit $code)'
      '${message.isEmpty ? '' : ': ${message.split('\n').last}'}',
    );
  }
  final text = utf8.decode(out.takeBytes(), allowMalformed: true).trim();
  try {
    return jsonDecode(text);
  } on FormatException {
    throw PluginException('${plugin.manifest.name} did not return JSON.');
  }
}

/// A plugin run that failed; [message] is shown to the user.
final class PluginException implements Exception {
  const PluginException(this.message);

  final String message;

  @override
  String toString() => message;
}
