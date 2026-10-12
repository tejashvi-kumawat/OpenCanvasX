import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';

import '../theme/ocx_theme.dart';
import '../widgets/controls.dart';
import '../widgets/number_field.dart';
import 'preset_frame.dart';

/// What the user asked to create.
class NewDesignRequest {
  const NewDesignRequest({required this.title, required this.page});

  final String title;
  final DesignPage page;
}

/// Opens the size picker (P1.2.3). Returns `null` if cancelled.
Future<NewDesignRequest?> showCreateDesignDialog(
  BuildContext context, {
  PagePreset? initial,
  bool customSize = false,
}) => showDialog<NewDesignRequest>(
  context: context,
  builder: (_) => _CreateDesignDialog(initial: initial, customSize: customSize),
);

/// Largest page side accepted, in reference pixels (≈ 8.5 m at 96 DPI).
const double _maxSidePx = 32000;

class _CreateDesignDialog extends StatefulWidget {
  const _CreateDesignDialog({this.initial, this.customSize = false});

  final PagePreset? initial;
  final bool customSize;

  @override
  State<_CreateDesignDialog> createState() => _CreateDesignDialogState();
}

class _CreateDesignDialogState extends State<_CreateDesignDialog> {
  PresetCategory? _category;
  late bool _custom = widget.customSize;
  late PagePreset _preset = widget.initial ?? pagePresets.first;
  final TextEditingController _title = TextEditingController();
  double _width = 1200;
  double _height = 800;
  LengthUnit _unit = LengthUnit.px;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String? get _customError {
    double px(double v) => convertLength(v, from: _unit, to: LengthUnit.px);
    if (_width <= 0 || _height <= 0) {
      return 'Width and height must be greater than zero.';
    }
    if (px(_width) > _maxSidePx || px(_height) > _maxSidePx) {
      return 'That is larger than OpenCanvasX supports.';
    }
    return null;
  }

  void _create() {
    if (_custom && _customError != null) return;
    final id = PageId.generate();
    final page =
        _custom
            ? DesignPage(
              id: id,
              width: _width,
              height: _height,
              unit: _unit,
              dpi: _unit == LengthUnit.px ? defaultDpi : 300,
            )
            : _preset.createPage(id);
    final typed = _title.text.trim();
    Navigator.pop(
      context,
      NewDesignRequest(
        title:
            typed.isNotEmpty
                ? typed
                : (_custom
                    ? 'Untitled design'
                    : 'Untitled ${_preset.name.toLowerCase()}'),
        page: page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final presets =
        _category == null
            ? pagePresets
            : pagePresets.where((p) => p.category == _category).toList();
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 760,
        height: 520,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.xl,
                Space.lg,
                Space.md,
                Space.lg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Create design',
                      style: OcxText.heading(context),
                    ),
                  ),
                  OcxIconButton(
                    icon: Icons.close,
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 180,
                    color: c.background,
                    padding: const EdgeInsets.all(Space.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Category(
                          label: 'All sizes',
                          selected: !_custom && _category == null,
                          onTap:
                              () => setState(() {
                                _custom = false;
                                _category = null;
                              }),
                        ),
                        for (final category in PresetCategory.values)
                          _Category(
                            label: category.label,
                            selected: !_custom && _category == category,
                            onTap:
                                () => setState(() {
                                  _custom = false;
                                  _category = category;
                                }),
                          ),
                        const Divider(height: Space.lg),
                        _Category(
                          label: 'Custom size',
                          selected: _custom,
                          onTap: () => setState(() => _custom = true),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child:
                        _custom
                            ? _customForm(context)
                            : GridView.builder(
                              padding: const EdgeInsets.all(Space.lg),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 140,
                                    mainAxisSpacing: Space.sm,
                                    crossAxisSpacing: Space.sm,
                                    childAspectRatio: 0.95,
                                  ),
                              itemCount: presets.length,
                              itemBuilder:
                                  (context, i) => _PresetOption(
                                    preset: presets[i],
                                    selected: presets[i].id == _preset.id,
                                    onTap:
                                        () => setState(
                                          () => _preset = presets[i],
                                        ),
                                    onDoubleTap: () {
                                      setState(() => _preset = presets[i]);
                                      _create();
                                    },
                                  ),
                            ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Row(
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _title,
                      style: OcxText.body(context),
                      onSubmitted: (_) => _create(),
                      decoration: InputDecoration(
                        hintText:
                            _custom
                                ? 'Design name'
                                : 'Untitled ${_preset.name.toLowerCase()}',
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Text(
                      _custom
                          ? '${_fmt(_width)} × ${_fmt(_height)} ${_unit.symbol}'
                          : _preset.sizeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OcxText.caption(
                        context,
                      ).copyWith(color: c.textTertiary),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: Space.sm),
                  FilledButton(
                    onPressed: _custom && _customError != null ? null : _create,
                    child: const Text('Create design'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customForm(BuildContext context) {
    final c = context.ocx;
    final error = _customError;
    return Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Custom size', style: OcxText.title(context)),
          const SizedBox(height: Space.xs),
          Text(
            'Pixels for screens; millimetres, centimetres or inches for print.',
            style: OcxText.body(context).copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Space.lg),
          SizedBox(
            width: 320,
            child: FieldColumn(
              children: [
                FieldRow(
                  children: [
                    NumberField(
                      label: 'W',
                      value: _width,
                      min: 0,
                      decimals: 2,
                      tooltip: 'Width',
                      onChanged: (v) => setState(() => _width = v),
                    ),
                    NumberField(
                      label: 'H',
                      value: _height,
                      min: 0,
                      decimals: 2,
                      tooltip: 'Height',
                      onChanged: (v) => setState(() => _height = v),
                    ),
                  ],
                ),
                OcxSelect<LengthUnit>(
                  value: _unit,
                  tooltip: 'Unit',
                  options: const [
                    SelectOption(LengthUnit.px, 'Pixels (px)'),
                    SelectOption(LengthUnit.mm, 'Millimetres (mm)'),
                    SelectOption(LengthUnit.cm, 'Centimetres (cm)'),
                    SelectOption(LengthUnit.inch, 'Inches (in)'),
                    SelectOption(LengthUnit.pt, 'Points (pt)'),
                  ],
                  onChanged: (u) => setState(() => _unit = u),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          PresetFrame(
            width: _width > 0 ? _width : 1,
            height: _height > 0 ? _height : 1,
            category: null,
            box: 96,
          ),
          if (error != null) ...[
            const SizedBox(height: Space.md),
            Text(error, style: OcxText.body(context).copyWith(color: c.danger)),
          ],
        ],
      ),
    );
  }
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

class _Category extends StatelessWidget {
  const _Category({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    return Material(
      color: selected ? c.accentSubtle : Colors.transparent,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Container(
          height: Chrome.button,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: Space.sm),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (selected
                    ? OcxText.bodyStrong(context)
                    : OcxText.body(context))
                .copyWith(color: selected ? c.accent : null),
          ),
        ),
      ),
    );
  }
}

class _PresetOption extends StatelessWidget {
  const _PresetOption({
    required this.preset,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final PagePreset preset;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(
          color: selected ? c.accent : c.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.all(Space.sm),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: PresetFrame(
                    width: preset.width,
                    height: preset.height,
                    category: preset.category,
                    selected: selected,
                  ),
                ),
              ),
              Text(
                preset.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OcxText.bodyStrong(context),
              ),
              Text(
                preset.sizeLabel,
                maxLines: 1,
                style: OcxText.caption(
                  context,
                ).copyWith(color: c.textTertiary, fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
