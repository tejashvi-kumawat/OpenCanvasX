import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/ocx_theme.dart';
import '../widgets/controls.dart';
import '../widgets/number_field.dart';
import '../widgets/object_icons.dart';
import '../providers.dart';
import '../widgets/color_picker.dart';
import 'fill_editor.dart';
import 'editor_controller.dart';

/// System fonts offered after the bundled ones until local font discovery
/// lands (P1.5.5). Families that are not installed fall back to the
/// default UI font.
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
    return ColorPickerScope(
      documentColors: documentColors(session.document),
      customColors: ref.watch(customPaletteProvider),
      onSaveColor: ref.read(customPaletteProvider.notifier).add,
      // The next canvas click samples a colour (the open picker closes on
      // that click as it lands outside the menu).
      onEyedropper:
          (onPicked) => ref.read(eyedropperProvider.notifier).pick = onPicked,
      child: Container(
        width: Chrome.inspector,
        color: context.ocx.surface,
        child: ListView(
          padding: const EdgeInsets.only(bottom: Space.xl),
          children:
              selected.isEmpty
                  ? [_PageInspector(session: session)]
                  : [_SelectionInspector(session: session, objects: selected)],
        ),
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
    final anyGroup = objects.any((o) => o.type == ObjectType.group);

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
        if (single?.payload case ImagePayload(:final assetHash))
          _AssetSource(
            info: widget.session.document.assets[assetHash],
            colorable: single!.style?.fill != null,
          ),
        _AlignmentSection(count: objects.length),
        if (single != null) _layoutSection(single, unit, decimals, step),
        if (single != null &&
            (isComponent(single) || single.type == ObjectType.instance))
          _ComponentSection(session: widget.session, object: single),
        if (single?.payload case final FramePayload frame)
          _frameSection(single!, frame),
        if (single != null && isMaskGroup(single))
          _ImageFrameNote(object: single, document: widget.session.document),
        if (objects.every(
          (o) =>
              o.payload is ImagePayload &&
              widget
                      .session
                      .document
                      .assets[(o.payload as ImagePayload).assetHash]
                      ?.mime !=
                  'image/svg+xml',
        ))
          _AdjustSection(objects: objects),
        if (allText) _TextSection(texts: texts, unit: unit),
        if (allText && single != null)
          _ContrastNote(
            text: single.style?.fill?.representative,
            background: _backgroundBehind(
              widget.session.document,
              page,
              single,
            ),
          ),
        if (single != null && page.isBoard)
          _InteractionSection(session: widget.session, object: single),
        _appearanceSection(objects),
        if (!allLines && !anyGroup) _fillSection(objects, allText),
        if (single != null && !anyGroup) _strokeSection(single, style, unit),
      ],
    );
  }

  /// Frame options: size presets and clipping (ADR-0007).
  Widget _frameSection(DesignObject o, FramePayload frame) {
    final editor = ref.read(editorProvider.notifier);
    final presets = framePresets;
    final t = o.transform;
    final current =
        presets
            .where((p) => p.width == t.width && p.height == t.height)
            .firstOrNull;
    return PanelSection(
      title: 'Frame',
      child: FieldColumn(
        children: [
          OcxSelect<String>(
            value: current?.id ?? '',
            tooltip: 'Frame size',
            options: [
              const SelectOption('', 'Custom'),
              for (final p in presets)
                SelectOption(p.id, '${p.name} · ${p.sizeLabel}'),
            ],
            onChanged: (id) {
              final preset = presets.where((p) => p.id == id).firstOrNull;
              if (preset == null) return;
              editor.updateSelected(
                (x) => x.copyWith(
                  transform: x.transform.copyWith(
                    width: preset.width,
                    height: preset.height,
                  ),
                ),
                label: 'Resize frame',
              );
            },
          ),
          Row(
            children: [
              Expanded(
                child: Text('Clip content', style: OcxText.body(context)),
              ),
              Switch(
                value: frame.clipContent,
                onChanged:
                    (v) => editor.updateSelected(
                      (x) =>
                          x.copyWith(payload: frame.copyWith(clipContent: v)),
                      label: v ? 'Clip content' : 'Show overflow',
                    ),
              ),
            ],
          ),
        ],
      ),
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
        o.type == ObjectType.rect ||
        o.type == ObjectType.roundedRect ||
        o.type == ObjectType.frame;
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

  /// Shows [fill] on the selection live (one gesture until committed).
  void _previewFill(Fill fill) {
    final editor = ref.read(editorProvider.notifier);
    if (!editor.isGestureActive) editor.beginGesture();
    editor.previewObjects([
      for (final o in widget.objects)
        o.copyWith(
          style: ObjectStyle(
            fill: fill,
            stroke: (o.style ?? ObjectStyle.none).stroke,
            cornerRadius: (o.style ?? ObjectStyle.none).cornerRadius,
          ),
        ),
    ]);
  }

  Widget _fillSection(List<DesignObject> objects, bool allText) {
    final fills = {for (final o in objects) o.style?.fill};
    final fill = fills.length == 1 ? fills.first : null;
    final mixed = fills.length > 1;
    void setFill(Fill? f) {
      final editor = ref.read(editorProvider.notifier);
      if (editor.isGestureActive) {
        editor.previewObjects([
          for (final o in widget.objects)
            o.copyWith(
              style: ObjectStyle(
                fill: f,
                stroke: (o.style ?? ObjectStyle.none).stroke,
                cornerRadius: (o.style ?? ObjectStyle.none).cornerRadius,
              ),
            ),
        ]);
        editor.endGesture('Fill');
        return;
      }
      _style(
        (s) => ObjectStyle(
          fill: f,
          stroke: s.stroke,
          cornerRadius: s.cornerRadius,
        ),
        'Fill',
      );
    }

    return PanelSection(
      title: allText ? 'Text colour' : 'Fill',
      trailing: [
        if (fill == null && !mixed)
          OcxIconButton(
            icon: Icons.add,
            tooltip: 'Add fill',
            onPressed: () => setFill(SolidFill(defaultShapeFill)),
          ),
      ],
      child:
          mixed
              ? Text(
                'Mixed — pick a colour to apply to all',
                style: OcxText.caption(context),
              )
              : fill == null
              ? null
              : FillEditor(
                fill: fill,
                onChanged: setFill,
                onPreview: _previewFill,
                onRemove: () => setFill(null),
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
            options: [
              for (final f in [
                ...?ref.watch(bundledFontsProvider).value?.map((f) => f.family),
                ...fontFamilies,
              ])
                SelectOption(f, f),
            ],
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
    final presets =
        pagePresets
            .where((p) => p.unit == page.unit && p.kind == PageKind.fixed)
            .toList();
    final matching =
        presets
            .where((p) => p.width == page.width && p.height == page.height)
            .firstOrNull;
    final c = context.ocx;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          icon:
              page.isBoard
                  ? Icons.dashboard_outlined
                  : Icons.insert_drive_file_outlined,
          title: page.name.isEmpty ? 'Page $index' : page.name,
          subtitle:
              page.isBoard
                  ? 'Free canvas'
                  : page.unit == LengthUnit.px
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
              if (page.isBoard)
                Text(
                  'Boards have no edges. Add frames (F) for screens, '
                  'posts or slides.',
                  style: OcxText.caption(
                    context,
                  ).copyWith(fontWeight: FontWeight.w400),
                ),
              if (presets.isNotEmpty && !page.isBoard)
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
              if (!page.isBoard)
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

/// Where a placed image came from and under which licence (P2.1.4).
class _AssetSource extends ConsumerWidget {
  const _AssetSource({required this.info, required this.colorable});

  final AssetInfo? info;
  final bool colorable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ocx;
    final info = this.info;
    if (info == null) return const SizedBox.shrink();
    final ref0 = info.licenseRef;
    String text;
    if (ref0 != null && ref0.startsWith('pack:')) {
      final id = ref0.substring(5).split('@').first;
      final pack = ref.watch(assetCatalogProvider).value?.pack(id);
      text =
          pack == null
              ? 'From the $id pack'
              : pack.license.attributionRequired
              ? '${pack.license.attribution}.'
              : '${pack.name} ${pack.version} · ${pack.license.spdx} · '
                  '${pack.license.author}';
    } else {
      final kind = switch (info.mime) {
        'image/svg+xml' => 'SVG',
        'image/png' => 'PNG',
        'image/jpeg' => 'JPEG',
        'image/webp' => 'WebP',
        'image/gif' => 'GIF',
        'image/bmp' => 'BMP',
        _ => info.mime,
      };
      final kb = (info.byteLength / 1024).toStringAsFixed(0);
      text = 'Uploaded $kind · $kb KB · stored in this design';
    }
    return PanelSection(
      title: 'Source',
      child: Text(
        colorable ? '$text\nRecolour it with Fill below.' : text,
        style: OcxText.caption(
          context,
        ).copyWith(color: c.textSecondary, fontWeight: FontWeight.w400),
      ),
    );
  }
}

/// The solid colour behind [object]: the nearest enclosing frame's fill,
/// else the page background (white when transparent).
ArgbColor _backgroundBehind(
  DesignDocument document,
  DesignPage page,
  DesignObject object,
) {
  var parent = object.parentId;
  while (parent != null) {
    final p = document.objects[parent];
    if (p == null) break;
    if (p.type == ObjectType.frame && p.style?.fill != null) {
      return p.style!.fill!.representative;
    }
    parent = p.parentId;
  }
  return switch (page.background) {
    SolidBackground(:final color) => color,
    _ => ArgbColor.white,
  };
}

/// WCAG contrast of text against what is behind it (P1.7.4).
class _ContrastNote extends StatelessWidget {
  const _ContrastNote({required this.text, required this.background});

  final ArgbColor? text;
  final ArgbColor background;

  @override
  Widget build(BuildContext context) {
    final color = text;
    if (color == null) return const SizedBox.shrink();
    final c = context.ocx;
    final ratio = contrastRatio(
      ArgbColor(color.value | 0xFF000000),
      ArgbColor(background.value | 0xFF000000),
    );
    final (label, tone) = switch (ratio) {
      >= 7 => ('AAA', c.success),
      >= 4.5 => ('AA', c.success),
      >= 3 => ('AA large text only', c.warning),
      _ => ('Too low for reading', c.danger),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.sm,
        Space.md,
        Space.sm,
      ),
      child: Row(
        children: [
          Icon(
            ratio >= 4.5 ? Icons.check_circle_outline : Icons.error_outline,
            size: 14,
            color: tone,
          ),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Tooltip(
              message:
                  'Contrast with the background behind this text '
                  '(WCAG 2: 4.5:1 for body text, 3:1 for large text).',
              child: Text(
                'Contrast ${ratio.toStringAsFixed(1)}:1 · $label',
                style: OcxText.caption(context).copyWith(color: tone),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Colours used in [document] (fills, gradient stops, strokes, page
/// backgrounds), most used first (P1.7.2).
List<ArgbColor> documentColors(DesignDocument document) {
  final counts = <ArgbColor, int>{};
  void add(ArgbColor c) {
    final opaque = ArgbColor(c.value | 0xFF000000);
    counts[opaque] = (counts[opaque] ?? 0) + 1;
  }

  for (final o in document.objects.values) {
    switch (o.style?.fill) {
      case SolidFill(:final color):
        add(color);
      case LinearGradientFill(:final stops) || RadialGradientFill(:final stops):
        for (final s in stops) {
          add(s.color);
        }
      case null:
        break;
    }
    if (o.style?.stroke case final stroke?) add(stroke.color);
  }
  for (final page in document.pages) {
    if (page.background case SolidBackground(:final color)) add(color);
  }
  final sorted =
      counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return [for (final e in sorted.take(18)) e.key];
}

/// Prototype interaction of the selected object (on boards): click → go
/// to a frame, with a transition.
class _InteractionSection extends ConsumerWidget {
  const _InteractionSection({required this.session, required this.object});

  final EditorSession session;
  final DesignObject object;

  static String _transitionLabel(PrototypeTransition t) => switch (t) {
    PrototypeTransition.instant => 'Instant',
    PrototypeTransition.dissolve => 'Dissolve',
    PrototypeTransition.slideLeft => 'Slide left',
    PrototypeTransition.slideRight => 'Slide right',
    PrototypeTransition.slideUp => 'Slide up',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.read(editorProvider.notifier);
    final page = session.activePage;
    final document = session.document;
    final frames = [
      for (final id in page.objectIds)
        if (document.objects[id] case final o?
            when o.type == ObjectType.frame && o.id != object.id)
          o,
    ];
    if (frames.isEmpty) return const SizedBox.shrink();
    final link = page.links.where((l) => l.source == object.id).firstOrNull;
    return PanelSection(
      title: 'Prototype',
      trailing: [
        if (link == null)
          OcxIconButton(
            icon: Icons.add_link,
            tooltip: 'Go to a frame on click',
            onPressed: () => editor.setLink(object.id, frames.first.id),
          )
        else
          OcxIconButton(
            icon: Icons.link_off,
            tooltip: 'Remove link',
            onPressed: () => editor.setLink(object.id, null),
          ),
      ],
      child:
          link == null
              ? null
              : FieldColumn(
                children: [
                  OcxSelect<ObjectId>(
                    value: link.target,
                    label: 'Missing frame',
                    tooltip: 'On click, go to',
                    options: [
                      for (final f in frames)
                        SelectOption(f.id, layerName(document, page, f)),
                    ],
                    onChanged:
                        (target) => editor.setLink(
                          object.id,
                          target,
                          transition: link.transition,
                        ),
                  ),
                  OcxSelect<PrototypeTransition>(
                    value: link.transition,
                    tooltip: 'Transition',
                    options: [
                      for (final t in PrototypeTransition.values)
                        SelectOption(t, _transitionLabel(t)),
                    ],
                    onChanged:
                        (t) => editor.setLink(
                          object.id,
                          link.target,
                          transition: t,
                        ),
                  ),
                  Text(
                    'Press Present (F5) and click this to follow the link.',
                    style: OcxText.caption(context).copyWith(
                      color: context.ocx.textTertiary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
    );
  }
}

/// Main component or instance actions (Figma-style components).
class _ComponentSection extends ConsumerWidget {
  const _ComponentSection({required this.session, required this.object});

  final EditorSession session;
  final DesignObject object;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.read(editorProvider.notifier);
    final c = context.ocx;
    final document = session.document;
    if (isComponent(object)) {
      final count =
          document.objects.values
              .where(
                (o) =>
                    o.payload is InstancePayload &&
                    (o.payload as InstancePayload).componentId == object.id,
              )
              .length;
      return PanelSection(
        title: 'Main component',
        child: FieldColumn(
          children: [
            Text(
              count == 0
                  ? 'No instances yet. Changes here update every instance.'
                  : '$count instance${count == 1 ? '' : 's'} follow this '
                      'component.',
              style: OcxText.caption(
                context,
              ).copyWith(color: c.textSecondary, fontWeight: FontWeight.w400),
            ),
            OutlinedButton.icon(
              onPressed: () => editor.insertInstance(object.id),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Create instance'),
            ),
          ],
        ),
      );
    }
    final payload = object.payload as InstancePayload;
    final component = document.objects[payload.componentId];
    return PanelSection(
      title: 'Instance',
      child: FieldColumn(
        children: [
          Text(
            component == null
                ? 'The main component was deleted.'
                : 'Of ${component.name ?? 'Component'}',
            style: OcxText.caption(context).copyWith(
              color: component == null ? c.danger : c.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
          Row(
            children: [
              if (component != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => editor.goToMainComponent(object.id),
                    child: const Text('Go to main'),
                  ),
                ),
              if (component != null) const SizedBox(width: Space.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: component == null ? null : editor.detachSelection,
                  child: const Text('Detach'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Image adjustments (P3.3.1, P3.3.2): one-click looks and sliders,
/// previewed live while dragging and recorded as one undo step.
class _AdjustSection extends ConsumerWidget {
  const _AdjustSection({required this.objects});

  final List<DesignObject> objects;

  static const _sliders = [
    ('brightness', 'Brightness', -100.0, 100.0),
    ('contrast', 'Contrast', -100.0, 100.0),
    ('saturation', 'Saturation', -100.0, 100.0),
    ('exposure', 'Exposure', -100.0, 100.0),
    ('temperature', 'Temperature', -100.0, 100.0),
    ('tint', 'Tint', -100.0, 100.0),
    ('hue', 'Hue', -180.0, 180.0),
    ('sepia', 'Sepia', 0.0, 100.0),
    ('blur', 'Blur', 0.0, 100.0),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.read(editorProvider.notifier);
    final c = context.ocx;
    final first = (objects.first.payload as ImagePayload).adjust;
    final values = first.toMap();
    return PanelSection(
      title: 'Adjust',
      trailing: [
        if (!first.isNone)
          OcxIconButton(
            icon: Icons.restart_alt,
            tooltip: 'Reset adjustments',
            onPressed:
                () => editor.commitAdjust(
                  (_) => ImageAdjustments.none,
                  label: 'Reset adjustments',
                ),
          ),
      ],
      child: FieldColumn(
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final MapEntry(key: name, value: preset)
                  in imageFilterPresets.entries)
                ActionChip(
                  label: Text(name),
                  labelStyle: OcxText.caption(context),
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                      ImageAdjustments.fromMap(preset) == first
                          ? c.accentSubtle
                          : null,
                  onPressed:
                      () => editor.commitAdjust(
                        (_) => ImageAdjustments.fromMap(preset),
                        label: 'Filter $name',
                      ),
                ),
            ],
          ),
          for (final (key, label, min, max) in _sliders)
            Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    label,
                    style: OcxText.caption(
                      context,
                    ).copyWith(color: c.textSecondary),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      overlayShape: SliderComponentShape.noOverlay,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                    ),
                    child: Slider(
                      value: values[key]!.clamp(min, max),
                      min: min,
                      max: max,
                      onChanged:
                          (v) => editor.previewAdjust(
                            (a) => a.withValue(key, v.roundToDouble()),
                          ),
                      onChangeEnd:
                          (v) => editor.commitAdjust(
                            (a) => a.withValue(key, v.roundToDouble()),
                          ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 30,
                  child: Text(
                    values[key]!.round().toString(),
                    textAlign: TextAlign.right,
                    style: OcxText.caption(context),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Hints for an image frame (mask group) and replacing its photo.
class _ImageFrameNote extends ConsumerWidget {
  const _ImageFrameNote({required this.object, required this.document});

  final DesignObject object;
  final DesignDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ocx;
    final empty = object.childIds.length < 2;
    return PanelSection(
      title: 'Image frame',
      child: FieldColumn(
        children: [
          Text(
            empty
                ? 'Drop a photo from Uploads or Elements on this frame, or '
                    'upload one while it is selected.'
                : 'Double-click the photo to move or resize it inside the '
                    'frame. Upload or drop another to replace it.',
            style: OcxText.caption(
              context,
            ).copyWith(color: c.textSecondary, fontWeight: FontWeight.w400),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final files = await ref.read(imagePickerProvider)();
              if (files.isEmpty) return;
              ref
                  .read(editorProvider.notifier)
                  .insertImage(
                    files.first.bytes,
                    name: files.first.name,
                    intoFrame: object.id,
                  );
            },
            icon: const Icon(Icons.upload_outlined, size: 16),
            label: Text(empty ? 'Upload a photo' : 'Replace photo'),
          ),
        ],
      ),
    );
  }
}
