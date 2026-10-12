import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';

import '../theme/ocx_theme.dart';
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
  /// `null` = all sizes; the custom tab is tracked separately.
  PresetCategory? _category;
  late bool _custom = widget.customSize;
  late PagePreset _preset = widget.initial ?? pagePresets.first;
  final TextEditingController _title = TextEditingController();
  double _customWidth = 1200;
  double _customHeight = 800;
  LengthUnit _customUnit = LengthUnit.px;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String? get _customError {
    double px(double v) =>
        convertLength(v, from: _customUnit, to: LengthUnit.px);
    if (_customWidth <= 0 || _customHeight <= 0) {
      return 'Width and height must be greater than zero.';
    }
    if (px(_customWidth) > _maxSidePx || px(_customHeight) > _maxSidePx) {
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
              width: _customWidth,
              height: _customHeight,
              unit: _customUnit,
              dpi: _customUnit == LengthUnit.px ? defaultDpi : 300,
            )
            : _preset.createPage(id);
    final typed = _title.text.trim();
    Navigator.pop(
      context,
      NewDesignRequest(
        title:
            typed.isEmpty
                ? (_custom ? 'Untitled design' : 'Untitled ${_preset.name}')
                : typed,
        page: page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ocx = context.ocx;
    final presets =
        _category == null
            ? pagePresets
            : pagePresets.where((p) => p.category == _category).toList();
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 820,
        height: 600,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.xl,
                Space.xl,
                Space.md,
                Space.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create a design',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pick a size to start with — you can change it later.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
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
                    width: 200,
                    color: theme.colorScheme.surfaceContainerLow,
                    padding: const EdgeInsets.all(Space.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CategoryItem(
                          label: 'All sizes',
                          icon: Icons.apps_rounded,
                          selected: !_custom && _category == null,
                          onTap:
                              () => setState(() {
                                _custom = false;
                                _category = null;
                              }),
                        ),
                        for (final category in PresetCategory.values)
                          _CategoryItem(
                            label: category.label,
                            icon: categoryIcon(category),
                            selected: !_custom && _category == category,
                            onTap:
                                () => setState(() {
                                  _custom = false;
                                  _category = category;
                                }),
                          ),
                        const Spacer(),
                        _CategoryItem(
                          label: 'Custom size',
                          icon: Icons.crop_free_rounded,
                          selected: _custom,
                          onTap: () => setState(() => _custom = true),
                        ),
                      ],
                    ),
                  ),
                  VerticalDivider(color: ocx.border),
                  Expanded(
                    child:
                        _custom
                            ? _customForm(context)
                            : GridView.builder(
                              padding: const EdgeInsets.all(Space.xl),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 170,
                                    mainAxisSpacing: Space.md,
                                    crossAxisSpacing: Space.md,
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
              padding: const EdgeInsets.all(Space.lg),
              child: Row(
                children: [
                  Flexible(
                    flex: 3,
                    child: TextField(
                      controller: _title,
                      onSubmitted: (_) => _create(),
                      decoration: InputDecoration(
                        hintText:
                            _custom
                                ? 'Design name (optional)'
                                : 'Untitled ${_preset.name}',
                        prefixIcon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.lg),
                  Flexible(
                    flex: 2,
                    child: Text(
                      _custom
                          ? '${_fmt(_customWidth)} × ${_fmt(_customHeight)} ${_customUnit.symbol}'
                          : _preset.sizeLabel,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  const SizedBox(width: Space.lg),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: Space.sm),
                  FilledButton.icon(
                    onPressed: _custom && _customError != null ? null : _create,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Create design'),
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
    final theme = Theme.of(context);
    final error = _customError;
    return Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Custom size', style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.xs),
          Text(
            'Use pixels for screens, millimetres or inches for print.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Space.xl),
          Row(
            children: [
              SizedBox(
                width: 160,
                child: NumberField(
                  label: 'Width',
                  value: _customWidth,
                  min: 0,
                  decimals: 2,
                  onChanged: (v) => setState(() => _customWidth = v),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: Space.md),
                child: Icon(Icons.close, size: 16),
              ),
              SizedBox(
                width: 160,
                child: NumberField(
                  label: 'Height',
                  value: _customHeight,
                  min: 0,
                  decimals: 2,
                  onChanged: (v) => setState(() => _customHeight = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          SegmentedButton<LengthUnit>(
            segments: [
              for (final unit in LengthUnit.values)
                ButtonSegment(value: unit, label: Text(unit.symbol)),
            ],
            selected: {_customUnit},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _customUnit = s.single),
          ),
          const SizedBox(height: Space.xl),
          PresetFrame(
            width: _customWidth > 0 ? _customWidth : 1,
            height: _customHeight > 0 ? _customHeight : 1,
            category: null,
            box: 120,
          ),
          if (error != null) ...[
            const SizedBox(height: Space.lg),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ocx = context.ocx;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? ocx.selectedFill : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: 10,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? theme.colorScheme.primary : ocx.subtleText,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected ? theme.colorScheme.primary : null,
                    ),
                  ),
                ),
              ],
            ),
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
    final theme = Theme.of(context);
    final ocx = context.ocx;
    return Material(
      color: selected ? ocx.selectedFill : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(
          color: selected ? ocx.selection : ocx.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: PresetFrame(
                    width: preset.width,
                    height: preset.height,
                    category: preset.category,
                  ),
                ),
              ),
              const SizedBox(height: Space.sm),
              Text(
                preset.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
              Text(preset.sizeLabel, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
