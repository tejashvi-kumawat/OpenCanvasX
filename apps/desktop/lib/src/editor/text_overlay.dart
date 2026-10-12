import 'dart:math' as math;

import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:renderer/renderer.dart';

import '../theme/ocx_theme.dart';

/// Inline text editor drawn exactly over a text object (P1.5.1).
///
/// [matrix] maps the object's local box to the canvas, so the editor follows
/// zoom and rotation. Styling mirrors `renderer.layoutText`, so text does
/// not jump when editing starts or ends.
class TextEditOverlay extends StatefulWidget {
  const TextEditOverlay({
    required this.object,
    required this.matrix,
    required this.onChanged,
    required this.onDone,
    super.key,
  });

  final DesignObject object;
  final Matrix4 matrix;
  final ValueChanged<String> onChanged;
  final VoidCallback onDone;

  @override
  State<TextEditOverlay> createState() => _TextEditOverlayState();
}

class _TextEditOverlayState extends State<TextEditOverlay> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode(debugLabel: 'text edit');
  bool _done = false;

  TextPayload get _payload => widget.object.payload as TextPayload;

  @override
  void initState() {
    super.initState();
    final text = _payload.text;
    _controller = TextEditingController(text: text)
      ..selection = TextSelection(baseOffset: 0, extentOffset: text.length);
    _focus.addListener(() {
      if (!_focus.hasFocus) _finish();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final payload = _payload;
    final t = widget.object.transform;
    final fill = widget.object.style?.fill;
    final color =
        fill == null ? context.ocx.text : toUiColor(fill.representative);
    final style = TextStyle(
      fontFamily: payload.fontFamily ?? defaultFontFamily,
      fontSize: payload.fontSize,
      height: payload.lineHeight,
      letterSpacing: payload.letterSpacing,
      fontWeight: FontWeight.values[(payload.fontWeight ~/ 100) - 1],
      fontStyle: payload.italic ? FontStyle.italic : FontStyle.normal,
      color: color,
    );
    // Auto-width text grows as you type; give the field room so it never
    // wraps before the box catches up.
    final width =
        payload.sizing == TextSizing.autoWidth
            ? math.max<double>(t.width, 1) + payload.fontSize * 4
            : math.max<double>(t.width, 1);
    return Positioned(
      left: 0,
      top: 0,
      child: Transform(
        transform: widget.matrix,
        child: SizedBox(
          width: width,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): _finish,
            },
            child: EditableText(
              controller: _controller,
              focusNode: _focus,
              style: style,
              strutStyle: StrutStyle.disabled,
              textAlign: switch (payload.align) {
                TextAlignment.left => TextAlign.left,
                TextAlignment.center => TextAlign.center,
                TextAlignment.right => TextAlign.right,
                TextAlignment.justify => TextAlign.justify,
              },
              maxLines: null,
              cursorColor: context.ocx.accent,
              cursorWidth: math.max<double>(payload.fontSize / 24, 1),
              backgroundCursorColor: Colors.grey,
              selectionColor: context.ocx.accent.withValues(alpha: 0.25),
              keyboardType: TextInputType.multiline,
              onChanged: widget.onChanged,
              onTapOutside: (_) => _finish(),
            ),
          ),
        ),
      ),
    );
  }
}
