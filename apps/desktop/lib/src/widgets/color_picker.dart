import 'dart:math' as math;

import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:renderer/renderer.dart' show toUiColor;

import '../theme/ocx_theme.dart';

/// Palettes and tools the colour picker offers, provided by the screen
/// that hosts colour rows (the inspector).
class ColorPickerScope extends InheritedWidget {
  const ColorPickerScope({
    required super.child,
    this.documentColors = const [],
    this.customColors = const [],
    this.onSaveColor,
    this.onEyedropper,
    super.key,
  });

  /// Colours used in the open design, most used first.
  final List<ArgbColor> documentColors;

  /// The user's saved colours ("My colours", P1.7.2).
  final List<ArgbColor> customColors;
  final ValueChanged<ArgbColor>? onSaveColor;

  /// Starts picking a colour from the canvas; the callback receives it.
  final void Function(ValueChanged<ArgbColor> onPicked)? onEyedropper;

  static ColorPickerScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ColorPickerScope>();

  @override
  bool updateShouldNotify(ColorPickerScope oldWidget) =>
      oldWidget.documentColors != documentColors ||
      oldWidget.customColors != customColors;
}

/// Built-in swatches: neutrals, then a hue ramp.
final List<ArgbColor> defaultSwatches = [
  for (final v in const [
    0xFF000000, 0xFF3A3F4A, 0xFF6B7280, 0xFFA3A9B5, 0xFFD8DBE2, 0xFFFFFFFF, //
    0xFFE5484D, 0xFFF76B15, 0xFFFFC53D, 0xFF46A758, 0xFF12A594, 0xFF3256F0,
    0xFF6E56CF, 0xFFD6409F, 0xFFFFE3E0, 0xFFFFF4E4, 0xFFE6F6EB, 0xFFDDEBFF,
  ])
    ArgbColor(v),
];

/// How the numeric fields show the colour.
enum ColorModel { hex, rgb, hsl, hsv }

/// Colour picker (P1.7.1): saturation/value square, hue and alpha sliders,
/// HEX / RGB / HSL / HSV fields, eyedropper and swatches (P1.7.2).
class ColorPickerPanel extends StatefulWidget {
  const ColorPickerPanel({
    required this.color,
    required this.onChanged,
    this.onChangeEnd,
    super.key,
  });

  final ArgbColor color;

  /// Called continuously while dragging.
  final ValueChanged<ArgbColor> onChanged;

  /// Called when a drag ends or a field is committed (one undo step).
  final ValueChanged<ArgbColor>? onChangeEnd;

  @override
  State<ColorPickerPanel> createState() => _ColorPickerPanelState();
}

class _ColorPickerPanelState extends State<ColorPickerPanel> {
  late HSVColor _hsv = HSVColor.fromColor(toUiColor(widget.color));
  ColorModel _model = ColorModel.hex;

  @override
  void didUpdateWidget(ColorPickerPanel old) {
    super.didUpdateWidget(old);
    if (_argb(_hsv) != widget.color.value) {
      _hsv = HSVColor.fromColor(toUiColor(widget.color));
    }
  }

  static int _argb(HSVColor hsv) => hsv.toColor().toARGB32();

  void _set(HSVColor hsv, {bool end = false}) {
    setState(() => _hsv = hsv);
    final color = ArgbColor(_argb(hsv));
    widget.onChanged(color);
    if (end) widget.onChangeEnd?.call(color);
  }

  void _setColor(ArgbColor color) =>
      _set(HSVColor.fromColor(toUiColor(color)), end: true);

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final scope = ColorPickerScope.of(context);
    final color = ArgbColor(_argb(_hsv));
    return SizedBox(
      width: 240,
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SvSquare(
              width: _inner,
              hsv: _hsv,
              onChanged: _set,
              onEnd: () => widget.onChangeEnd?.call(color),
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                if (scope?.onEyedropper case final pick?)
                  IconButton(
                    tooltip: 'Pick a colour from the canvas',
                    iconSize: Chrome.icon,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => pick(_setColor),
                    icon: const Icon(Icons.colorize_outlined),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _Slider(
                        width: _inner - (scope?.onEyedropper == null ? 0 : 40),
                        value: _hsv.hue / 360,
                        track: _hueTrack,
                        thumb: HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
                        semantics: 'Hue',
                        onChanged: (v) => _set(_hsv.withHue(v * 360)),
                        onEnd: () => widget.onChangeEnd?.call(color),
                      ),
                      const SizedBox(height: Space.sm),
                      _Slider(
                        width: _inner - (scope?.onEyedropper == null ? 0 : 40),
                        value: _hsv.alpha,
                        track: [
                          _hsv.toColor().withValues(alpha: 0),
                          _hsv.toColor().withValues(alpha: 1),
                        ],
                        checker: true,
                        thumb: _hsv.toColor(),
                        semantics: 'Opacity',
                        onChanged: (v) => _set(_hsv.withAlpha(v)),
                        onEnd: () => widget.onChangeEnd?.call(color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                SizedBox(
                  width: 64,
                  child: DropdownButton<ColorModel>(
                    value: _model,
                    isDense: true,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    style: OcxText.body(context),
                    items: [
                      for (final m in ColorModel.values)
                        DropdownMenuItem(
                          value: m,
                          child: Text(m.name.toUpperCase()),
                        ),
                    ],
                    onChanged: (m) => setState(() => _model = m ?? _model),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: _ColorFields(
                    key: ValueKey((_model, color.value)),
                    model: _model,
                    color: color,
                    onChanged: _setColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            _SwatchGroup(
              title: 'Default',
              colors: defaultSwatches,
              selected: color,
              onPick: (s) => _setColor(_withAlpha(s, color.alpha)),
            ),
            if (scope != null && scope.documentColors.isNotEmpty)
              _SwatchGroup(
                title: 'In this design',
                colors: scope.documentColors,
                selected: color,
                onPick: _setColor,
              ),
            if (scope?.onSaveColor != null)
              _SwatchGroup(
                title: 'My colours',
                colors: scope!.customColors,
                selected: color,
                onPick: _setColor,
                trailing: Tooltip(
                  message: 'Save this colour',
                  child: InkWell(
                    onTap: () => scope.onSaveColor!(color),
                    borderRadius: BorderRadius.circular(Radii.xs),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        border: Border.all(color: c.borderStrong),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Icon(Icons.add, size: 14, color: c.textSecondary),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Content width: 240 minus 12 px padding on each side.
  static const double _inner = 216;

  static ArgbColor _withAlpha(ArgbColor c, int alpha) =>
      ArgbColor((alpha << 24) | (c.value & 0xFFFFFF));

  static final _hueTrack = [
    for (var h = 0; h <= 360; h += 60)
      HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor(),
  ];
}

/// Saturation (x) × value (y) square for the current hue.
class _SvSquare extends StatelessWidget {
  const _SvSquare({
    required this.width,
    required this.hsv,
    required this.onChanged,
    required this.onEnd,
  });

  final double width;
  final HSVColor hsv;
  final void Function(HSVColor hsv, {bool end}) onChanged;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final size = Size(width, 150);
    void update(Offset p) => onChanged(
      hsv
          .withSaturation((p.dx / size.width).clamp(0.0, 1.0))
          .withValue(1 - (p.dy / size.height).clamp(0.0, 1.0)),
    );
    return Semantics(
      label: 'Saturation and brightness',
      child: GestureDetector(
        onPanDown: (d) => update(d.localPosition),
        onPanUpdate: (d) => update(d.localPosition),
        onPanEnd: (_) => onEnd(),
        onTapUp: (_) => onEnd(),
        child: CustomPaint(size: size, painter: _SvPainter(hsv)),
      ),
    );
  }
}

class _SvPainter extends CustomPainter {
  _SvPainter(this.hsv);

  final HSVColor hsv;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas
      ..save()
      ..clipRRect(rrect)
      ..drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white,
              HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
            ],
          ).createShader(rect),
      )
      ..drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black],
          ).createShader(rect),
      )
      ..restore();
    final p = Offset(
      hsv.saturation * size.width,
      (1 - hsv.value) * size.height,
    );
    canvas
      ..drawCircle(
        p,
        7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.white,
      )
      ..drawCircle(
        p,
        8.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.black26,
      );
  }

  @override
  bool shouldRepaint(_SvPainter old) => old.hsv != hsv;
}

/// A 12 px gradient track with a round thumb (hue, opacity, …).
class _Slider extends StatelessWidget {
  const _Slider({
    required this.width,
    required this.value,
    required this.track,
    required this.thumb,
    required this.semantics,
    required this.onChanged,
    required this.onEnd,
    this.checker = false,
  });

  final double width;
  final double value;
  final List<Color> track;
  final Color thumb;
  final String semantics;
  final ValueChanged<double> onChanged;
  final VoidCallback onEnd;
  final bool checker;

  @override
  Widget build(BuildContext context) {
    void update(Offset p) => onChanged((p.dx / width).clamp(0.0, 1.0));
    return Semantics(
      label: semantics,
      value: '${(value * 100).round()}%',
      child: GestureDetector(
        onPanDown: (d) => update(d.localPosition),
        onPanUpdate: (d) => update(d.localPosition),
        onPanEnd: (_) => onEnd(),
        onTapUp: (_) => onEnd(),
        child: CustomPaint(
          size: Size(width, 14),
          painter: _TrackPainter(value, track, thumb, checker: checker),
        ),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter(this.value, this.track, this.thumb, {required this.checker});

  final double value;
  final List<Color> track;
  final Color thumb;
  final bool checker;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 1, size.width, size.height - 2);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas
      ..save()
      ..clipRRect(rrect);
    if (checker) {
      canvas.drawRect(rect, Paint()..color = Colors.white);
      final grey = Paint()..color = const Color(0xFFDADDE3);
      for (var x = 0.0; x < size.width; x += 6) {
        for (var y = 0.0; y < size.height; y += 6) {
          if (((x + y) / 6).round().isEven) {
            canvas.drawRect(Rect.fromLTWH(x, y, 6, 6), grey);
          }
        }
      }
    }
    canvas
      ..drawRect(
        rect,
        Paint()..shader = LinearGradient(colors: track).createShader(rect),
      )
      ..restore();
    final x = (value * size.width).clamp(6.0, size.width - 6);
    final center = Offset(x, size.height / 2);
    canvas
      ..drawCircle(center, 7, Paint()..color = Colors.white)
      ..drawCircle(center, 5, Paint()..color = thumb.withValues(alpha: 1))
      ..drawCircle(
        center,
        7,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.black26,
      );
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.value != value || old.thumb != thumb || old.track != track;
}

/// Number fields for the chosen colour model; commits on Enter or blur.
class _ColorFields extends StatelessWidget {
  const _ColorFields({
    required this.model,
    required this.color,
    required this.onChanged,
    super.key,
  });

  final ColorModel model;
  final ArgbColor color;
  final ValueChanged<ArgbColor> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = toUiColor(color);
    final alpha = (color.alpha / 255 * 100).round();
    final (labels, values, maxes) = switch (model) {
      ColorModel.hex => (const <String>[], const <num>[], const <num>[]),
      ColorModel.rgb => (
        const ['R', 'G', 'B'],
        [color.red, color.green, color.blue],
        const [255, 255, 255],
      ),
      ColorModel.hsl => () {
        final hsl = HSLColor.fromColor(ui);
        return (
          const ['H', 'S', 'L'],
          [
            hsl.hue.round(),
            (hsl.saturation * 100).round(),
            (hsl.lightness * 100).round(),
          ],
          const [360, 100, 100],
        );
      }(),
      ColorModel.hsv => () {
        final hsv = HSVColor.fromColor(ui);
        return (
          const ['H', 'S', 'V'],
          [
            hsv.hue.round(),
            (hsv.saturation * 100).round(),
            (hsv.value * 100).round(),
          ],
          const [360, 100, 100],
        );
      }(),
    };

    ArgbColor fromValues(List<num> v) {
      final a = color.alpha / 255;
      final c = switch (model) {
        ColorModel.rgb => Color.fromARGB(
          color.alpha,
          v[0].toInt(),
          v[1].toInt(),
          v[2].toInt(),
        ),
        ColorModel.hsl =>
          HSLColor.fromAHSL(
            a,
            v[0].toDouble(),
            v[1] / 100,
            v[2] / 100,
          ).toColor(),
        ColorModel.hsv =>
          HSVColor.fromAHSV(
            a,
            v[0].toDouble(),
            v[1] / 100,
            v[2] / 100,
          ).toColor(),
        ColorModel.hex => ui,
      };
      return ArgbColor(c.toARGB32());
    }

    if (model == ColorModel.hex) {
      return _Field(
        initial:
            color.value
                .toRadixString(16)
                .padLeft(8, '0')
                .substring(2)
                .toUpperCase(),
        prefix: '#',
        hex: true,
        onSubmit: (text) {
          final cleaned = text.replaceFirst('#', '');
          if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleaned)) return;
          onChanged(
            ArgbColor((color.alpha << 24) | int.parse(cleaned, radix: 16)),
          );
        },
        trailing: '$alpha%',
      );
    }
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Expanded(
            child: _Field(
              initial: '${values[i]}',
              prefix: labels[i],
              onSubmit: (text) {
                final n = num.tryParse(text);
                if (n == null) return;
                final next = [...values]..[i] = n.clamp(0, maxes[i]);
                onChanged(fromValues(next));
              },
            ),
          ),
          if (i < 2) const SizedBox(width: Space.xs),
        ],
      ],
    );
  }
}

class _Field extends StatefulWidget {
  const _Field({
    required this.initial,
    required this.prefix,
    required this.onSubmit,
    this.hex = false,
    this.trailing,
  });

  final String initial;
  final String prefix;
  final ValueChanged<String> onSubmit;
  final bool hex;
  final String? trailing;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onSubmit(_text.text.trim());
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _text,
    focusNode: _focus,
    style: OcxText.body(context),
    inputFormatters: [
      if (widget.hex)
        FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]'))
      else
        FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(widget.hex ? 7 : 3),
    ],
    onSubmitted: (v) => widget.onSubmit(v.trim()),
    decoration: InputDecoration(
      prefixText: '${widget.prefix} ',
      suffixText: widget.trailing,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
    ),
  );
}

class _SwatchGroup extends StatelessWidget {
  const _SwatchGroup({
    required this.title,
    required this.colors,
    required this.selected,
    required this.onPick,
    this.trailing,
  });

  final String title;
  final List<ArgbColor> colors;
  final ArgbColor selected;
  final ValueChanged<ArgbColor> onPick;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: OcxText.caption(context).copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Space.xs),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final color in colors.take(18))
                Tooltip(
                  message: '#${hexColor(color)}',
                  waitDuration: const Duration(milliseconds: 500),
                  child: InkWell(
                    onTap: () => onPick(color),
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: toUiColor(color),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color:
                              color.value == selected.value
                                  ? c.accent
                                  : c.borderStrong,
                          width: color.value == selected.value ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
              if (trailing case final t?) t,
            ],
          ),
        ],
      ),
    );
  }
}

/// `RRGGBB` (upper case) of [c].
String hexColor(ArgbColor c) =>
    (c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

/// WCAG relative luminance of [c] (P1.7.4).
double relativeLuminance(ArgbColor c) {
  double channel(int v) {
    final s = v / 255;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(c.red) +
      0.7152 * channel(c.green) +
      0.0722 * channel(c.blue);
}

/// WCAG contrast ratio between two opaque colours (1–21).
double contrastRatio(ArgbColor a, ArgbColor b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
