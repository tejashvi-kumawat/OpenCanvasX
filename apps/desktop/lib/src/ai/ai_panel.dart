import 'package:ai_engine/ai_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plugins_sdk/plugins_sdk.dart';

import '../editor/editor_controller.dart';
import '../editor/panels/asset_tiles.dart';
import '../theme/ocx_theme.dart';
import 'ai.dart';

/// AI (P5.3): write with AI for selected text and design from a prompt.
/// Off until the user sets up a provider.
class AiPanel extends ConsumerStatefulWidget {
  const AiPanel({super.key});

  @override
  ConsumerState<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends ConsumerState<AiPanel> {
  final TextEditingController _prompt = TextEditingController();
  String _language = 'Spanish';
  bool _busy = false;
  bool _designing = false;
  String? _suggestion;
  ObjectId? _suggestionFor;

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = _designing = false);
    }
  }

  Future<void> _textTask(TextTask task, DesignObject object) =>
      _guard(() async {
        final text = (object.payload as TextPayload).text;
        final reply = await runAi(
          context,
          ref,
          task: task.label,
          system: textSystemPrompt,
          prompt: textTaskPrompt(task, text, language: _language),
          summary: 'The selected text (${text.length} characters).',
        );
        if (reply == null || !mounted) return;
        setState(() {
          _suggestion = cleanTextReply(reply);
          _suggestionFor = object.id;
        });
      });

  Future<void> _design() => _guard(() async {
    final request = _prompt.text.trim();
    final session = ref.read(editorProvider);
    if (request.isEmpty || session == null) return;
    final page = session.activePage;
    final reply = await runAi(
      context,
      ref,
      onSend: () => setState(() => _designing = true),
      task: 'Design',
      system: designSystemPrompt(
        width: page.width,
        height: page.height,
        unit: page.unit.symbol,
      ),
      prompt: request,
      summary:
          'Your description (${request.length} characters) and the page '
          'size. No existing content.',
    );
    if (reply == null) return;
    final json = extractJsonObject(reply);
    if (json == null) {
      throw const AiException('The AI reply did not contain a design.');
    }
    final current = ref.read(editorProvider)!;
    // Validated exactly like a plugin with write permission only.
    final effect = applyPluginResponse(
      current.document,
      current.state.activePageId,
      json,
      permissions: {PluginPermission.writeDocument},
      measure: ref.read(textMeasurerProvider),
    );
    ref
        .read(editorProvider.notifier)
        .applyPluginEffect(effect, name: 'AI design');
    if (mounted && effect.messages.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(effect.messages.first)));
    }
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final config = ref.watch(aiConfigProvider);
    final session = ref.watch(editorProvider);
    final selected = session?.state.selectedObjects ?? const [];
    final text =
        selected.length == 1 && selected.single.payload is TextPayload
            ? selected.single
            : null;
    final log = ref.watch(aiLogProvider);
    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xl),
      children: [
        Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      config == null
                          ? c.surfaceSunken
                          : (config.isLocal
                              ? const Color(0x2246A758)
                              : c.accentSubtle),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  config == null ? 'Off' : (config.isLocal ? 'Local' : 'Cloud'),
                  style: OcxText.caption(context),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  config?.displayName ?? 'AI is off',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OcxText.body(context),
                ),
              ),
              IconButton(
                tooltip: 'AI settings',
                iconSize: Chrome.icon,
                onPressed: () => showAiSettings(context),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
        ),
        if (config == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'AI is optional. Use a model on this computer (Ollama, '
                  'LM Studio) or your own account with an AI provider. '
                  'Nothing is sent anywhere until you turn it on, and you '
                  'are asked before anything leaves this computer.',
                  style: OcxText.caption(context).copyWith(
                    color: c.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: Space.md),
                FilledButton(
                  onPressed: () => showAiSettings(context),
                  child: const Text('Set up AI'),
                ),
              ],
            ),
          )
        else ...[
          const SectionHeader(title: 'Write with AI'),
          if (text == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Text(
                'Select a text box to rewrite, shorten, expand, change the '
                'tone of, fix or translate it.',
                style: OcxText.caption(
                  context,
                ).copyWith(color: c.textTertiary, fontWeight: FontWeight.w400),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final task in TextTask.values)
                    if (task != TextTask.translate)
                      ActionChip(
                        label: Text(task.label),
                        labelStyle: OcxText.caption(context),
                        visualDensity: VisualDensity.compact,
                        onPressed: _busy ? null : () => _textTask(task, text),
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.sm,
                Space.md,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      value: _language,
                      isExpanded: true,
                      isDense: true,
                      items: [
                        for (final l in const [
                          'English',
                          'Hindi',
                          'Spanish',
                          'French',
                          'German',
                          'Portuguese',
                          'Japanese',
                          'Chinese',
                          'Arabic',
                        ])
                          DropdownMenuItem(value: l, child: Text(l)),
                      ],
                      onChanged:
                          (v) => setState(() => _language = v ?? _language),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  OutlinedButton(
                    onPressed:
                        _busy
                            ? null
                            : () => _textTask(TextTask.translate, text),
                    child: const Text('Translate'),
                  ),
                ],
              ),
            ),
          ],
          if (_suggestion case final suggestion?
              when _suggestionFor != null &&
                  session?.document.objects[_suggestionFor] != null)
            Container(
              margin: const EdgeInsets.all(Space.md),
              padding: const EdgeInsets.all(Space.md),
              decoration: BoxDecoration(
                border: Border.all(color: c.accent),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(suggestion, style: OcxText.body(context)),
                  const SizedBox(height: Space.sm),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: () {
                          ref
                              .read(editorProvider.notifier)
                              .updateObject(
                                _suggestionFor!,
                                (o) => o.copyWith(
                                  payload: (o.payload as TextPayload).copyWith(
                                    text: suggestion,
                                  ),
                                ),
                                label: 'AI text',
                              );
                          setState(() => _suggestion = null);
                        },
                        child: const Text('Replace'),
                      ),
                      const SizedBox(width: Space.sm),
                      TextButton(
                        onPressed: () => setState(() => _suggestion = null),
                        child: const Text('Discard'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SectionHeader(title: 'Design with AI'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: TextField(
              controller: _prompt,
              minLines: 3,
              maxLines: 6,
              style: OcxText.body(context),
              decoration: const InputDecoration(
                hintText:
                    'e.g. "A poster for a jazz night on Friday at 8 pm, with '
                    'a big title and the venue at the bottom"',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.md),
            child: FilledButton.icon(
              onPressed: _busy ? null : _design,
              icon:
                  _designing
                      ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Generate on this page'),
            ),
          ),
          if (log.isNotEmpty) ...[
            const SectionHeader(title: 'Recent requests'),
            for (final entry in log.take(8))
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.md,
                  0,
                  Space.md,
                  Space.xs,
                ),
                child: Text(
                  '${entry.task} · ${entry.local ? 'local' : 'cloud'} · '
                  '${entry.charactersSent} chars sent'
                  '${entry.tokensIn == null ? '' : ' · ${entry.tokensIn}+${entry.tokensOut ?? 0} tokens'}',
                  style: OcxText.caption(context).copyWith(
                    color: c.textTertiary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
          ],
        ],
      ],
    );
  }
}

/// AI settings (P5.1.5): off, or a provider with endpoint, model, key,
/// temperature and length. Keys go to the OS credential store.
Future<void> showAiSettings(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _AiSettingsDialog(),
);

class _AiSettingsDialog extends ConsumerStatefulWidget {
  const _AiSettingsDialog();

  @override
  ConsumerState<_AiSettingsDialog> createState() => _AiSettingsDialogState();
}

class _AiSettingsDialogState extends ConsumerState<_AiSettingsDialog> {
  late AiProviderKind? _kind = ref.read(aiConfigProvider)?.kind;
  late final TextEditingController _endpoint = TextEditingController(
    text: ref.read(aiConfigProvider)?.endpoint ?? '',
  );
  late final TextEditingController _model = TextEditingController(
    text: ref.read(aiConfigProvider)?.model ?? '',
  );
  final TextEditingController _key = TextEditingController();
  late double _temperature = ref.read(aiConfigProvider)?.temperature ?? 0.7;
  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final kind = _kind;
    if (kind == null) return;
    final key = await ref.read(secretStoreProvider).read(aiKeyName(kind));
    if (mounted) setState(() => _hasKey = key != null && key.isNotEmpty);
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final kind = _kind;
    final controller = ref.read(aiConfigProvider.notifier);
    if (kind == null) {
      controller.config = null;
    } else {
      controller.config = AiConfig(
        kind: kind,
        endpoint:
            _endpoint.text.trim().isEmpty
                ? kind.defaultEndpoint
                : _endpoint.text.trim(),
        model: _model.text.trim(),
        temperature: _temperature,
      );
      if (_key.text.trim().isNotEmpty) {
        await ref
            .read(secretStoreProvider)
            .write(aiKeyName(kind), _key.text.trim());
      }
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final kind = _kind;
    return AlertDialog(
      title: const Text('AI settings'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<AiProviderKind?>(
              initialValue: kind,
              decoration: const InputDecoration(labelText: 'Provider'),
              items: [
                const DropdownMenuItem(child: Text('Off (no AI)')),
                for (final k in AiProviderKind.values)
                  DropdownMenuItem(value: k, child: Text(k.label)),
              ],
              onChanged:
                  (k) => setState(() {
                    _kind = k;
                    if (k != null) _endpoint.text = k.defaultEndpoint;
                    _hasKey = false;
                    _loadKey();
                  }),
            ),
            if (kind != null) ...[
              const SizedBox(height: Space.md),
              TextField(
                controller: _endpoint,
                decoration: const InputDecoration(labelText: 'Endpoint'),
              ),
              const SizedBox(height: Space.md),
              TextField(
                controller: _model,
                decoration: InputDecoration(
                  labelText: 'Model',
                  hintText: switch (kind) {
                    AiProviderKind.ollama => 'e.g. llama3.1',
                    AiProviderKind.anthropic => 'model id from your account',
                    AiProviderKind.openAiCompatible => 'model id',
                  },
                ),
              ),
              if (kind != AiProviderKind.ollama) ...[
                const SizedBox(height: Space.md),
                TextField(
                  controller: _key,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'API key',
                    hintText: _hasKey ? 'Saved (leave empty to keep)' : null,
                    helperText:
                        "Kept in the operating system's credential store, never "
                        'in designs or settings.',
                  ),
                ),
              ],
              const SizedBox(height: Space.md),
              Text(
                'Creativity ${_temperature.toStringAsFixed(1)}',
                style: OcxText.caption(
                  context,
                ).copyWith(color: c.textSecondary),
              ),
              Slider(
                value: _temperature,
                max: 1.5,
                divisions: 15,
                onChanged: (v) => setState(() => _temperature = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (kind != null && _hasKey)
          TextButton(
            onPressed: () async {
              await ref.read(secretStoreProvider).delete(aiKeyName(kind));
              setState(() => _hasKey = false);
            },
            child: const Text('Forget key'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
