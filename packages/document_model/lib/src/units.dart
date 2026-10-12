/// Length units a page can be measured in.
///
/// Conversion between units and DPI handling arrive with P1.1.3.
enum LengthUnit {
  px('px'),
  pt('pt'),
  mm('mm'),
  cm('cm'),
  inch('in');

  const LengthUnit(this.symbol);

  /// Short label used in the UI and on disk (`in` for [inch]).
  final String symbol;
}
