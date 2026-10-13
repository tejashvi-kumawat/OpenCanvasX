import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'color.dart';
import 'validation.dart';

/// Character-level formatting (P1.5.4): style overrides for the
/// characters `[start, end)` of a text. `null` fields inherit the text
/// box's style.
@immutable
final class TextRun {
  factory TextRun(
    int start,
    int end, {
    int? fontWeight,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    ArgbColor? color,
    double? fontSize,
    String? fontFamily,
  }) {
    if (start < 0 || end <= start) {
      throw ArgumentError('Invalid run [$start, $end)');
    }
    if (fontWeight != null &&
        (fontWeight < 100 || fontWeight > 900 || fontWeight % 100 != 0)) {
      throw ArgumentError.value(fontWeight, 'fontWeight');
    }
    if (fontSize != null) checkPositive(fontSize, 'fontSize');
    return TextRun._(start, end, (
      fontWeight: fontWeight,
      italic: italic,
      underline: underline,
      strikethrough: strikethrough,
      color: color,
      fontSize: fontSize,
      fontFamily: fontFamily,
    ));
  }

  const TextRun._(this.start, this.end, this.style);

  final int start;
  final int end;
  final TextRunStyle style;

  int? get fontWeight => style.fontWeight;
  bool? get italic => style.italic;
  bool? get underline => style.underline;
  bool? get strikethrough => style.strikethrough;
  ArgbColor? get color => style.color;
  double? get fontSize => style.fontSize;
  String? get fontFamily => style.fontFamily;

  /// Whether it overrides nothing.
  bool get isPlain => style == TextRunStyles.none;

  TextRun withRange(int start, int end) => TextRun._(start, end, style);

  TextRun withStyle(TextRunStyle style) => TextRun._(start, end, style);

  @override
  bool operator ==(Object other) =>
      other is TextRun &&
      other.start == start &&
      other.end == end &&
      other.style == style;

  @override
  int get hashCode => Object.hash(start, end, style);

  @override
  String toString() => 'TextRun($start, $end, $style)';
}

/// The overrides of a [TextRun]; also used as a patch (non-null fields
/// are set).
typedef TextRunStyle =
    ({
      int? fontWeight,
      bool? italic,
      bool? underline,
      bool? strikethrough,
      ArgbColor? color,
      double? fontSize,
      String? fontFamily,
    });

extension TextRunStyles on TextRunStyle {
  static const TextRunStyle none = (
    fontWeight: null,
    italic: null,
    underline: null,
    strikethrough: null,
    color: null,
    fontSize: null,
    fontFamily: null,
  );

  /// This style with [patch]'s non-null fields applied.
  TextRunStyle merge(TextRunStyle patch) => (
    fontWeight: patch.fontWeight ?? fontWeight,
    italic: patch.italic ?? italic,
    underline: patch.underline ?? underline,
    strikethrough: patch.strikethrough ?? strikethrough,
    color: patch.color ?? color,
    fontSize: patch.fontSize ?? fontSize,
    fontFamily: patch.fontFamily ?? fontFamily,
  );
}

/// A patch setting only the given fields.
TextRunStyle textRunPatch({
  int? fontWeight,
  bool? italic,
  bool? underline,
  bool? strikethrough,
  ArgbColor? color,
  double? fontSize,
  String? fontFamily,
}) => (
  fontWeight: fontWeight,
  italic: italic,
  underline: underline,
  strikethrough: strikethrough,
  color: color,
  fontSize: fontSize,
  fontFamily: fontFamily,
);

/// [runs] clipped to `[0, length)`, sorted, without plain or empty runs,
/// with touching runs of the same style merged.
List<TextRun> normalizeRuns(Iterable<TextRun> runs, int length) {
  final sorted = [
    for (final r in runs)
      if (!r.isPlain && r.start < length)
        r.withRange(r.start, math.min(r.end, length)),
  ]..sort((a, b) => a.start.compareTo(b.start));
  final out = <TextRun>[];
  for (final r in sorted) {
    if (out.isNotEmpty) {
      final last = out.last;
      if (r.start < last.end) {
        // Overlap: the later run wins from its start.
        out[out.length - 1] = last.withRange(last.start, r.start);
        if (out.last.start >= out.last.end) out.removeLast();
      } else if (r.start == last.end && r.style == last.style) {
        out[out.length - 1] = last.withRange(last.start, r.end);
        continue;
      }
    }
    out.add(r);
  }
  return [
    for (final r in out)
      if (r.end > r.start) r,
  ];
}

/// Style overrides in effect at character [index] (none outside runs).
TextRunStyle runStyleAt(List<TextRun> runs, int index) {
  for (final r in runs) {
    if (index >= r.start && index < r.end) return r.style;
  }
  return TextRunStyles.none;
}

/// [runs] with [patch] applied to `[start, end)` of a text of [length].
List<TextRun> applyRunPatch(
  List<TextRun> runs,
  int start,
  int end,
  TextRunStyle patch,
  int length,
) {
  final s = start.clamp(0, length);
  final e = end.clamp(0, length);
  if (e <= s) return normalizeRuns(runs, length);
  // Split every boundary into segments, then patch those inside.
  final cuts = <int>{0, length, s, e};
  for (final r in runs) {
    cuts
      ..add(r.start.clamp(0, length))
      ..add(r.end.clamp(0, length));
  }
  final points = cuts.toList()..sort();
  final out = <TextRun>[];
  for (var i = 0; i + 1 < points.length; i++) {
    final a = points[i];
    final b = points[i + 1];
    if (b <= a) continue;
    var style = runStyleAt(runs, a);
    if (a >= s && b <= e) style = style.merge(patch);
    if (style != TextRunStyles.none) {
      out.add(TextRun._(a, b, style));
    }
  }
  return normalizeRuns(out, length);
}

/// [runs] with the given fields reset to the box style over
/// `[start, end)` (e.g. "not bold" where the box is regular).
List<TextRun> clearRunFields(
  List<TextRun> runs,
  int start,
  int end,
  int length, {
  bool fontWeight = false,
  bool italic = false,
  bool underline = false,
  bool strikethrough = false,
  bool color = false,
  bool fontSize = false,
  bool fontFamily = false,
}) {
  final s = start.clamp(0, length);
  final e = end.clamp(0, length);
  final cuts = <int>{0, length, s, e};
  for (final r in runs) {
    cuts
      ..add(r.start.clamp(0, length))
      ..add(r.end.clamp(0, length));
  }
  final points = cuts.toList()..sort();
  final out = <TextRun>[];
  for (var i = 0; i + 1 < points.length; i++) {
    final a = points[i];
    final b = points[i + 1];
    if (b <= a) continue;
    var st = runStyleAt(runs, a);
    if (a >= s && b <= e) {
      st = (
        fontWeight: fontWeight ? null : st.fontWeight,
        italic: italic ? null : st.italic,
        underline: underline ? null : st.underline,
        strikethrough: strikethrough ? null : st.strikethrough,
        color: color ? null : st.color,
        fontSize: fontSize ? null : st.fontSize,
        fontFamily: fontFamily ? null : st.fontFamily,
      );
    }
    if (st != TextRunStyles.none) out.add(TextRun._(a, b, st));
  }
  return normalizeRuns(out, length);
}

/// [runs] adjusted after the text changed from [before] to [after]: the
/// common start and end are kept; deleted characters drop out; inserted
/// characters take the style of the character before them (typing after
/// a bold word continues in bold).
List<TextRun> shiftRunsForEdit(
  List<TextRun> runs,
  String before,
  String after,
) {
  if (runs.isEmpty || before == after) {
    return normalizeRuns(runs, after.length);
  }
  var prefix = 0;
  final maxPrefix = math.min(before.length, after.length);
  while (prefix < maxPrefix &&
      before.codeUnitAt(prefix) == after.codeUnitAt(prefix)) {
    prefix++;
  }
  var suffix = 0;
  while (suffix < before.length - prefix &&
      suffix < after.length - prefix &&
      before.codeUnitAt(before.length - 1 - suffix) ==
          after.codeUnitAt(after.length - 1 - suffix)) {
    suffix++;
  }
  final removedEnd = before.length - suffix;
  final inserted = after.length - suffix - prefix;
  final delta = after.length - before.length;

  // Typed characters take the style of the character before them, so a
  // run that starts at the edit begins after the new text and one that
  // ends there grows over it (except at the very start of the text).
  int map(int i, {required bool isEnd}) {
    if (i < prefix) return i;
    if (i <= removedEnd) {
      return !isEnd && i == 0 ? 0 : prefix + inserted;
    }
    return i + delta;
  }

  return normalizeRuns([
    for (final r in runs)
      if (map(r.end, isEnd: true) > map(r.start, isEnd: false))
        r.withRange(map(r.start, isEnd: false), map(r.end, isEnd: true)),
  ], after.length);
}
