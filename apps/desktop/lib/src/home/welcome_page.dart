import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storage/storage.dart';

import '../providers.dart';
import '../theme/ocx_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/formatting.dart';

/// First launch (ux-spec.md "Onboarding"): privacy explanation and choosing
/// the local projects folder (P1.1.7). No account is ever required.
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  String? _error;
  bool _busy = false;

  Future<void> _run(Future<ProjectsFolderProblem?> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final problem = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = problem == null ? null : describeFolderProblem(problem);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const Expanded(flex: 11, child: _BrandPanel()),
          Expanded(
            flex: 9,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Space.xxxl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _setup(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _setup(BuildContext context) {
    final theme = Theme.of(context);
    final ocx = context.ocx;
    final suggested = ref.watch(suggestedProjectsFolderProvider);
    final controller = ref.read(projectsFolderProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Welcome to OpenCanvasX', style: theme.textTheme.headlineMedium),
        const SizedBox(height: Space.sm),
        Text(
          "Let's choose where your designs will be saved. It takes one click.",
          style: theme.textTheme.bodyLarge?.copyWith(color: ocx.subtleText),
        ),
        const SizedBox(height: Space.xxl),
        Text(
          'YOUR DESIGNS FOLDER',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: Space.md),
        suggested.when(
          data: (path) => _FolderOption(path: path),
          loading:
              () => const SizedBox(
                height: 76,
                child: Center(child: CircularProgressIndicator()),
              ),
          error: (_, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: Space.lg),
        SizedBox(
          height: 46,
          child: FilledButton.icon(
            onPressed:
                _busy || !suggested.hasValue
                    ? null
                    : () => _run(
                      () =>
                          controller.use(suggested.requireValue, create: true),
                    ),
            icon:
                _busy
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.check_rounded),
            label: const Text('Use this folder'),
          ),
        ),
        const SizedBox(height: Space.sm + 2),
        SizedBox(
          height: 46,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(controller.choose),
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Choose a different folder…'),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: Space.lg),
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: Space.xxl),
        Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 20, color: ocx.success),
              const SizedBox(width: Space.md),
              Expanded(
                child: Text(
                  'Your designs stay on this computer as .opencanvasx files. '
                  'No account, no uploads, no tracking — you can move or back '
                  'them up like any other file.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FolderOption extends StatelessWidget {
  const _FolderOption({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ocx = context.ocx;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: ocx.selectedFill,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: ocx.selection, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(Icons.folder_rounded, color: theme.colorScheme.primary),
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
                        'Documents › OpenCanvasX',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Text(
                        'Recommended',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Tooltip(
                  message: path,
                  child: Text(
                    shortenPath(path, maxLength: 46),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Left half: brand gradient, product promise, decorative shapes.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const white = Colors.white;
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: Brand.heroGradient),
      child: Stack(
        children: [
          const Positioned(
            right: -80,
            top: -60,
            child: _Circle(size: 300, alpha: 0.10),
          ),
          const Positioned(
            left: -60,
            bottom: -90,
            child: _Circle(size: 260, alpha: 0.08),
          ),
          Positioned(
            right: 64,
            bottom: 120,
            child: Transform.rotate(
              angle: 0.22,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.xxxl + 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandLockup(color: white),
                const Spacer(),
                Text(
                  'Design anything.\nKeep everything.',
                  style: theme.textTheme.displaySmall?.copyWith(color: white),
                ),
                const SizedBox(height: Space.lg),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Text(
                    'A free, open-source design studio that works on your '
                    'computer — no subscription, no watermark, no cloud required.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: white.withValues(alpha: 0.88),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: Space.xxl),
                for (final (icon, text) in const [
                  (Icons.wifi_off_rounded, 'Works fully offline'),
                  (Icons.person_off_outlined, 'No account or sign-in, ever'),
                  (
                    Icons.folder_zip_outlined,
                    'Open .opencanvasx files that you own',
                  ),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.md),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(Radii.sm),
                          ),
                          child: Icon(icon, size: 18, color: white),
                        ),
                        const SizedBox(width: Space.md),
                        Text(
                          text,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: white,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                Text(
                  'Free & open source · Apache-2.0',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
}
