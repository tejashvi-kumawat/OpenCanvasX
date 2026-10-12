import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ocx_theme.dart';

/// 28 px numeric input with a short prefix label inside ("X", "W", "°").
///
/// Commits on Enter or when focus leaves; ↑/↓ step by [step] (Shift ×10).
/// While focused it never overwrites what the user is typing.
class NumberField extends StatefulWidget {
  const NumberField({
    required this.value,
    required this.onChanged,
    this.label,
    this.icon,
    this.suffix,
    this.step = 1,
    this.min,
    this.max,
    this.decimals = 1,
    this.tooltip,
    super.key,
  });

  final double value;
  final ValueChanged<double> onChanged;

  /// Short prefix such as "X" or "W".
  final String? label;

  /// Prefix icon instead of [label] (e.g. rotation, corner radius).
  final IconData? icon;

  /// Unit after the number, e.g. "px" or "%".
  final String? suffix;
  final double step;
  final double? min;
  final double? max;
  final int decimals;
  final String? tooltip;

  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  late final TextEditingController _controller = TextEditingController(
    text: _format(widget.value),
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && oldWidget.value != widget.value) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _format(double v) {
    final fixed = v.toStringAsFixed(widget.decimals);
    return fixed.contains('.')
        ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
        : fixed;
  }

  double _clamp(double v) {
    var result = v;
    if (widget.min != null && result < widget.min!) result = widget.min!;
    if (widget.max != null && result > widget.max!) result = widget.max!;
    return result;
  }

  void _commit() {
    final parsed = double.tryParse(
      _controller.text.trim().replaceAll(',', '.'),
    );
    if (parsed == null || !parsed.isFinite) {
      _controller.text = _format(widget.value);
      return;
    }
    final value = _clamp(parsed);
    _controller.text = _format(value);
    if (value != widget.value) widget.onChanged(value);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final up = event.logicalKey == LogicalKeyboardKey.arrowUp;
    final down = event.logicalKey == LogicalKeyboardKey.arrowDown;
    if (!up && !down) return KeyEventResult.ignored;
    final current = double.tryParse(_controller.text) ?? widget.value;
    final step =
        widget.step * (HardwareKeyboard.instance.isShiftPressed ? 10 : 1);
    final next = _clamp(current + (up ? step : -step));
    _controller.text = _format(next);
    widget.onChanged(next);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final prefix =
        widget.icon != null
            ? Icon(widget.icon, size: 14, color: c.textTertiary)
            : (widget.label != null
                ? Text(
                  widget.label!,
                  style: OcxText.caption(
                    context,
                  ).copyWith(color: c.textTertiary),
                )
                : null);
    final field = Focus(
      onKeyEvent: _onKey,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        style: OcxText.body(context),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp('[-0-9.,]')),
        ],
        onSubmitted: (_) => _commit(),
        decoration: InputDecoration(
          prefixIcon:
              prefix == null
                  ? null
                  : SizedBox(width: 24, child: Center(child: prefix)),
          prefixIconConstraints: const BoxConstraints(minWidth: 24),
          suffixText: widget.suffix,
          contentPadding: EdgeInsets.only(
            left: prefix == null ? Space.sm : 0,
            right: Space.sm,
            top: 7,
            bottom: 7,
          ),
        ),
      ),
    );
    return widget.tooltip == null
        ? field
        : Tooltip(message: widget.tooltip, child: field);
  }
}
