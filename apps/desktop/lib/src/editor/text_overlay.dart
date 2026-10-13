import 'dart:math' as math;

import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:renderer/renderer.dart';

import '../theme/ocx_theme.dart';
import 'editor_controller.dart' show TextToggle;

/// A text controller that paints character runs (P1.5.4) and keeps them
/// in step with typing.
class RichTextEditingController extends TextEditingController {
  RichTextEditingController({required super.text, required this.runs});

  /// The runs for the current text.
  List<TextRun> runs;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final composing = withComposing && value.isComposingRangeValid;
    if (runs.isEmpty || composing) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final children = <TextSpan>[];
    var at = 0;
    for (final run in runs) {
      if (run.start >= text.length) break;
      final end = math.min(run.end, text.length);
      if (run.start > at) {
        children.add(TextSpan(text: text.substring(at, run.start)));
      }
      children.add(
        TextSpan(
          text: text.substring(run.start, end),
          style: runFlutterStyle(run),
        ),
      );
      at = end;
    }
    if (at < text.length) children.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: children);
  }
}

/// [run]'s overrides as a Flutter text style (unset fields inherit).
TextStyle runFlutterStyle(TextRun run) => TextStyle(
  color: run.color == null ? null : toUiColor(run.color!),
  fontWeight:
      run.fontWeight == null
          ? null
          : FontWeight.values[(run.fontWeight! ~/ 100) - 1],
  fontStyle:
      run.italic == null
          ? null
          : (run.italic! ? FontStyle.italic : FontStyle.normal),
  decoration: TextDecoration.combine([
    if (run.underline ?? false) TextDecoration.underline,
    if (run.strikethrough ?? false) TextDecoration.lineThrough,
  ]),
  fontSize: run.fontSize,
  fontFamily: run.fontFamily,
);

/// Inline text editor drawn exactly over a text object (P1.5.1).
///
/// [matrix] maps the object's local box to the canvas, so the editor follows
/// zoom and rotation. Styling mirrors `renderer.layoutText`, so text does
/// not jump when editing starts or ends. Character runs are shown live and
/// Ctrl+B/I/U format the selected characters (P1.5.4).
class TextEditOverlay extends StatefulWidget {
  const TextEditOverlay({
    required this.object,
    required this.matrix,
    required this.onChanged,
    required this.onDone,
    this.onSelection,
    this.onToggle,
    super.key,
  });

  final DesignObject object;
  final Matrix4 matrix;

  /// New text and the runs that follow it.
  final void Function(String text, List<TextRun> runs) onChanged;
  final VoidCallback onDone;

  /// The selected characters changed.
  final ValueChanged<TextRange>? onSelection;
  final ValueChanged<TextToggle>? onToggle;

  @override
  State<TextEditOverlay> createState() => _TextEditOverlayState();
}

class _TextEditOverlayState extends State<TextEditOverlay> {
  late final RichTextEditingController _controller;
  final FocusNode _focus = FocusNode(debugLabel: 'text edit');
  bool _done = false;
  late String _lastText;
  TextSelection? _lastSelection;

  TextPayload get _payload => widget.object.payload as TextPayload;

  @override
  void initState() {
    super.initState();
    final text = _payload.text;
    _lastText = text;
    _controller =
        RichTextEditingController(text: text, runs: _payload.runs)
          ..selection = TextSelection(baseOffset: 0, extentOffset: text.length)
          ..addListener(_onValue);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focus.requestFocus();
        _onValue();
      }
    });
  }

  @override
  void didUpdateWidget(TextEditOverlay old) {
    super.didUpdateWidget(old);
    // Formatting applied from outside (inspector, shortcuts) arrives as a
    // new payload with the same text.
    final runs = _payload.runs;
    if (_payload.text == _controller.text &&
        !_sameRuns(runs, _controller.runs)) {
      _controller.runs = runs;
      // Repaint the field with the new runs.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  static bool _sameRuns(List<TextRun> a, List<TextRun> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _onValue() {
    final text = _controller.text;
    if (text != _lastText) {
      _controller.runs = shiftRunsForEdit(_controller.runs, _lastText, text);
      _lastText = text;
      widget.onChanged(text, _controller.runs);
    }
    final selection = _controller.selection;
    if (selection != _lastSelection && selection.isValid) {
      _lastSelection = selection;
      widget.onSelection?.call(
        TextRange(start: selection.start, end: selection.end),
      );
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onValue)
      ..dispose();
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
    final toggle = widget.onToggle;
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
              if (toggle != null) ...{
                const SingleActivator(LogicalKeyboardKey.keyB, control: true):
                    () => toggle(TextToggle.bold),
                const SingleActivator(LogicalKeyboardKey.keyI, control: true):
                    () => toggle(TextToggle.italic),
                const SingleActivator(LogicalKeyboardKey.keyU, control: true):
                    () => toggle(TextToggle.underline),
                const SingleActivator(
                      LogicalKeyboardKey.keyX,
                      control: true,
                      shift: true,
                    ):
                    () => toggle(TextToggle.strikethrough),
              },
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
              // Editing ends with Esc or a click on the canvas (which the
              // canvas handles), not when the inspector, a menu or a dialog
              // takes focus: their formatting applies to the selection.
              onTapOutside: (_) {},
            ),
          ),
        ),
      ),
    );
  }
}
