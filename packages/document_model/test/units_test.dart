import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

void main() {
  group('convertLength', () {
    double convert(double v, LengthUnit from, LengthUnit to, [double? dpi]) =>
        convertLength(v, from: from, to: to, dpi: dpi ?? defaultDpi);

    test('physical units use exact ratios', () {
      expect(convert(1, LengthUnit.inch, LengthUnit.pt), 72);
      expect(convert(1, LengthUnit.inch, LengthUnit.mm), closeTo(25.4, 1e-9));
      expect(convert(1, LengthUnit.inch, LengthUnit.cm), closeTo(2.54, 1e-9));
      expect(convert(10, LengthUnit.mm, LengthUnit.cm), closeTo(1, 1e-9));
      expect(convert(72, LengthUnit.pt, LengthUnit.inch), closeTo(1, 1e-9));
    });

    test('pixels depend on dpi', () {
      expect(convert(96, LengthUnit.px, LengthUnit.inch), 1);
      expect(
        convert(1, LengthUnit.inch, LengthUnit.px, 300),
        closeTo(300, 1e-9),
      );
      expect(
        convert(210, LengthUnit.mm, LengthUnit.px, 300),
        closeTo(2480.31, 0.01),
      );
      expect(convert(96, LengthUnit.px, LengthUnit.pt), closeTo(72, 1e-9));
    });

    test('same unit is identity', () {
      expect(convert(12.5, LengthUnit.mm, LengthUnit.mm), 12.5);
    });

    test('round-trips through every unit', () {
      for (final from in LengthUnit.values) {
        for (final to in LengthUnit.values) {
          final there = convert(123.456, from, to, 150);
          expect(
            convert(there, to, from, 150),
            closeTo(123.456, 1e-9),
            reason: '${from.symbol} -> ${to.symbol}',
          );
        }
      }
    });

    test('rejects non-finite values and non-positive dpi', () {
      expect(
        () => convert(double.nan, LengthUnit.mm, LengthUnit.pt),
        throwsArgumentError,
      );
      expect(
        () => convert(1, LengthUnit.px, LengthUnit.mm, 0),
        throwsArgumentError,
      );
    });
  });

  test('fromSymbol parses file-format symbols', () {
    expect(LengthUnit.fromSymbol('in'), LengthUnit.inch);
    expect(LengthUnit.fromSymbol('mm'), LengthUnit.mm);
    expect(LengthUnit.fromSymbol('inch'), isNull);
  });

  group('DesignPage sizes', () {
    final a4 = DesignPage(
      id: const PageId('a4'),
      width: 210,
      height: 297,
      unit: LengthUnit.mm,
    );

    test('sizeIn converts both dimensions', () {
      final inches = a4.sizeIn(LengthUnit.inch);
      expect(inches.width, closeTo(8.2677, 1e-4));
      expect(inches.height, closeTo(11.6929, 1e-4));
    });

    test('pixelSizeAt rounds to whole pixels', () {
      expect(a4.pixelSizeAt(300), (width: 2480, height: 3508));
      expect(a4.pixelSizeAt(72), (width: 595, height: 842));
    });

    test('pixel pages scale with export dpi relative to page dpi', () {
      final square = DesignPage(
        id: const PageId('sq'),
        width: 1080,
        height: 1080,
      );
      expect(square.pixelSizeAt(96), (width: 1080, height: 1080));
      expect(square.pixelSizeAt(192), (width: 2160, height: 2160));
    });

    test('pixelSizeAt is at least 1x1 and rejects bad dpi', () {
      final tiny = DesignPage(
        id: const PageId('t'),
        width: 0.1,
        height: 0.1,
        unit: LengthUnit.mm,
      );
      expect(tiny.pixelSizeAt(72), (width: 1, height: 1));
      expect(() => tiny.pixelSizeAt(0), throwsArgumentError);
    });
  });
}
