import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renderer/renderer.dart';

Future<Uint8List> redPng() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 2),
    ui.Paint()..color = const ui.Color(0xFFFF0000),
  );
  final image = await recorder.endRecording().toImage(4, 2);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('decodes rasters asynchronously and notifies', (tester) async {
    await tester.runAsync(() async {
      final cache = MediaCache();
      var notified = 0;
      cache
        ..addListener(() => notified++)
        ..register('png', await redPng(), 'image/png');
      expect(cache.resolve('png'), isNull);
      await cache.preload([('png', null)]);
      final media = cache.resolve('png');
      expect(media, isA<RasterMedia>());
      expect((media! as RasterMedia).image.width, 4);
      expect(notified, 1);
      expect(cache.resolve('missing'), isNull);
      cache.dispose();
    });
  });

  testWidgets('parses SVG once per currentColor', (tester) async {
    await tester.runAsync(() async {
      final cache =
          MediaCache()..register(
            'svg',
            Uint8List.fromList(
              utf8.encode(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 12"> '
                '<rect width="24" height="12" fill="currentColor"/></svg>',
              ),
            ),
            'image/svg+xml',
          );
      await cache.preload([('svg', 0xFF3256F0), ('svg', null)]);
      final blue = cache.resolve('svg', currentColor: 0xFF3256F0);
      expect(blue, isA<VectorMedia>());
      expect((blue! as VectorMedia).size, const ui.Size(24, 12));
      expect(
        identical(blue, cache.resolve('svg', currentColor: 0xFF3256F0)),
        isTrue,
      );
      expect(cache.resolve('svg'), isNot(same(blue)));
      expect(cache.allBytes.keys, ['svg']);
      cache.dispose();
    });
  });

  testWidgets('undecodable bytes fail quietly', (tester) async {
    await tester.runAsync(() async {
      final cache =
          MediaCache()
            ..register('bad', Uint8List.fromList([1, 2, 3]), 'image/png');
      await cache.preload([('bad', null)]);
      expect(cache.resolve('bad'), isNull);
      cache.dispose();
    });
  });
}
