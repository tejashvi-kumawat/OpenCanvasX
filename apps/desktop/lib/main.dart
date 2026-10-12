import 'package:design_engine/design_engine.dart' as design_engine;
import 'package:flutter/material.dart';
import 'package:ocx_logging/ocx_logging.dart';
import 'package:ocx_native_bridge/ocx_native_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final log = OcxLogger(name: 'desktop', minLevel: LogLevel.debug);
  await OcxNativeBridge.init();
  log.info(
    'OpenCanvasX shell starting '
    '(design_engine=${design_engine.packageVersion()}, '
    'native=${OcxNativeBridge.nativeVersion()})',
  );
  runApp(const OpenCanvasXApp());
}

/// Phase 0 empty desktop shell — canvas and panels arrive in Phase 1.
class OpenCanvasXApp extends StatelessWidget {
  const OpenCanvasXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenCanvasX',
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
        title: const Text('OpenCanvasX'),
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
