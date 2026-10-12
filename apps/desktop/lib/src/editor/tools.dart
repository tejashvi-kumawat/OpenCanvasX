import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Canvas tools in the toolbar (design-system.md §5 "Toolbar").
enum EditorTool {
  move('Move', Icons.near_me_outlined, LogicalKeyboardKey.keyV, 'V'),
  hand('Hand', Icons.pan_tool_outlined, LogicalKeyboardKey.keyH, 'H'),
  frame('Frame', Icons.tag, LogicalKeyboardKey.keyF, 'F'),
  rect('Rectangle', Icons.crop_square, LogicalKeyboardKey.keyR, 'R'),
  roundedRect('Rounded rectangle', Icons.rounded_corner, null, null),
  ellipse('Ellipse', Icons.circle_outlined, LogicalKeyboardKey.keyO, 'O'),
  polygon('Polygon', Icons.hexagon_outlined, null, null),
  star('Star', Icons.star_outline, null, null),
  line('Line', Icons.horizontal_rule, LogicalKeyboardKey.keyL, 'L'),
  arrow('Arrow', Icons.north_east, LogicalKeyboardKey.keyL, 'Shift+L'),
  text('Text', Icons.title, LogicalKeyboardKey.keyT, 'T');

  const EditorTool(this.label, this.icon, this.key, this.shortcutLabel);

  final String label;
  final IconData icon;
  final LogicalKeyboardKey? key;
  final String? shortcutLabel;

  String get tooltip =>
      shortcutLabel == null ? label : '$label  ($shortcutLabel)';

  /// The object type this tool draws, if it draws one.
  ObjectType? get objectType => switch (this) {
    EditorTool.rect => ObjectType.rect,
    EditorTool.roundedRect => ObjectType.roundedRect,
    EditorTool.ellipse => ObjectType.ellipse,
    EditorTool.polygon => ObjectType.polygon,
    EditorTool.star => ObjectType.star,
    EditorTool.line => ObjectType.line,
    EditorTool.arrow => ObjectType.arrow,
    EditorTool.text => ObjectType.text,
    EditorTool.frame => ObjectType.frame,
    EditorTool.move || EditorTool.hand => null,
  };

  bool get isShape => const {
    EditorTool.rect,
    EditorTool.roundedRect,
    EditorTool.ellipse,
    EditorTool.polygon,
    EditorTool.star,
  }.contains(this);

  bool get isLine => this == EditorTool.line || this == EditorTool.arrow;
}

/// Shape tools grouped under one toolbar button.
const shapeTools = [
  EditorTool.rect,
  EditorTool.roundedRect,
  EditorTool.ellipse,
  EditorTool.polygon,
  EditorTool.star,
];

/// Line tools grouped under one toolbar button.
const lineTools = [EditorTool.line, EditorTool.arrow];

/// Active tool plus the last-used shape and line tools (shown on the
/// grouped toolbar buttons).
@immutable
class ToolState {
  const ToolState({
    this.active = EditorTool.move,
    this.lastShape = EditorTool.rect,
    this.lastLine = EditorTool.line,
  });

  final EditorTool active;
  final EditorTool lastShape;
  final EditorTool lastLine;
}

final toolProvider = NotifierProvider<ToolController, ToolState>(
  ToolController.new,
);

class ToolController extends Notifier<ToolState> {
  @override
  ToolState build() => const ToolState();

  void select(EditorTool tool) =>
      state = ToolState(
        active: tool,
        lastShape: tool.isShape ? tool : state.lastShape,
        lastLine: tool.isLine ? tool : state.lastLine,
      );

  /// Back to Move, e.g. after drawing one shape.
  void reset() => select(EditorTool.move);
}
