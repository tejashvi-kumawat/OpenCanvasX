import 'dart:async';
import 'dart:io';

import 'package:asset_packs/asset_packs.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ocx_logging/ocx_logging.dart';
import 'package:ocx_native_bridge/ocx_native_bridge.dart';
import 'package:path_provider/path_provider.dart';
import 'package:storage/storage.dart';

import 'src/app.dart';
import 'src/providers.dart';

export 'src/app.dart' show OpenCanvasXApp;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final log = OcxLogger(name: 'desktop', minLevel: LogLevel.debug);
  await OcxNativeBridge.init();

  // Per-user data folder, e.g. %APPDATA%\OpenCanvasX\OpenCanvasX on Windows.
  final dataDir = await getApplicationSupportDirectory();
  final index = AppIndex.open(
    '${dataDir.path}${Platform.pathSeparator}index.sqlite',
  );

  // Bundled fonts register in the background; text re-lays out when
  // they arrive.
  unawaited(loadBundledFonts(rootBundle));

  log.info('OpenCanvasX starting (native=${OcxNativeBridge.nativeVersion()})');
  runApp(
    ProviderScope(
      overrides: [
        appIndexProvider.overrideWithValue(index),
        // `opencanvasx.exe design.opencanvasx` opens that design directly.
        launchFileProvider.overrideWithValue(
          args.where((a) => a.endsWith(projectFileExtension)).firstOrNull,
        ),
      ],
      child: const OpenCanvasXApp(),
    ),
  );
}
