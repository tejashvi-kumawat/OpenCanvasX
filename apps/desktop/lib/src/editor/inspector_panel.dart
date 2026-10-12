import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/ocx_theme.dart';
import '../widgets/color_picker.dart';
import '../widgets/number_field.dart';
import '../widgets/panel_section.dart';
import 'editor_controller.dart';

/// Right-hand properties panel (P1.10.2): edits the selection, or the page
/// when nothing is selected.
class InspectorPanel extends ConsumerWidget {
  const InspectorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(editorProvider);
    if (session == null) return const SizedBox.shrink();
    final selected = session.state.selectedObjects;
    return ColoredBox(
      color: context.ocx.panel,
      child: SizedBox(
        width: Chrome.inspectorWidth,
        child: ListView(
          padding: const EdgeInsets.only(bottom: Space.xl),
          children: switch (selected.length) {
            0 => [_PageInspector(session: session)],
            1 => [_ObjectInspector(session: session, object: selected.single)],
            _ => [_MultiInspector(session: session, objects: selected)],
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.subtitle, this.icon});

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.lg,
        Space.lg,
        Space.xs,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: context.ocx.selectedFill,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(icon, size: 18, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: Space.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (subtitle != null)
                  Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ object

class _ObjectInspector extends ConsumerStatefulWidget {
  const _ObjectInspector({required this.session, required this.object});

  final EditorSession session;
  final DesignObject object;

  @override
  ConsumerState<_ObjectInspector> createState() => _ObjectInspectorState();
}

class _ObjectInspectorState extends ConsumerState<_ObjectInspector> {
  bool _lockRatio = false;

  EditorController get _editor => ref.read(editorProvider.notifier);

  void _setTransform(ObjectTransform t, String label) =>
      _editor.updateSelected((o) => o.copyWith(transform: t), label: label);

  void _setStyle(ObjectStyle style, String label) =>
      _editor.updateSelected((o) => o.copyWith(style: style), label: label);

  @override
  Widget build(BuildContext context) {
    final o = widget.object;
    final t = o.transform;
    final page = widget.session.activePage;
    final unit = page.unit.symbol;
    final decimals = page.unit == LengthUnit.px ? 0 : 2;
    final step = page.unit == LengthUnit.px ? 1.0 : 0.5;
    final style = o.style ?? ObjectStyle.none;
    final isLine = o.type == ObjectType.line || o.type == ObjectType.arrow;
    final canRound =
        o.type == ObjectType.rect || o.type == ObjectType.roundedRect;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: layerName(widget.session.document, page, o),
          subtitle: typeLabel(o.type),
          icon: _iconFor(o.type),
        ),
        PanelSection(
          title: 'Position',
          child: FieldRow(
            children: [
              NumberField(
                label: 'X',
                value: t.x,
                decimals: decimals,
                step: step,
                onChanged: (v) => _setTransform(t.copyWith(x: v), 'Move'),
              ),
              NumberField(
                label: 'Y',
                value: t.y,
                decimals: decimals,
                step: step,
                onChanged: (v) => _setTransform(t.copyWith(y: v), 'Move'),
              ),
            ],
          ),
        ),
        PanelSection(
          title: 'Size',
          trailing:
              isLine
                  ? null
                  : ToolIconButton(
                    icon: _lockRatio ? Icons.link : Icons.link_off,
                    tooltip:
                        _lockRatio
                            ? 'Unlock aspect ratio'
                            : 'Lock aspect ratio',
                    selected: _lockRatio,
                    onPressed: () => setState(() => _lockRatio = !_lockRatio),
                  ),
          child: FieldRow(
            children: [
              NumberField(
                label: isLine ? 'L' : 'W',
                value: t.width,
                suffix: unit,
                min: 0,
                decimals: decimals,
                step: step,
                onChanged:
                    (v) => _setTransform(
                      _lockRatio && t.width > 0
                          ? t.copyWith(width: v, height: t.height * v / t.width)
                          : t.copyWith(width: v),
                      'Resize',
                    ),
              ),
              if (!isLine)
                NumberField(
                  label: 'H',
                  value: t.height,
                  suffix: unit,
                  min: 0,
                  decimals: decimals,
                  step: step,
                  onChanged:
                      (v) => _setTransform(
                        _lockRatio && t.height > 0
                            ? t.copyWith(
                              height: v,
                              width: t.width * v / t.height,
                            )
                            : t.copyWith(height: v),
                        'Resize',
                      ),
                ),
            ],
          ),
        ),
        PanelSection(
          title: 'Rotation',
          child: Row(
            children: [
              Expanded(
                child: NumberField(
                  value: t.rotation,
                  suffix: '°',
                  onChanged:
                      (v) => _setTransform(
                        t.copyWith(rotation: normalizeDegrees(v)),
                        'Rotate',
                      ),
                ),
              ),
              const SizedBox(width: Space.sm),
              SizedBox(
                width: 38,
                child: ToolIconButton(
                  icon: Icons.flip,
                  tooltip: 'Flip horizontal',
                  onPressed:
                      () => _setTransform(
                        flipTransform(t, horizontal: true),
                        'Flip',
                      ),
                ),
              ),
              SizedBox(
                width: 38,
                // The same mirror glyph, turned for the vertical axis.
                child: RotatedBox(
                  quarterTurns: 1,
                  child: ToolIconButton(
                    icon: Icons.flip,
                    tooltip: 'Flip vertical',
                    onPressed:
                        () => _setTransform(
                          flipTransform(t, horizontal: false),
                          'Flip',
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
        PanelSection(
          title: 'Opacity',
          child: _OpacitySlider(
            value: o.opacity,
            onChanged:
                (v) => _editor.updateSelected(
                  (x) => x.copyWith(opacity: v),
                  label: 'Opacity',
                ),
          ),
        ),
        if (!isLine)
          PanelSection(
            title: 'Fill',
            child: ColorPicker(
              value: switch (style.fill) {
                SolidFill(:final color) => color,
                null => null,
              },
              allowNone: true,
              onChanged:
                  (c) => _setStyle(
                    ObjectStyle(
                      fill: c == null ? null : SolidFill(c),
                      stroke: style.stroke,
                      cornerRadius: style.cornerRadius,
                    ),
                    'Fill',
                  ),
            ),
          ),
        PanelSection(
          title: isLine ? 'Line' : 'Border',
          trailing:
              isLine
                  ? null
                  : Switch(
                    value: style.stroke != null,
                    onChanged:
                        (on) => _setStyle(
                          ObjectStyle(
                            fill: style.fill,
                            stroke:
                                on
                                    ? Stroke(
                                      color: ArgbColor.black,
                                      width: _defaultStroke(page),
                                    )
                                    : null,
                            cornerRadius: style.cornerRadius,
                          ),
                          'Border',
                        ),
                  ),
          child:
              style.stroke == null
                  ? const SizedBox.shrink()
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      NumberField(
                        label: 'Weight',
                        value: style.stroke!.width,
                        suffix: unit,
                        min: 0,
                        decimals: page.unit == LengthUnit.px ? 1 : 2,
                        step: page.unit == LengthUnit.px ? 1 : 0.25,
                        onChanged:
                            (v) => _setStyle(
                              ObjectStyle(
                                fill: style.fill,
                                stroke: Stroke(
                                  color: style.stroke!.color,
                                  width: v,
                                ),
                                cornerRadius: style.cornerRadius,
                              ),
                              'Border',
                            ),
                      ),
                      const SizedBox(height: Space.md),
                      ColorPicker(
                        value: style.stroke!.color,
                        onChanged:
                            (c) => _setStyle(
                              ObjectStyle(
                                fill: style.fill,
                                stroke: Stroke(
                                  color: c ?? ArgbColor.black,
                                  width: style.stroke!.width,
                                ),
                                cornerRadius: style.cornerRadius,
                              ),
                              'Border',
                            ),
                      ),
                    ],
                  ),
        ),
        if (canRound)
          PanelSection(
            title: 'Corner radius',
            child: NumberField(
              value: style.cornerRadius,
              suffix: unit,
              min: 0,
              decimals: decimals,
              step: step,
              onChanged:
                  (v) => _setStyle(
                    ObjectStyle(
                      fill: style.fill,
                      stroke: style.stroke,
                      cornerRadius: v,
                    ),
                    'Corner radius',
                  ),
            ),
          ),
        const _AlignSection(toPage: true),
        const _ArrangeSection(),
      ],
    );
  }
}

double _defaultStroke(DesignPage page) =>
    page.unit == LengthUnit.px
        ? 4
        : convertLength(3, from: LengthUnit.px, to: page.unit);

IconData _iconFor(ObjectType type) => switch (type) {
  ObjectType.rect => Icons.crop_square,
  ObjectType.roundedRect => Icons.rounded_corner,
  ObjectType.ellipse => Icons.circle_outlined,
  ObjectType.line => Icons.horizontal_rule,
  ObjectType.arrow => Icons.arrow_right_alt,
  ObjectType.text => Icons.title,
  ObjectType.image => Icons.image_outlined,
  ObjectType.path => Icons.gesture,
  ObjectType.group => Icons.folder_copy_outlined,
};

/// Opacity slider that previews locally while dragging and commits once on
/// release, so a drag is a single undo step.
class _OpacitySlider extends StatefulWidget {
  const _OpacitySlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_OpacitySlider> createState() => _OpacitySliderState();
}

class _OpacitySliderState extends State<_OpacitySlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final value = _dragging ?? widget.value;
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: value,
            onChanged: (v) => setState(() => _dragging = v),
            onChangeEnd: (v) {
              setState(() => _dragging = null);
              widget.onChanged(v);
            },
          ),
        ),
        SizedBox(
          width: 76,
          child: NumberField(
            value: (value * 100).roundToDouble(),
            suffix: '%',
            min: 0,
            max: 100,
            decimals: 0,
            onChanged: (v) => widget.onChanged(v / 100),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------- multi-select

class _MultiInspector extends ConsumerWidget {
  const _MultiInspector({required this.session, required this.objects});

  final EditorSession session;
  final List<DesignObject> objects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.read(editorProvider.notifier);
    final opacities = objects.map((o) => o.opacity).toSet();
    final fills =
        objects
            .where(
              (o) => o.type != ObjectType.line && o.type != ObjectType.arrow,
            )
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: '${objects.length} elements',
          subtitle: 'Edit them together',
          icon: Icons.select_all,
        ),
        PanelSection(
          title: 'Opacity',
          child: _OpacitySlider(
            value: opacities.length == 1 ? opacities.first : 1,
            onChanged:
                (v) => editor.updateSelected(
                  (o) => o.copyWith(opacity: v),
                  label: 'Opacity',
                ),
          ),
        ),
        if (fills.isNotEmpty)
          PanelSection(
            title: 'Fill',
            child: ColorPicker(
              value: null,
              allowNone: true,
              onChanged:
                  (c) => editor.updateSelected(
                    (o) =>
                        o.type == ObjectType.line || o.type == ObjectType.arrow
                            ? o
                            : o.copyWith(
                              style: ObjectStyle(
                                fill: c == null ? null : SolidFill(c),
                                stroke: o.style?.stroke,
                                cornerRadius: o.style?.cornerRadius ?? 0,
                              ),
                            ),
                    label: 'Fill',
                  ),
            ),
          ),
        const _AlignSection(toPage: false),
        const _ArrangeSection(),
      ],
    );
  }
}

class _AlignSection extends ConsumerWidget {
  const _AlignSection({required this.toPage});

  final bool toPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.read(editorProvider.notifier);
    final target = toPage ? 'page' : 'selection';
    return PanelSection(
      title: 'Align to $target',
      child: Row(
        children: [
          for (final (edge, icon, label) in const [
            (AlignEdge.left, Icons.align_horizontal_left, 'Left'),
            (
              AlignEdge.centerHorizontal,
              Icons.align_horizontal_center,
              'Centre',
            ),
            (AlignEdge.right, Icons.align_horizontal_right, 'Right'),
            (AlignEdge.top, Icons.align_vertical_top, 'Top'),
            (AlignEdge.centerVertical, Icons.align_vertical_center, 'Middle'),
            (AlignEdge.bottom, Icons.align_vertical_bottom, 'Bottom'),
          ])
            Expanded(
              child: ToolIconButton(
                icon: icon,
                tooltip: 'Align $label',
                onPressed: () => editor.align(edge),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArrangeSection extends ConsumerWidget {
  const _ArrangeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.read(editorProvider.notifier);
    return PanelSection(
      title: 'Arrange',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final (move, icon, label) in const [
                (
                  ZOrderMove.toBack,
                  Icons.vertical_align_bottom,
                  'Send to back',
                ),
                (ZOrderMove.backward, Icons.arrow_downward, 'Send backward'),
                (ZOrderMove.forward, Icons.arrow_upward, 'Bring forward'),
                (
                  ZOrderMove.toFront,
                  Icons.vertical_align_top,
                  'Bring to front',
                ),
              ])
                Expanded(
                  child: ToolIconButton(
                    icon: icon,
                    tooltip: label,
                    onPressed: () => editor.arrange(move),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          FieldRow(
            children: [
              OutlinedButton.icon(
                onPressed: editor.duplicateSelection,
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('Duplicate'),
              ),
              OutlinedButton.icon(
                onPressed: editor.deleteSelection,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- page

class _PageInspector extends ConsumerWidget {
  const _PageInspector({required this.session});

  final EditorSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.read(editorProvider.notifier);
    final page = session.activePage;
    final decimals = page.unit == LengthUnit.px ? 0 : 2;
    final index = session.state.activePageIndex + 1;
    final background = switch (page.background) {
      SolidBackground(:final color) => color,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: 'Page $index',
          subtitle:
              '${_fmt(page.width)} × ${_fmt(page.height)} ${page.unit.symbol}'
              '${page.unit == LengthUnit.px ? '' : ' · ${page.dpi.round()} DPI'}',
          icon: Icons.description_outlined,
        ),
        PanelSection(
          title: 'Name',
          child: _NameField(
            value: page.name,
            hint: 'Page $index',
            onSubmitted:
                (name) => editor.updatePage(
                  page.copyWith(name: name.trim()),
                  label: 'Rename page',
                ),
          ),
        ),
        PanelSection(
          title: 'Size',
          trailing: _ResizeMenu(page: page),
          child: FieldRow(
            children: [
              NumberField(
                label: 'W',
                value: page.width,
                suffix: page.unit.symbol,
                min: 1,
                decimals: decimals,
                onChanged: (v) => _resize(editor, page, width: v),
              ),
              NumberField(
                label: 'H',
                value: page.height,
                suffix: page.unit.symbol,
                min: 1,
                decimals: decimals,
                onChanged: (v) => _resize(editor, page, height: v),
              ),
            ],
          ),
        ),
        PanelSection(
          title: 'Background',
          child: ColorPicker(
            value: background,
            allowNone: true,
            onChanged:
                (c) => editor.updatePage(
                  page.copyWith(
                    background:
                        c == null
                            ? const TransparentBackground()
                            : SolidBackground(c),
                  ),
                  label: 'Background',
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Text(
            'Tip: click an element to edit it, drag on empty space to select '
            'several, and hold Ctrl while scrolling to zoom.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  void _resize(
    EditorController editor,
    DesignPage page, {
    double? width,
    double? height,
  }) {
    final w = width ?? page.width;
    final h = height ?? page.height;
    final margins = page.margins;
    final fits =
        margins.left + margins.right <= w && margins.top + margins.bottom <= h;
    editor.updatePage(
      page.copyWith(
        width: w,
        height: h,
        margins: fits ? null : PageInsets.zero,
      ),
      label: 'Resize page',
    );
  }
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

class _ResizeMenu extends ConsumerWidget {
  const _ResizeMenu({required this.page});

  final DesignPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.read(editorProvider.notifier);
    // Only offer presets in the page's own unit; objects are positioned in
    // that unit, so switching units would move everything.
    final presets = pagePresets.where((p) => p.unit == page.unit).toList();
    return MenuAnchor(
      menuChildren: [
        for (final preset in presets)
          MenuItemButton(
            onPressed:
                () => editor.updatePage(
                  page.copyWith(width: preset.width, height: preset.height),
                  label: 'Resize page',
                ),
            trailingIcon: Text(
              preset.sizeLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            child: Text(preset.name),
          ),
      ],
      builder:
          (context, controller, _) => TextButton.icon(
            onPressed:
                presets.isEmpty
                    ? null
                    : () =>
                        controller.isOpen
                            ? controller.close()
                            : controller.open(),
            icon: const Icon(Icons.aspect_ratio, size: 16),
            label: const Text('Presets'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 28),
            ),
          ),
    );
  }
}

class _NameField extends StatefulWidget {
  const _NameField({
    required this.value,
    required this.hint,
    required this.onSubmitted,
  });

  final String value;
  final String hint;
  final ValueChanged<String> onSubmitted;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _controller.text != widget.value) {
        widget.onSubmitted(_controller.text);
      }
    });
  }

  @override
  void didUpdateWidget(_NameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focus,
    decoration: InputDecoration(hintText: widget.hint),
    onSubmitted: widget.onSubmitted,
  );
}
