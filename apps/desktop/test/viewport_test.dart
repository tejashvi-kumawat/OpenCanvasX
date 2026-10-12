import 'dart:io';

import 'package:document_model/document_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencanvasx/src/editor/viewport.dart';
import 'package:opencanvasx/src/widgets/formatting.dart';

void main() {
  group('layoutPages', () {
    test('stacks pages vertically, centred on x = 0', () {
      final frames = layoutPages([
        DesignPage(id: const PageId('a'), width: 1000, height: 500),
        DesignPage(id: const PageId('b'), width: 200, height: 100),
      ]);
      expect(frames[0].rect, const Rect.fromLTWH(-500, 0, 1000, 500));
      expect(
        frames[1].rect,
        const Rect.fromLTWH(-100, 500 + pageGap, 200, 100),
      );
    });

    test('physical units display at 96 px per inch', () {
      final frame =
          layoutPages([
            DesignPage(
              id: const PageId('a4'),
              width: 210,
              height: 297,
              unit: LengthUnit.mm,
              dpi: 300,
            ),
          ]).single;
      expect(frame.unitScale, closeTo(96 / 25.4, 1e-9));
      expect(frame.rect.width, closeTo(793.7, 0.1));
    });

    test('page and workspace coordinates round-trip', () {
      final frame =
          layoutPages([
            DesignPage(
              id: const PageId('a'),
              width: 100,
              height: 100,
              unit: LengthUnit.mm,
            ),
          ]).single;
      const p = Point2D(12.5, 40);
      final back = frame.toPage(frame.toWorkspace(p));
      expect(back.x, closeTo(p.x, 1e-9));
      expect(back.y, closeTo(p.y, 1e-9));
    });
  });

  group('ViewportController', () {
    late ProviderContainer container;
    ViewportController view() => container.read(viewportProvider.notifier);
    ViewportState state() => container.read(viewportProvider);

    setUp(() {
      container =
          ProviderContainer()
            ..read(viewportProvider.notifier).setSize(const Size(800, 600));
    });

    tearDown(() => container.dispose());

    test('fit centres and scales a rect with padding', () {
      view().fit(const Rect.fromLTWH(-500, 0, 1000, 500), padding: 50);
      expect(state().zoom, closeTo(0.7, 1e-9));
      expect(state().toScreen(const Offset(0, 250)), const Offset(400, 300));
      expect(state().fitted, isTrue);
    });

    test('zoomAt keeps the focal point still', () {
      const focal = Offset(200, 150);
      final before = state().toWorkspace(focal);
      view().zoomAt(focal, 2.5);
      expect(state().zoom, 2.5);
      final after = state().toWorkspace(focal);
      expect(after.dx, closeTo(before.dx, 1e-9));
      expect(after.dy, closeTo(before.dy, 1e-9));
    });

    test('zoom is clamped', () {
      view().zoomAt(Offset.zero, 1000);
      expect(state().zoom, maxZoom);
      view().zoomAt(Offset.zero, 0.00001);
      expect(state().zoom, minZoom);
    });

    test('zoomIn and zoomOut step through common levels', () {
      view().zoomIn();
      expect(state().zoom, 1.25);
      view()
        ..zoomOut()
        ..zoomOut();
      expect(state().zoom, 0.75);
    });

    test('reveal centres a rect without zooming', () {
      view()
        ..setZoom(2)
        ..reveal(const Rect.fromLTWH(1000, 1000, 100, 100));
      expect(state().zoom, 2);
      expect(
        state().toScreen(const Offset(1050, 1050)),
        const Offset(400, 300),
      );
    });

    test('reset forgets the fit but keeps the size', () {
      view()
        ..fit(const Rect.fromLTWH(0, 0, 10, 10))
        ..reset();
      expect(state().fitted, isFalse);
      expect(state().size, const Size(800, 600));
    });
  });

  group('formatting', () {
    final now = DateTime(2026, 10, 12, 15);

    test('relativeTime', () {
      expect(relativeTime(now, now: now), 'just now');
      expect(
        relativeTime(now.subtract(const Duration(minutes: 5)), now: now),
        '5 min ago',
      );
      expect(
        relativeTime(now.subtract(const Duration(hours: 3)), now: now),
        '3 h ago',
      );
      expect(relativeTime(DateTime(2026, 10, 11, 20), now: now), 'Yesterday');
      expect(relativeTime(DateTime(2026, 3, 2), now: now), '2 Mar 2026');
    });

    test('sizeLabel', () {
      expect(sizeLabel(1080, 1080, 'px'), '1080 × 1080 px');
      expect(sizeLabel(8.5, 11, 'in'), '8.5 × 11 in');
    });

    test(
      'shortenPath keeps short paths and elides the middle of long ones',
      () {
        expect(shortenPath('short', maxLength: 20), 'short');
        final long = [
          'C:',
          'Users',
          'someone',
          'Documents',
          'Work',
          'Clients',
          'OpenCanvasX',
        ].join(Platform.pathSeparator);
        final short = shortenPath(long, maxLength: 30);
        expect(short.length, lessThanOrEqualTo(32));
        expect(short, contains('…'));
        expect(short, endsWith('OpenCanvasX'));
      },
    );
  });
}
