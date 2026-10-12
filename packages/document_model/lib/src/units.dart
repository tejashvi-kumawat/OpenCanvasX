import 'validation.dart';

/// CSS reference resolution: 96 px per inch.
const double defaultDpi = 96;

/// Length units a page can be measured in.
///
/// Physical units have fixed ratios (1 in = 72 pt = 25.4 mm = 2.54 cm);
/// pixels depend on a DPI.
enum LengthUnit {
  px('px'),
  pt('pt'),
  mm('mm'),
  cm('cm'),
  inch('in');

  const LengthUnit(this.symbol);

  /// Short label used in the UI and on disk (`in` for [inch]).
  final String symbol;

  /// Size of one unit in inches; [dpi] is only used for [px].
  double inchesPerUnit({double dpi = defaultDpi}) => switch (this) {
    LengthUnit.px => 1 / dpi,
    LengthUnit.pt => 1 / 72,
    LengthUnit.mm => 1 / 25.4,
    LengthUnit.cm => 1 / 2.54,
    LengthUnit.inch => 1,
  };

  /// Looks up a unit by its [symbol]; `null` if unknown.
  static LengthUnit? fromSymbol(String symbol) {
    for (final unit in values) {
      if (unit.symbol == symbol) return unit;
    }
    return null;
  }
}

/// Converts [value] between units. [dpi] relates pixels to physical units.
double convertLength(
  double value, {
  required LengthUnit from,
  required LengthUnit to,
  double dpi = defaultDpi,
}) {
  checkFinite(value, 'value');
  checkPositive(dpi, 'dpi');
  if (from == to) return value;
  return value * from.inchesPerUnit(dpi: dpi) / to.inchesPerUnit(dpi: dpi);
}
