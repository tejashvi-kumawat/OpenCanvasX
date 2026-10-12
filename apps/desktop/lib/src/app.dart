import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home/home_page.dart';
import 'home/open_design.dart';
import 'home/welcome_page.dart';
import 'providers.dart';
import 'theme/ocx_theme.dart';

/// Root widget. Needs a `ProviderScope` with `appIndexProvider` overridden.
class OpenCanvasXApp extends ConsumerWidget {
  const OpenCanvasXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'OpenCanvasX',
      debugShowCheckedModeBanner: false,
      theme: buildOcxTheme(Brightness.light),
      darkTheme: buildOcxTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      home: const _Root(),
    );
  }
}

/// First run shows the welcome/setup screen; afterwards, home. A design
/// passed on the command line opens once a projects folder exists.
class _Root extends ConsumerStatefulWidget {
  const _Root();

  @override
  ConsumerState<_Root> createState() => _RootState();
}

class _RootState extends ConsumerState<_Root> {
  bool _launchHandled = false;

  void _openLaunchFile() {
    final file = ref.read(launchFileProvider);
    if (_launchHandled || file == null) return;
    _launchHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) openDesign(context, ref, file);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasFolder = ref.watch(projectsFolderProvider) != null;
    if (hasFolder) _openLaunchFile();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child:
          hasFolder
              ? const HomePage(key: ValueKey('home'))
              : const WelcomePage(key: ValueKey('welcome')),
    );
  }
}
