import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:renderer/renderer.dart' show toUiColor;

import '../theme/ocx_theme.dart';
import '../widgets/controls.dart';
import '../widgets/number_field.dart';

/// Fill kinds offered in the inspector.
enum FillKind { solid, linear, radial }

/// Edits a fill (P1.7.1, P1.7.3): solid colour, or a linear/radial
/// gradient with draggable stops, the selected stop's colour and the
/// angle. [onPreview] shows changes live (e.g. while dragging);
/// [onChanged] commits them.
class FillEditor extends StatefulWidget {
  const FillEditor({
    required this.fill,
    required this.onChanged,
    required this.onRemove,
    this.onPreview,
    super.key,
  });

  final Fill fill;
  final ValueChanged<Fill> onChanged;
  final ValueChanged<Fill>? onPreview;
  final VoidCallback onRemove;

  @override
  State<FillEditor> createState() => _FillEditorState();
}

class _FillEditorState extends State<FillEditor> {
  int _stop = 0;

  FillKind get _kind => switch (widget.fill) {
    SolidFill() => FillKind.solid,
    LinearGradientFill() => FillKind.linear,
    RadialGradientFill() => FillKind.radial,
  };

  List<GradientStop> get _stops => switch (widget.fill) {
    LinearGradientFill(:final stops) ||
    RadialGradientFill(:final stops) => stops,
    SolidFill() => const [],
  };

  Fill _withStops(List<GradientStop> stops) => switch (widget.fill) {
    final LinearGradientFill g => g.copyWith(stops: stops),
    final RadialGradientFill g => g.copyWith(stops: stops),
    final SolidFill s => s,
  };

  void _convert(FillKind kind) {
    if (kind == _kind) return;
    final base = widget.fill.representative;
    final stops =
        _stops.isNotEmpty
            ? _stops
            : [
              GradientStop(0, base),
              GradientStop(1, ArgbColor(base.value & 0x00FFFFFF)),
            ];
    _stop = 0;
    widget.onChanged(switch (kind) {
      FillKind.solid => SolidFill(base),
      FillKind.linear => LinearGradientFill(stops),
      FillKind.radial => RadialGradientFill(stops),
    });
  }

  @override
  Widget build(BuildContext context) {
    final stops = _stops;
    final selected = stops.isEmpty ? 0 : _stop.clamp(0, stops.length - 1);
    return FieldColumn(
      children: [
        Row(
          children: [
            Expanded(
              child: OcxSegmented<FillKind>(
                value: _kind,
                segments: const [
                  Segment(FillKind.solid, Icons.square, 'Solid colour'),
                  Segment(FillKind.linear, Icons.gradient, 'Linear gradient'),
                  Segment(
                    FillKind.radial,
                    Icons.blur_circular,
                    'Radial gradient',
                  ),
                ],
                onChanged: _convert,
              ),
            ),
            const SizedBox(width: Space.xs),
            OcxIconButton(
              icon: Icons.remove,
              tooltip: 'Remove fill',
              onPressed: widget.onRemove,
            ),
          ],
        ),
        if (widget.fill case SolidFill(:final color))
          ColorRow(
            color: color,
            onChanged: (c) => widget.onChanged(SolidFill(c)),
            onPreview:
                widget.onPreview == null
                    ? null
                    : (c) => widget.onPreview!(SolidFill(c)),
          )
        else ...[
          _GradientBar(
            stops: stops,
            selected: selected,
            onSelect: (i) => setState(() => _stop = i),
            onMove: (i, offset) {
              final next = [...stops]..[i] = stops[i].copyWith(offset: offset);
              widget.onPreview?.call(_withStops(next));
            },
            onMoveEnd: (i, offset) {
              final moved = stops[i].copyWith(offset: offset);
              final next = [...stops]..[i] = moved;
              final fill = _withStops(next);
              final sorted = switch (fill) {
                LinearGradientFill(:final stops) ||
                RadialGradientFill(:final stops) => stops,
                SolidFill() => const <GradientStop>[],
              };
              setState(() => _stop = sorted.indexOf(moved));
              widget.onChanged(fill);
            },
            onAdd: (offset) {
              final color = _colorAt(stops, offset);
              final added = GradientStop(offset, color);
              final fill = _withStops([...stops, added]);
              final sorted = switch (fill) {
                LinearGradientFill(:final stops) ||
                RadialGradientFill(:final stops) => stops,
                SolidFill() => const <GradientStop>[],
              };
              setState(() => _stop = sorted.indexOf(added));
              widget.onChanged(fill);
            },
          ),
          Row(
            children: [
              Expanded(
                child: ColorRow(
                  key: ValueKey(selected),
                  color: stops[selected].color,
                  onChanged:
                      (c) => widget.onChanged(
                        _withStops(
                          [...stops]
                            ..[selected] = stops[selected].copyWith(color: c),
                        ),
                      ),
                  onPreview:
                      widget.onPreview == null
                          ? null
                          : (c) => widget.onPreview!(
                            _withStops(
                              [...stops]
                                ..[selected] = stops[selected].copyWith(
                                  color: c,
                                ),
                            ),
                          ),
                ),
              ),
              const SizedBox(width: Space.xs),
              OcxIconButton(
                icon: Icons.delete_outline,
                tooltip: 'Remove stop',
                onPressed:
                    stops.length > 2
                        ? () {
                          setState(() => _stop = 0);
                          widget.onChanged(
                            _withStops([...stops]..removeAt(selected)),
                          );
                        }
                        : null,
              ),
            ],
          ),
          if (widget.fill case final LinearGradientFill g)
            FieldRow(
              children: [
                NumberField(
                  label: '°',
                  value: g.angle,
                  decimals: 0,
                  tooltip: 'Gradient angle',
                  onChanged: (v) => widget.onChanged(g.copyWith(angle: v)),
                ),
                OcxIconButton(
                  icon: Icons.rotate_90_degrees_cw_outlined,
                  tooltip: 'Rotate 90°',
                  onPressed:
                      () => widget.onChanged(g.copyWith(angle: g.angle + 90)),
                ),
              ],
            ),
        ],
      ],
    );
  }

  static ArgbColor _colorAt(List<GradientStop> stops, double offset) {
    for (var i = 1; i < stops.length; i++) {
      final a = stops[i - 1];
      final b = stops[i];
      if (offset <= b.offset) {
        final t =
            b.offset == a.offset
                ? 0.0
                : (offset - a.offset) / (b.offset - a.offset);
        final c = Color.lerp(toUiColor(a.color), toUiColor(b.color), t)!;
        return ArgbColor(c.toARGB32());
      }
    }
    return stops.last.color;
  }
}

/// The gradient preview with draggable stop markers; click empty space to
/// add a stop.
class _GradientBar extends StatelessWidget {
  const _GradientBar({
    required this.stops,
    required this.selected,
    required this.onSelect,
    required this.onMove,
    required this.onMoveEnd,
    required this.onAdd,
  });

  final List<GradientStop> stops;
  final int selected;
  final ValueChanged<int> onSelect;
  final void Function(int index, double offset) onMove;
  final void Function(int index, double offset) onMoveEnd;
  final ValueChanged<double> onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - 12;
        double offsetOf(double x) => ((x - 6) / width).clamp(0.0, 1.0);
        return SizedBox(
          height: 34,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 6,
                right: 6,
                top: 0,
                height: 16,
                child: GestureDetector(
                  onTapUp: (d) => onAdd(offsetOf(d.localPosition.dx + 6)),
                  child: Tooltip(
                    message: 'Click to add a colour stop',
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Radii.xs),
                        border: Border.all(color: c.borderStrong),
                        gradient: LinearGradient(
                          colors: [for (final s in stops) toUiColor(s.color)],
                          stops: [for (final s in stops) s.offset],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              for (final (i, stop) in stops.indexed)
                Positioned(
                  left: stop.offset * width,
                  top: 16,
                  child: _StopMarker(
                    color: stop.color,
                    selected: i == selected,
                    onTap: () => onSelect(i),
                    onDrag: (dx) {
                      onSelect(i);
                      onMove(i, (stop.offset + dx / width).clamp(0.0, 1.0));
                    },
                    onDragEnd:
                        (dx) => onMoveEnd(
                          i,
                          (stop.offset + dx / width).clamp(0.0, 1.0),
                        ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StopMarker extends StatefulWidget {
  const _StopMarker({
    required this.color,
    required this.selected,
    required this.onTap,
    required this.onDrag,
    required this.onDragEnd,
  });

  final ArgbColor color;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onDragEnd;

  @override
  State<_StopMarker> createState() => _StopMarkerState();
}

class _StopMarkerState extends State<_StopMarker> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    return GestureDetector(
      onTap: widget.onTap,
      onHorizontalDragStart: (_) => _dx = 0,
      onHorizontalDragUpdate: (d) {
        _dx += d.delta.dx;
        widget.onDrag(_dx);
      },
      onHorizontalDragEnd: (_) => widget.onDragEnd(_dx),
      child: Container(
        width: 12,
        height: 14,
        decoration: BoxDecoration(
          color: toUiColor(widget.color),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: widget.selected ? c.accent : c.borderStrong,
            width: widget.selected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}
