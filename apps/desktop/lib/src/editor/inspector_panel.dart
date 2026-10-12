import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/ocx_theme.dart';
import '../widgets/controls.dart';
import '../widgets/number_field.dart';
import '../widgets/object_icons.dart';
import 'editor_controller.dart';

/// Fonts offered until local font discovery lands (P1.5.5). Families that
/// are not installed fall back to the default UI font.
const fontFamilies = [
  'Segoe UI',
  'Arial',
  'Calibri',
  'Cambria',
  'Georgia',
  'Times New Roman',
  'Verdana',
  'Tahoma',
  'Trebuchet MS',
  'Courier New',
  'Consolas',
  'Impact',
];

const _weights = [
  (100, 'Thin'),
  (200, 'Extra light'),
  (300, 'Light'),
  (400, 'Regular'),
  (500, 'Medium'),
  (600, 'Semibold'),
  (700, 'Bold'),
  (800, 'Extra bold'),
  (900, 'Black'),
];

/// Right sidebar (P1.10.2). Sections always appear in the order defined in
/// design-system.md §5: Alignment, Layout, Text, Appearance, Fill, Stroke.
class InspectorPanel extends ConsumerWidget {
  const InspectorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(editorProvider);
    if (session == null) return const SizedBox.shrink();
    final selected = session.state.selectedObjects;
    return Container(
      width: Chrome.inspector,
      color: context.ocx.surface,
      child: ListView(
        padding: const EdgeInsets.only(bottom: Space.xl),
        children:
            selected.isEmpty
                ? [_PageInspector(session: session)]
                : [_SelectionInspector(session: session, objects: selected)],
      ),
    );
  }
}

/// Header row: icon + name of what is being edited.
class _Header extends StatelessWidget {
  const _Header({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: Row(
              children: [
                Icon(icon, size: Chrome.icon, color: c.textSecondary),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OcxText.bodyStrong(context),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: OcxText.caption(
                      context,
                    ).copyWith(color: c.textTertiary),
                  ),
              ],
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }
}

// ---------------------------------------------------------------- selection

class _SelectionInspector extends ConsumerStatefulWidget {
  const _SelectionInspector({required this.session, required this.objects});

  final EditorSession session;
  final List<DesignObject> objects;

  @override
  ConsumerState<_SelectionInspector> createState() =>
      _SelectionInspectorState();
}

class _SelectionInspectorState extends ConsumerState<_SelectionInspector> {
  bool _lockRatio = false;

  EditorController get _editor => ref.read(editorProvider.notifier);

  void _update(DesignObject Function(DesignObject o) f, String label) =>
      _editor.updateSelected(f, label: label);

  void _transform(
    ObjectTransform Function(ObjectTransform t) f,
    String label,
  ) => _update((o) => o.copyWith(transform: f(o.transform)), label);

  void _style(ObjectStyle Function(ObjectStyle s) f, String label) =>
      _update((o) => o.copyWith(style: f(o.style ?? ObjectStyle.none)), label);

  @override
  Widget build(BuildContext context) {
    final objects = widget.objects;
    final single = objects.length == 1 ? objects.single : null;
    final page = widget.session.activePage;
    final unit = page.unit.symbol;
    final decimals = page.unit == LengthUnit.px ? 0 : 2;
    final step = page.unit == LengthUnit.px ? 1.0 : 0.5;
    final texts = [
      for (final o in objects)
        if (o.payload case final TextPayload t) t,
    ];
    final allText = texts.length == objects.length;
    final allLines = objects.every(
      (o) => o.type == ObjectType.line || o.type == ObjectType.arrow,
    );
    final style = single?.style ?? ObjectStyle.none;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          icon: single == null ? Icons.select_all : objectIcon(single.type),
          title:
              single == null
                  ? '${objects.length} layers'
                  : layerName(widget.session.document, page, single),
          subtitle: single == null ? null : typeLabel(single.type),
        ),
        _AlignmentSection(count: objects.length),
        if (single != null) _layoutSection(single, unit, decimals, step),
        if (allText) _TextSection(texts: texts, unit: unit),
        _appearanceSection(objects),
        if (!allLines) _fillSection(objects, allText),
        if (single != null) _strokeSection(single, style, unit),
      ],
    );
  }

  Widget _layoutSection(
    DesignObject o,
    String unit,
    int decimals,
    double step,
  ) {
    final t = o.transform;
    final flat = t.height == 0;
    final canRound =
        o.type == ObjectType.rect || o.type == ObjectType.roundedRect;
    final style = o.style ?? ObjectStyle.none;
    return PanelSection(
      title: 'Layout',
      trailing: [
        OcxIconButton(
          icon: Icons.flip,
          tooltip: 'Flip horizontal',
          onPressed:
              () =>
                  _transform((t) => flipTransform(t, horizontal: true), 'Flip'),
        ),
        RotatedBox(
          quarterTurns: 1,
          child: OcxIconButton(
            icon: Icons.flip,
            tooltip: 'Flip vertical',
            onPressed:
                () => _transform(
                  (t) => flipTransform(t, horizontal: false),
                  'Flip',
                ),
          ),
        ),
      ],
      child: FieldColumn(
        children: [
          FieldRow(
            children: [
              NumberField(
                label: 'X',
                value: t.x,
                decimals: decimals,
                step: step,
                tooltip: 'X position ($unit)',
                onChanged: (v) => _transform((t) => t.copyWith(x: v), 'Move'),
              ),
              NumberField(
                label: 'Y',
                value: t.y,
                decimals: decimals,
                step: step,
                tooltip: 'Y position ($unit)',
                onChanged: (v) => _transform((t) => t.copyWith(y: v), 'Move'),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: NumberField(
                  label: flat ? 'L' : 'W',
                  value: t.width,
                  min: 0,
                  decimals: decimals,
                  step: step,
                  tooltip: flat ? 'Length ($unit)' : 'Width ($unit)',
                  onChanged:
                      (v) => _transform(
                        (t) =>
                            _lockRatio && t.width > 0
                                ? t.copyWith(
                                  width: v,
                                  height: t.height * v / t.width,
                                )
                                : t.copyWith(width: v),
                        'Resize',
                      ),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child:
                    flat
                        ? const SizedBox.shrink()
                        : NumberField(
                          label: 'H',
                          value: t.height,
                          min: 0,
                          decimals: decimals,
                          step: step,
                          tooltip: 'Height ($unit)',
                          onChanged:
                              (v) => _transform(
                                (t) =>
                                    _lockRatio && t.height > 0
                                        ? t.copyWith(
                                          height: v,
                                          width: t.width * v / t.height,
                                        )
                                        : t.copyWith(height: v),
                                'Resize',
                              ),
                        ),
              ),
              if (!flat)
                OcxIconButton(
                  icon: _lockRatio ? Icons.link : Icons.link_off,
                  tooltip:
                      _lockRatio ? 'Unlock aspect ratio' : 'Lock aspect ratio',
                  selected: _lockRatio,
                  onPressed: () => setState(() => _lockRatio = !_lockRatio),
                ),
            ],
          ),
          FieldRow(
            children: [
              NumberField(
                icon: Icons.rotate_right,
                value: t.rotation,
                suffix: '°',
                tooltip: 'Rotation',
                onChanged:
                    (v) => _transform(
                      (t) => t.copyWith(rotation: normalizeDegrees(v)),
                      'Rotate',
                    ),
              ),
              if (canRound)
                NumberField(
                  icon: Icons.rounded_corner,
                  value: style.cornerRadius,
                  min: 0,
                  decimals: decimals,
                  step: step,
                  tooltip: 'Corner radius ($unit)',
                  onChanged:
                      (v) => _style(
                        (s) => ObjectStyle(
                          fill: s.fill,
                          stroke: s.stroke,
                          cornerRadius: v,
                        ),
                        'Corner radius',
                      ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _appearanceSection(List<DesignObject> objects) {
    final opacities = objects.map((o) => o.opacity).toSet();
    final blends = objects.map((o) => o.blendMode).toSet();
    return PanelSection(
      title: 'Appearance',
      child: FieldRow(
        flex: const [2, 3],
        children: [
          NumberField(
            icon: Icons.opacity,
            value:
                opacities.length == 1
                    ? (opacities.first * 100).roundToDouble()
                    : 100,
            suffix: '%',
            min: 0,
            max: 100,
            decimals: 0,
            tooltip: 'Opacity',
            onChanged:
                (v) => _update((o) => o.copyWith(opacity: v / 100), 'Opacity'),
          ),
          OcxSelect<ObjectBlendMode>(
            value: blends.length == 1 ? blends.first : null,
            label: 'Mixed',
            tooltip: 'Blend mode',
            options: [
              for (final mode in ObjectBlendMode.values)
                SelectOption(mode, _blendLabel(mode)),
            ],
            onChanged:
                (m) => _update((o) => o.copyWith(blendMode: m), 'Blend mode'),
          ),
        ],
      ),
    );
  }

  Widget _fillSection(List<DesignObject> objects, bool allText) {
    final fills = {
      for (final o in objects)
        switch (o.style?.fill) {
          SolidFill(:final color) => color,
          null => null,
        },
    };
    final color = fills.length == 1 ? fills.first : null;
    final mixed = fills.length > 1;
    void setFill(ArgbColor? c) => _style(
      (s) => ObjectStyle(
        fill: c == null ? null : SolidFill(c),
        stroke: s.stroke,
        cornerRadius: s.cornerRadius,
      ),
      'Fill',
    );
    return PanelSection(
      title: allText ? 'Text colour' : 'Fill',
      trailing: [
        if (color == null && !mixed)
          OcxIconButton(
            icon: Icons.add,
            tooltip: 'Add fill',
            onPressed: () => setFill(defaultShapeFill),
          ),
      ],
      child:
          mixed
              ? Text(
                'Mixed — pick a colour to apply to all',
                style: OcxText.caption(context),
              )
              : color == null
              ? null
              : ColorRow(
                color: color,
                onChanged: setFill,
                trailing: OcxIconButton(
                  icon: Icons.remove,
                  tooltip: 'Remove fill',
                  onPressed: () => setFill(null),
                ),
              ),
    );
  }

  Widget _strokeSection(DesignObject o, ObjectStyle style, String unit) {
    final stroke = style.stroke;
    final page = widget.session.activePage;
    void setStroke(Stroke? s) => _style(
      (old) => ObjectStyle(
        fill: old.fill,
        stroke: s,
        cornerRadius: old.cornerRadius,
      ),
      'Stroke',
    );
    final defaultWidth =
        page.unit == LengthUnit.px
            ? 2.0
            : convertLength(2, from: LengthUnit.px, to: page.unit);
    return PanelSection(
      title: 'Stroke',
      trailing: [
        if (stroke == null)
          OcxIconButton(
            icon: Icons.add,
            tooltip: 'Add stroke',
            onPressed:
                () => setStroke(
                  Stroke(color: ArgbColor.black, width: defaultWidth),
                ),
          ),
      ],
      child:
          stroke == null
              ? null
              : FieldColumn(
                children: [
                  ColorRow(
                    color: stroke.color,
                    onChanged: (c) => setStroke(stroke.copyWith(color: c)),
                    trailing: OcxIconButton(
                      icon: Icons.remove,
                      tooltip: 'Remove stroke',
                      onPressed: () => setStroke(null),
                    ),
                  ),
                  FieldRow(
                    children: [
                      NumberField(
                        icon: Icons.line_weight,
                        value: stroke.width,
                        min: 0,
                        decimals: page.unit == LengthUnit.px ? 1 : 2,
                        step: page.unit == LengthUnit.px ? 1 : 0.25,
                        tooltip: 'Stroke weight ($unit)',
                        onChanged: (v) => setStroke(stroke.copyWith(width: v)),
                      ),
                      OcxSelect<StrokeDash>(
                        value: stroke.dash,
                        tooltip: 'Stroke style',
                        options: const [
                          SelectOption(StrokeDash.solid, 'Solid'),
                          SelectOption(StrokeDash.dashed, 'Dashed'),
                          SelectOption(StrokeDash.dotted, 'Dotted'),
                        ],
                        onChanged: (d) => setStroke(stroke.copyWith(dash: d)),
                      ),
                    ],
                  ),
                ],
              ),
    );
  }
}

String _blendLabel(ObjectBlendMode mode) => switch (mode) {
  ObjectBlendMode.normal => 'Normal',
  ObjectBlendMode.multiply => 'Multiply',
  ObjectBlendMode.screen => 'Screen',
  ObjectBlendMode.overlay => 'Overlay',
  ObjectBlendMode.darken => 'Darken',
  ObjectBlendMode.lighten => 'Lighten',
  ObjectBlendMode.colorDodge => 'Colour dodge',
  ObjectBlendMode.colorBurn => 'Colour burn',
  ObjectBlendMode.hardLight => 'Hard light',
  ObjectBlendMode.softLight => 'Soft light',
  ObjectBlendMode.difference => 'Difference',
  ObjectBlendMode.exclusion => 'Exclusion',
  ObjectBlendMode.hue => 'Hue',
  ObjectBlendMode.saturation => 'Saturation',
  ObjectBlendMode.color => 'Colour',
  ObjectBlendMode.luminosity => 'Luminosity',
};

class _AlignmentSection extends ConsumerWidget {
  const _AlignmentSection({required this.count});

  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.read(editorProvider.notifier);
    final target = count == 1 ? 'page' : 'selection';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.sm,
        Space.xs,
        Space.sm,
        Space.xs,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (edge, icon, label) in const [
                (AlignEdge.left, Icons.align_horizontal_left, 'left'),
                (
                  AlignEdge.centerHorizontal,
                  Icons.align_horizontal_center,
                  'centre',
                ),
                (AlignEdge.right, Icons.align_horizontal_right, 'right'),
                (AlignEdge.top, Icons.align_vertical_top, 'top'),
                (
                  AlignEdge.centerVertical,
                  Icons.align_vertical_center,
                  'middle',
                ),
                (AlignEdge.bottom, Icons.align_vertical_bottom, 'bottom'),
              ])
                OcxIconButton(
                  icon: icon,
                  tooltip: 'Align $label to $target',
                  onPressed: () => editor.align(edge),
                ),
              OcxIconButton(
                icon: Icons.horizontal_distribute,
                tooltip: 'Distribute horizontally (3 or more)',
                onPressed:
                    count >= 3
                        ? () => editor.distribute(DistributeAxis.horizontal)
                        : null,
              ),
              OcxIconButton(
                icon: Icons.vertical_distribute,
                tooltip: 'Distribute vertically (3 or more)',
                onPressed:
                    count >= 3
                        ? () => editor.distribute(DistributeAxis.vertical)
                        : null,
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          const Divider(),
        ],
      ),
    );
  }
}

class _TextSection extends ConsumerWidget {
  const _TextSection({required this.texts, required this.unit});

  final List<TextPayload> texts;
  final String unit;

  T? _common<T>(T Function(TextPayload t) f) {
    final values = texts.map(f).toSet();
    return values.length == 1 ? values.first : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.read(editorProvider.notifier);
    void update(TextPayload Function(TextPayload t) f, String label) =>
        editor.updateSelectedText(f, label: label);
    final family = _common((t) => t.fontFamily ?? fontFamilies.first);
    final weight = _common((t) => t.fontWeight);
    final size = _common((t) => t.fontSize);
    final align = _common((t) => t.align);
    final sizing = _common((t) => t.sizing);
    final lineHeight = _common((t) => t.lineHeight);
    final spacing = _common((t) => t.letterSpacing);
    final italic = _common((t) => t.italic) ?? false;

    return PanelSection(
      title: 'Text',
      trailing: [
        OcxIconButton(
          icon: Icons.format_italic,
          tooltip: 'Italic',
          selected: italic,
          onPressed: () => update((t) => t.copyWith(italic: !italic), 'Italic'),
        ),
      ],
      child: FieldColumn(
        children: [
          OcxSelect<String>(
            value: family,
            label: 'Mixed',
            tooltip: 'Font',
            options: [for (final f in fontFamilies) SelectOption(f, f)],
            onChanged: (f) => update((t) => t.copyWith(fontFamily: f), 'Font'),
          ),
          FieldRow(
            flex: const [3, 2],
            children: [
              OcxSelect<int>(
                value: weight,
                label: 'Mixed',
                tooltip: 'Weight',
                options: [
                  for (final (w, name) in _weights) SelectOption(w, name),
                ],
                onChanged:
                    (w) => update((t) => t.copyWith(fontWeight: w), 'Weight'),
              ),
              NumberField(
                icon: Icons.format_size,
                value: size ?? 0,
                min: 1,
                tooltip: 'Font size ($unit)',
                onChanged:
                    (v) => update((t) => t.copyWith(fontSize: v), 'Font size'),
              ),
            ],
          ),
          FieldRow(
            children: [
              OcxSegmented<TextAlignment>(
                value: align,
                segments: const [
                  Segment(
                    TextAlignment.left,
                    Icons.format_align_left,
                    'Align left',
                  ),
                  Segment(
                    TextAlignment.center,
                    Icons.format_align_center,
                    'Align centre',
                  ),
                  Segment(
                    TextAlignment.right,
                    Icons.format_align_right,
                    'Align right',
                  ),
                  Segment(
                    TextAlignment.justify,
                    Icons.format_align_justify,
                    'Justify',
                  ),
                ],
                onChanged:
                    (a) => update((t) => t.copyWith(align: a), 'Text align'),
              ),
              OcxSegmented<TextSizing>(
                value: sizing,
                segments: const [
                  Segment(TextSizing.autoWidth, Icons.swap_horiz, 'Auto width'),
                  Segment(
                    TextSizing.autoHeight,
                    Icons.swap_vert,
                    'Auto height',
                  ),
                  Segment(TextSizing.fixed, Icons.crop_free, 'Fixed size'),
                ],
                onChanged:
                    (s) => update((t) => t.copyWith(sizing: s), 'Text sizing'),
              ),
            ],
          ),
          FieldRow(
            children: [
              NumberField(
                icon: Icons.format_line_spacing,
                value: lineHeight ?? 1.2,
                min: 0.5,
                max: 5,
                step: 0.1,
                decimals: 2,
                tooltip: 'Line height (× font size)',
                onChanged:
                    (v) =>
                        update((t) => t.copyWith(lineHeight: v), 'Line height'),
              ),
              NumberField(
                icon: Icons.space_bar,
                value: spacing ?? 0,
                step: 0.5,
                tooltip: 'Letter spacing ($unit)',
                onChanged:
                    (v) => update(
                      (t) => t.copyWith(letterSpacing: v),
                      'Letter spacing',
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
    final presets = pagePresets.where((p) => p.unit == page.unit).toList();
    final matching =
        presets
            .where((p) => p.width == page.width && p.height == page.height)
            .firstOrNull;
    final c = context.ocx;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          icon: Icons.insert_drive_file_outlined,
          title: page.name.isEmpty ? 'Page $index' : page.name,
          subtitle:
              page.unit == LengthUnit.px
                  ? 'px'
                  : '${page.unit.symbol} · ${page.dpi.round()} dpi',
        ),
        PanelSection(
          title: 'Page',
          child: FieldColumn(
            children: [
              _NameField(
                value: page.name,
                hint: 'Page $index',
                onSubmitted:
                    (name) => editor.updatePage(
                      page.copyWith(name: name.trim()),
                      label: 'Rename page',
                    ),
              ),
              if (presets.isNotEmpty)
                OcxSelect<PagePreset>(
                  value: matching,
                  label: 'Custom size',
                  tooltip: 'Page size preset',
                  options: [
                    for (final p in presets)
                      SelectOption(p, p.name, trailing: p.sizeLabel),
                  ],
                  onChanged:
                      (p) => editor.updatePage(
                        page.copyWith(width: p.width, height: p.height),
                        label: 'Resize page',
                      ),
                ),
              FieldRow(
                children: [
                  NumberField(
                    label: 'W',
                    value: page.width,
                    min: 1,
                    decimals: decimals,
                    tooltip: 'Page width (${page.unit.symbol})',
                    onChanged: (v) => _resize(editor, page, width: v),
                  ),
                  NumberField(
                    label: 'H',
                    value: page.height,
                    min: 1,
                    decimals: decimals,
                    tooltip: 'Page height (${page.unit.symbol})',
                    onChanged: (v) => _resize(editor, page, height: v),
                  ),
                ],
              ),
            ],
          ),
        ),
        PanelSection(
          title: 'Background',
          trailing: [
            if (background == null)
              OcxIconButton(
                icon: Icons.add,
                tooltip: 'Add background colour',
                onPressed:
                    () => editor.updatePage(
                      page.copyWith(
                        background: const SolidBackground(ArgbColor.white),
                      ),
                      label: 'Background',
                    ),
              ),
          ],
          child:
              background == null
                  ? Text(
                    'Transparent',
                    style: OcxText.caption(
                      context,
                    ).copyWith(color: c.textTertiary),
                  )
                  : ColorRow(
                    color: background,
                    onChanged:
                        (color) => editor.updatePage(
                          page.copyWith(background: SolidBackground(color)),
                          label: 'Background',
                        ),
                    trailing: OcxIconButton(
                      icon: Icons.remove,
                      tooltip: 'Make transparent',
                      onPressed:
                          () => editor.updatePage(
                            page.copyWith(
                              background: const TransparentBackground(),
                            ),
                            label: 'Background',
                          ),
                    ),
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
    final m = page.margins;
    final fits = m.left + m.right <= w && m.top + m.bottom <= h;
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
    style: OcxText.body(context),
    decoration: InputDecoration(hintText: widget.hint),
    onSubmitted: widget.onSubmitted,
  );
}
