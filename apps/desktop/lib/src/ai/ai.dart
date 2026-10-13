import 'dart:convert';
import 'dart:io';

import 'package:ai_engine/ai_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/ocx_theme.dart';
import 'windows_credentials.dart';

/// Where API keys are kept (P5.1.6): the OS credential store, never the
/// app index, design files or logs. Tests replace it.
abstract interface class SecretStore {
  Future<String?> read(String name);
  Future<void> write(String name, String value);
  Future<void> delete(String name);
}

/// Windows Credential Manager. Other platforms get their keychain later;
/// until then AI keys cannot be saved there.
class _OsSecretStore implements SecretStore {
  const _OsSecretStore();

  @override
  Future<String?> read(String name) async =>
      Platform.isWindows ? readWindowsCredential(name) : null;

  @override
  Future<void> write(String name, String value) async {
    if (!Platform.isWindows) {
      throw const AiException(
        'Saving API keys is only supported on Windows for now.',
      );
    }
    writeWindowsCredential(name, value);
  }

  @override
  Future<void> delete(String name) async {
    if (Platform.isWindows) deleteWindowsCredential(name);
  }
}

final secretStoreProvider = Provider<SecretStore>(
  (ref) => const _OsSecretStore(),
);

/// Secret name of [kind]'s API key.
String aiKeyName(AiProviderKind kind) => 'opencanvasx.ai.${kind.name}';

/// The AI provider settings, or `null` when AI is off (the default,
/// P5.1.7). Stored without the key.
final aiConfigProvider = NotifierProvider<AiConfigController, AiConfig?>(
  AiConfigController.new,
);

class AiConfigController extends Notifier<AiConfig?> {
  static const _key = 'ai.config';

  @override
  AiConfig? build() {
    final raw = ref.watch(appIndexProvider).settings.get(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AiConfig.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

  AiConfig? get config => state;

  set config(AiConfig? value) {
    final settings = ref.read(appIndexProvider).settings;
    if (value == null) {
      settings.remove(_key);
    } else {
      settings.set(_key, jsonEncode(value.toJson()));
    }
    state = value;
  }
}

/// Sends a request to the provider; tests replace it.
typedef AiComplete =
    Future<AiReply> Function(
      AiConfig config, {
      required String system,
      required String prompt,
      String? apiKey,
    });

final aiCompleteProvider = Provider<AiComplete>((ref) => complete);

/// One AI call, for the in-app log (no content, no keys).
typedef AiLogEntry =
    ({
      DateTime at,
      String task,
      String provider,
      bool local,
      int charactersSent,
      int? tokensIn,
      int? tokensOut,
    });

final aiLogProvider = NotifierProvider<AiLogController, List<AiLogEntry>>(
  AiLogController.new,
);

class AiLogController extends Notifier<List<AiLogEntry>> {
  @override
  List<AiLogEntry> build() => const [];

  void add(AiLogEntry entry) => state = [entry, ...state.take(49)];
}

/// Cloud providers the user agreed to send to without asking again this
/// session.
final _trustedThisSession = <String>{};

/// Shows what will be sent to a cloud provider (P5.2.2) and asks first;
/// local providers do not ask. Returns whether to continue.
Future<bool> confirmAiSend(
  BuildContext context,
  AiConfig config,
  String summary,
) async {
  if (config.isLocal || _trustedThisSession.contains(config.endpoint)) {
    return true;
  }
  var remember = false;
  final ok = await showDialog<bool>(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                icon: const Icon(Icons.cloud_upload_outlined),
                title: const Text('Send to an AI provider?'),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This will be sent to ${config.displayName} '
                        '(${Uri.tryParse(config.endpoint)?.host ?? config.endpoint}):',
                      ),
                      const SizedBox(height: Space.sm),
                      Text(summary, style: OcxText.bodyStrong(context)),
                      const SizedBox(height: Space.sm),
                      Text(
                        'It leaves this computer and is handled under your '
                        'account with that provider. Nothing else from your '
                        'design is sent.',
                        style: OcxText.caption(context).copyWith(
                          color: context.ocx.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      CheckboxListTile(
                        value: remember,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          "Don't ask again until I close the app",
                        ),
                        onChanged: (v) => setState(() => remember = v ?? false),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Send'),
                  ),
                ],
              ),
        ),
  );
  if ((ok ?? false) && remember) _trustedThisSession.add(config.endpoint);
  return ok ?? false;
}

/// Runs one AI request with disclosure, the stored key and logging.
/// Returns the reply text, or `null` if cancelled.
Future<String?> runAi(
  BuildContext context,
  WidgetRef ref, {
  required String task,
  required String system,
  required String prompt,
  required String summary,
  VoidCallback? onSend,
}) async {
  final config = ref.read(aiConfigProvider);
  if (config == null) {
    throw const AiException('Turn on AI in AI settings first.');
  }
  if (!await confirmAiSend(context, config, summary)) return null;
  onSend?.call();
  final key = await ref.read(secretStoreProvider).read(aiKeyName(config.kind));
  final reply = await ref.read(aiCompleteProvider)(
    config,
    system: system,
    prompt: prompt,
    apiKey: key,
  );
  ref.read(aiLogProvider.notifier).add((
    at: DateTime.now(),
    task: task,
    provider: config.displayName,
    local: config.isLocal,
    charactersSent: system.length + prompt.length,
    tokensIn: reply.inputTokens,
    tokensOut: reply.outputTokens,
  ));
  return reply.text;
}
