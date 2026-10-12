import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/ocx_theme.dart';
import '../widgets/controls.dart';
import 'editor_controller.dart';
import 'tools.dart';

/// Floating tool bar centred at the bottom of the canvas
/// (design-system.md §5): selection and navigation tools, then the
/// drawing tools. Content (templates, icons, uploads) lives in the rail.
class FloatingToolbar extends StatelessWidget {
  const FloatingToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.all(Space.xs),
        child: _ToolButtons(),
      ),
    );
  }
}

class _ToolButtons extends ConsumerWidget {
  const _ToolButtons();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tools = ref.watch(toolProvider);
    final select = ref.read(toolProvider.notifier).select;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToolButton(
          tool: EditorTool.move,
          selected: tools.active == EditorTool.move,
          onTap: () => select(EditorTool.move),
        ),
        _ToolButton(
          tool: EditorTool.hand,
          selected: tools.active == EditorTool.hand,
          onTap: () => select(EditorTool.hand),
        ),
        const _Separator(),
        _FrameTool(
          selected: tools.active == EditorTool.frame,
          onSelect: () => select(EditorTool.frame),
        ),
        _ToolGroup(
          tools: shapeTools,
          current: tools.lastShape,
          active: tools.active,
          onSelect: select,
        ),
        _ToolGroup(
          tools: lineTools,
          current: tools.lastLine,
          active: tools.active,
          onSelect: select,
        ),
        _ToolButton(
          tool: EditorTool.text,
          selected: tools.active == EditorTool.text,
          onTap: () => select(EditorTool.text),
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tool,
    required this.selected,
    required this.onTap,
  });

  final EditorTool tool;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 1),
    child: OcxIconButton(
      icon: tool.icon,
      tooltip: tool.tooltip,
      selected: selected,
      iconSize: Chrome.toolbarIcon,
      size: 32,
      onPressed: onTap,
    ),
  );
}

/// Frame tool (F) plus a menu of frame sizes (ADR-0007).
class _FrameTool extends ConsumerWidget {
  const _FrameTool({required this.selected, required this.onSelect});

  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ocx;
    final editor = ref.read(editorProvider.notifier);
    final presets = framePresets;
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          onPressed: onSelect,
          leadingIcon: const Icon(Icons.tag),
          trailingIcon: Text('F', style: OcxText.caption(context)),
          child: const Text('Draw a frame'),
        ),
        const Divider(),
        for (final category in PresetCategory.values)
          if (presets.any((p) => p.category == category))
            SubmenuButton(
              menuChildren: [
                for (final p in presets)
                  if (p.category == category)
                    MenuItemButton(
                      onPressed:
                          () => editor.insertFrame(
                            width: p.width,
                            height: p.height,
                            name: p.name,
                          ),
                      trailingIcon: Text(
                        p.sizeLabel,
                        style: OcxText.caption(context),
                      ),
                      child: Text(p.name),
                    ),
              ],
              child: Text(category.label),
            ),
      ],
      builder:
          (context, controller, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Material(
              color: selected ? c.accentSubtle : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: EditorTool.frame.tooltip,
                    child: InkWell(
                      onTap: onSelect,
                      borderRadius: BorderRadius.circular(Radii.xs),
                      child: SizedBox(
                        width: 30,
                        height: 32,
                        child: Icon(
                          EditorTool.frame.icon,
                          size: Chrome.toolbarIcon,
                          color: selected ? c.accent : c.text,
                        ),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Frame sizes',
                    child: InkWell(
                      onTap:
                          () =>
                              controller.isOpen
                                  ? controller.close()
                                  : controller.open(),
                      borderRadius: BorderRadius.circular(Radii.xs),
                      child: SizedBox(
                        width: 14,
                        height: 32,
                        child: Icon(
                          Icons.expand_more,
                          size: 14,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

/// One button for a family of tools (shapes, lines) with a chevron menu.
class _ToolGroup extends StatelessWidget {
  const _ToolGroup({
    required this.tools,
    required this.current,
    required this.active,
    required this.onSelect,
  });

  final List<EditorTool> tools;
  final EditorTool current;
  final EditorTool active;
  final ValueChanged<EditorTool> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final selected = tools.contains(active);
    return MenuAnchor(
      menuChildren: [
        for (final tool in tools)
          MenuItemButton(
            onPressed: () => onSelect(tool),
            leadingIcon: Icon(tool.icon),
            trailingIcon:
                tool.shortcutLabel == null
                    ? null
                    : Text(
                      tool.shortcutLabel!,
                      style: OcxText.caption(context),
                    ),
            child: Text(tool.label),
          ),
      ],
      builder:
          (context, controller, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Material(
              color: selected ? c.accentSubtle : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: current.tooltip,
                    child: InkWell(
                      onTap: () => onSelect(current),
                      borderRadius: BorderRadius.circular(Radii.xs),
                      child: SizedBox(
                        width: 30,
                        height: 32,
                        child: Icon(
                          current.icon,
                          size: Chrome.toolbarIcon,
                          color: selected ? c.accent : c.text,
                        ),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'More ${tools == shapeTools ? 'shapes' : 'lines'}',
                    child: InkWell(
                      onTap:
                          () =>
                              controller.isOpen
                                  ? controller.close()
                                  : controller.open(),
                      borderRadius: BorderRadius.circular(Radii.xs),
                      child: SizedBox(
                        width: 14,
                        height: 32,
                        child: Icon(
                          Icons.expand_more,
                          size: 14,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

// ------------------------------------------------------------ title/status

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 20,
    margin: const EdgeInsets.symmetric(horizontal: Space.xs),
    color: context.ocx.border,
  );
}
