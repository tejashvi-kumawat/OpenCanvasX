import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:renderer/renderer.dart';

import '../theme/ocx_theme.dart';

/// Default palette offered in the inspector; original selection of
/// neutrals and saturated hues.
final List<ArgbColor> defaultPalette = [
  for (final v in const [
    0xFF000000, 0xFF3F4654, 0xFF9AA1AE, 0xFFFFFFFF, //
    0xFF6D4AFF, 0xFF3B82F6, 0xFF12B5C9, 0xFF10B981,
    0xFF84CC16, 0xFFF5B301, 0xFFF97316, 0xFFEF4444,
    0xFFEC4899, 0xFFA855F7, 0xFFFDE68A, 0xFFBFDBFE,
  ])
    ArgbColor(v),
];

/// Swatch grid plus hex input (P1.7.1 will add the full picker).
class ColorPicker extends StatelessWidget {
  const ColorPicker({
    required this.value,
    required this.onChanged,
    this.allowNone = false,
    super.key,
  });

  /// Current colour; `null` means "none" (only when [allowNone]).
  final ArgbColor? value;
  final ValueChanged<ArgbColor?> onChanged;
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: Space.sm - 1,
          runSpacing: Space.sm - 1,
          children: [
            if (allowNone)
              _Swatch(
                color: null,
                selected: value == null,
                onTap: () => onChanged(null),
              ),
            for (final color in defaultPalette)
              _Swatch(
                color: color,
                selected: value?.value == color.value,
                onTap: () => onChanged(color),
              ),
          ],
        ),
        const SizedBox(height: Space.sm),
        _HexField(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final ArgbColor? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ocx = context.ocx;
    final c = color;
    return Tooltip(
      message: c == null ? 'None' : _hex(c),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 28,
          height: 28,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? ocx.selection : Colors.transparent,
              width: 2,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c == null ? Colors.white : toUiColor(c),
              border: Border.all(color: ocx.border),
            ),
            child: c == null ? CustomPaint(painter: _NoneSlashPainter()) : null,
          ),
        ),
      ),
    );
  }
}

class _NoneSlashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.8),
      Offset(size.width * 0.8, size.height * 0.2),
      Paint()
        ..color = const Color(0xFFEF4444)
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(_NoneSlashPainter oldDelegate) => false;
}

String _hex(ArgbColor c) {
  String two(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${two(c.red)}${two(c.green)}${two(c.blue)}';
}

class _HexField extends StatefulWidget {
  const _HexField({required this.value, required this.onChanged});

  final ArgbColor? value;
  final ValueChanged<ArgbColor?> onChanged;

  @override
  State<_HexField> createState() => _HexFieldState();
}

class _HexFieldState extends State<_HexField> {
  late final TextEditingController _controller = TextEditingController(
    text: _text(widget.value),
  );
  final FocusNode _focus = FocusNode();

  static String _text(ArgbColor? c) => c == null ? '' : _hex(c).substring(1);

  @override
  void didUpdateWidget(_HexField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && oldWidget.value != widget.value) {
      _controller.text = _text(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String text) {
    final cleaned = text.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleaned)) {
      _controller.text = _text(widget.value);
      return;
    }
    final alpha = widget.value?.alpha ?? 0xFF;
    widget.onChanged(ArgbColor((alpha << 24) | int.parse(cleaned, radix: 16)));
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    return TextField(
      controller: _controller,
      focusNode: _focus,
      onSubmitted: _submit,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
        LengthLimitingTextInputFormatter(7),
      ],
      decoration: InputDecoration(
        hintText: 'Hex colour',
        prefixIcon: Padding(
          padding: const EdgeInsets.all(Space.sm + 1),
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: value == null ? Colors.transparent : toUiColor(value),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: context.ocx.border),
            ),
          ),
        ),
        prefixText: '#',
      ),
    );
  }
}
