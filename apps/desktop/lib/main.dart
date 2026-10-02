import 'package:design_engine/design_engine.dart' as design_engine;
import 'package:flutter/material.dart';
import 'package:ods_logging/ods_logging.dart';
import 'package:ods_native_bridge/ods_native_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final log = OdsLogger(name: 'desktop', minLevel: LogLevel.debug);
  await OdsNativeBridge.init();
  log.info(
    'Open Design Studio shell starting '
    '(design_engine=${design_engine.packageVersion()}, '
    'native=${OdsNativeBridge.nativeVersion()})',
  );
  runApp(const OpenDesignStudioApp());
}

/// Phase 0 empty desktop shell — canvas and panels arrive in Phase 1.
class OpenDesignStudioApp extends StatelessWidget {
  const OpenDesignStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open Design Studio',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const _ShellScaffold(),
    );
  }
}

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Design Studio'),
      ),
      body: Center(
        child: Text(
          'Canvas area (Phase 1)',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
