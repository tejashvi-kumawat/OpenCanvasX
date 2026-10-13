import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/ocx_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/formatting.dart';

enum _Choice { suggested, other }

/// First launch (ux-spec.md "Onboarding"): what OpenCanvasX is, where
/// designs are saved (P1.1.7) and the privacy promise. No account, ever.
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  _Choice _choice = _Choice.suggested;
  String? _error;
  bool _busy = false;
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    ref.read(profileNameProvider.notifier).name = _name.text;
    final controller = ref.read(projectsFolderProvider.notifier);
    setState(() {
      _busy = true;
      _error = null;
    });
    final problem =
        _choice == _Choice.suggested
            ? await controller.use(
              await ref.read(suggestedProjectsFolderProvider.future),
              create: true,
            )
            : await controller.choose();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = problem == null ? null : describeFolderProblem(problem);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final suggested = ref.watch(suggestedProjectsFolderProvider);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BrandMark(size: 32),
                ),
                const SizedBox(height: Space.xl),
                Text('Welcome to OpenCanvasX', style: OcxText.display(context)),
                const SizedBox(height: Space.sm),
                Text(
                  'A free, open-source design app that works entirely on your '
                  'computer.',
                  style: OcxText.body(
                    context,
                  ).copyWith(color: c.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: Space.xl),
                Container(
                  padding: const EdgeInsets.all(Space.lg),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'What should we call you?',
                        style: OcxText.title(context),
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        'Optional. Saved as the author of your designs; it '
                        'stays on this computer.',
                        style: OcxText.body(
                          context,
                        ).copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(height: Space.sm),
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          hintText: 'Your name',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: Space.lg),
                      Text(
                        'Where should your designs be saved?',
                        style: OcxText.title(context),
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        'Each design is a .opencanvasx file in this folder. You '
                        'can change it later.',
                        style: OcxText.body(
                          context,
                        ).copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(height: Space.md),
                      _Option(
                        selected: _choice == _Choice.suggested,
                        title: 'Documents › OpenCanvasX',
                        subtitle: suggested.when(
                          data: (p) => shortenPath(p, maxLength: 44),
                          loading: () => '…',
                          error: (_, _) => '',
                        ),
                        badge: 'Recommended',
                        onTap:
                            () => setState(() => _choice = _Choice.suggested),
                      ),
                      const SizedBox(height: Space.sm),
                      _Option(
                        selected: _choice == _Choice.other,
                        title: 'Another folder',
                        subtitle:
                            'Choose any folder on this computer or a drive',
                        onTap: () => setState(() => _choice = _Choice.other),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: Space.md),
                        Text(
                          _error!,
                          style: OcxText.body(
                            context,
                          ).copyWith(color: c.danger),
                        ),
                      ],
                      const SizedBox(height: Space.lg),
                      SizedBox(
                        height: 36,
                        child: FilledButton(
                          onPressed:
                              _busy || !suggested.hasValue ? null : _continue,
                          child: Text(
                            _choice == _Choice.suggested
                                ? 'Continue'
                                : 'Choose folder…',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.xl),
                for (final (icon, text) in const [
                  (Icons.wifi_off_outlined, 'Works fully offline'),
                  (
                    Icons.person_off_outlined,
                    'No account, no uploads, no tracking',
                  ),
                  (Icons.description_outlined, 'Open file format that you own'),
                  (
                    Icons.cloud_outlined,
                    'Only what you turn on goes online: template sources you '
                        'add and an AI provider you set up, always asked first',
                  ),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: Row(
                      children: [
                        Icon(icon, size: Chrome.icon, color: c.textSecondary),
                        const SizedBox(width: Space.sm),
                        Flexible(
                          child: Text(
                            text,
                            style: OcxText.body(
                              context,
                            ).copyWith(color: c.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    return Material(
      color: selected ? c.accentSubtle : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        side: BorderSide(color: selected ? c.accent : c.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: Chrome.icon,
                color: selected ? c.accent : c.textTertiary,
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OcxText.bodyStrong(context),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: Space.sm),
                          Text(
                            badge!,
                            style: OcxText.caption(
                              context,
                            ).copyWith(color: c.accent),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OcxText.caption(context).copyWith(
                        color: c.textTertiary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
