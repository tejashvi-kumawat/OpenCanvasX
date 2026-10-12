import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:renderer/renderer.dart';

import '../theme/ocx_theme.dart';

/// 28 px icon button with a 16 px icon and a required tooltip
/// (design-system.md §6).
class OcxIconButton extends StatelessWidget {
  const OcxIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.size = Chrome.control,
    this.iconSize = Chrome.icon,
    this.color,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final double size;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? c.accentSubtle : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.xs),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(Radii.xs),
          child: SizedBox.square(
            dimension: size,
            child: Icon(
              icon,
              size: iconSize,
              color:
                  !enabled
                      ? c.textTertiary.withValues(alpha: 0.6)
                      : selected
                      ? c.accent
                      : (color ?? c.text),
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled group in a side panel: header row (11 px semibold + trailing
/// actions), content, divider below (design-system.md §5).
class PanelSection extends StatelessWidget {
  const PanelSection({
    required this.title,
    this.child,
    this.trailing = const [],
    this.divider = true,
    super.key,
  });

  final String title;
  final Widget? child;
  final List<Widget> trailing;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            Space.md,
            Space.sm,
            Space.sm,
            child == null ? Space.sm : Space.xs,
          ),
          child: SizedBox(
            height: Chrome.control,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: OcxText.caption(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...trailing,
              ],
            ),
          ),
        ),
        if (child case final content?)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
            child: content,
          ),
        if (divider) const Divider(),
      ],
    );
  }
}

/// Equal-width children separated by 8 px; rows inside a section are 8 px
/// apart (use [FieldColumn]).
class FieldRow extends StatelessWidget {
  const FieldRow({required this.children, this.flex, super.key});

  final List<Widget> children;

  /// Optional flex per child; defaults to 1 each.
  final List<int>? flex;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, child) in children.indexed) ...[
        if (i > 0) const SizedBox(width: Space.sm),
        Expanded(flex: flex?[i] ?? 1, child: child),
      ],
    ],
  );
}

/// Vertical stack of field rows with 8 px gaps.
class FieldColumn extends StatelessWidget {
  const FieldColumn({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, child) in children.indexed) ...[
        if (i > 0) const SizedBox(height: Space.sm),
        child,
      ],
    ],
  );
}

/// One option of an [OcxSelect].
class SelectOption<T> {
  const SelectOption(this.value, this.label, {this.trailing});

  final T value;
  final String label;

  /// Secondary text on the right of the menu item (e.g. a size).
  final String? trailing;
}

/// Compact dropdown (28 px) that opens a menu (design-system.md §6).
class OcxSelect<T> extends StatelessWidget {
  const OcxSelect({
    required this.value,
    required this.options,
    required this.onChanged,
    this.label,
    this.tooltip,
    super.key,
  });

  final T? value;
  final List<SelectOption<T>> options;
  final ValueChanged<T> onChanged;

  /// Text shown when [value] is not among the options (e.g. "Mixed").
  final String? label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final current = options.where((o) => o.value == value).firstOrNull;
    final field = MenuAnchor(
      menuChildren: [
        for (final option in options)
          MenuItemButton(
            onPressed: () => onChanged(option.value),
            leadingIcon: Icon(
              Icons.check,
              size: Chrome.icon,
              color: option.value == value ? c.accent : Colors.transparent,
            ),
            trailingIcon:
                option.trailing == null
                    ? null
                    : Text(option.trailing!, style: OcxText.caption(context)),
            child: Text(option.label),
          ),
      ],
      builder:
          (context, controller, _) => Material(
            color: c.surfaceSunken,
            borderRadius: BorderRadius.circular(Radii.xs),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.xs),
              onTap:
                  () =>
                      controller.isOpen
                          ? controller.close()
                          : controller.open(),
              child: SizedBox(
                height: Chrome.control,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: Space.sm,
                    right: Space.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          current?.label ?? label ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OcxText.body(context),
                        ),
                      ),
                      Icon(
                        Icons.expand_more,
                        size: Chrome.icon,
                        color: c.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
    return tooltip == null ? field : Tooltip(message: tooltip, child: field);
  }
}

/// One item of an [OcxSegmented].
class Segment<T> {
  const Segment(this.value, this.icon, this.tooltip);

  final T value;
  final IconData icon;
  final String tooltip;
}

/// Compact icon-only segmented control (28 px track).
class OcxSegmented<T> extends StatelessWidget {
  const OcxSegmented({
    required this.value,
    required this.segments,
    required this.onChanged,
    super.key,
  });

  final T? value;
  final List<Segment<T>> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    return Container(
      height: Chrome.control,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.xs),
      ),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: Tooltip(
                message: segment.tooltip,
                child: GestureDetector(
                  onTap: () => onChanged(segment.value),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      decoration: BoxDecoration(
                        color:
                            segment.value == value
                                ? c.surface
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(3),
                        border:
                            segment.value == value
                                ? Border.all(color: c.border)
                                : null,
                      ),
                      child: Icon(
                        segment.icon,
                        size: Chrome.icon,
                        color:
                            segment.value == value ? c.text : c.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Default palette offered in colour popovers (original selection).
final List<ArgbColor> defaultPalette = [
  for (final v in const [
    0xFF000000, 0xFF3D424D, 0xFF8A909C, 0xFFC4C9D4, 0xFFF0F1F4, 0xFFFFFFFF, //
    0xFF3256F0, 0xFF1F8EF1, 0xFF14A3A3, 0xFF1F9D55, 0xFF7CB518, 0xFFF2C14E,
    0xFFF28A30, 0xFFE5484D, 0xFFD6409F, 0xFF8E4EC6, 0xFF6E56CF, 0xFF8D6E63,
  ])
    ArgbColor(v),
];

String hexOf(ArgbColor c) {
  String two(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
  return '${two(c.red)}${two(c.green)}${two(c.blue)}';
}

/// Fill/stroke row: swatch (opens a palette popover), hex input and alpha
/// percentage (design-system.md §5 "Fill").
class ColorRow extends StatefulWidget {
  const ColorRow({
    required this.color,
    required this.onChanged,
    this.trailing,
    super.key,
  });

  final ArgbColor color;
  final ValueChanged<ArgbColor> onChanged;
  final Widget? trailing;

  @override
  State<ColorRow> createState() => _ColorRowState();
}

class _ColorRowState extends State<ColorRow> {
  late final TextEditingController _hex = TextEditingController(
    text: hexOf(widget.color),
  );
  late final TextEditingController _alpha = TextEditingController(
    text: _alphaText(widget.color),
  );
  final FocusNode _hexFocus = FocusNode();
  final FocusNode _alphaFocus = FocusNode();
  final MenuController _menu = MenuController();

  static String _alphaText(ArgbColor c) => '${(c.alpha / 255 * 100).round()}';

  @override
  void initState() {
    super.initState();
    _hexFocus.addListener(() {
      if (!_hexFocus.hasFocus) _commitHex();
    });
    _alphaFocus.addListener(() {
      if (!_alphaFocus.hasFocus) _commitAlpha();
    });
  }

  @override
  void didUpdateWidget(ColorRow old) {
    super.didUpdateWidget(old);
    if (old.color != widget.color) {
      if (!_hexFocus.hasFocus) _hex.text = hexOf(widget.color);
      if (!_alphaFocus.hasFocus) _alpha.text = _alphaText(widget.color);
    }
  }

  @override
  void dispose() {
    _hex.dispose();
    _alpha.dispose();
    _hexFocus.dispose();
    _alphaFocus.dispose();
    super.dispose();
  }

  void _commitHex() {
    final cleaned = _hex.text.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleaned)) {
      _hex.text = hexOf(widget.color);
      return;
    }
    final next = ArgbColor(
      (widget.color.alpha << 24) | int.parse(cleaned, radix: 16),
    );
    if (next != widget.color) widget.onChanged(next);
  }

  void _commitAlpha() {
    final value = int.tryParse(_alpha.text.trim().replaceAll('%', ''));
    if (value == null) {
      _alpha.text = _alphaText(widget.color);
      return;
    }
    final a = (value.clamp(0, 100) / 100 * 255).round();
    final next = ArgbColor((a << 24) | (widget.color.value & 0xFFFFFF));
    _alpha.text = _alphaText(next);
    if (next != widget.color) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: Chrome.control,
            decoration: BoxDecoration(
              color: c.surfaceSunken,
              borderRadius: BorderRadius.circular(Radii.xs),
            ),
            child: Row(
              children: [
                MenuAnchor(
                  controller: _menu,
                  menuChildren: [
                    _PalettePanel(
                      selected: widget.color,
                      onPick: (color) {
                        _menu.close();
                        widget.onChanged(
                          ArgbColor(
                            (widget.color.alpha << 24) |
                                (color.value & 0xFFFFFF),
                          ),
                        );
                      },
                    ),
                  ],
                  builder:
                      (context, controller, _) => Tooltip(
                        message: 'Choose colour',
                        child: InkWell(
                          onTap:
                              () =>
                                  controller.isOpen
                                      ? controller.close()
                                      : controller.open(),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: _Swatch(color: widget.color, size: 16),
                          ),
                        ),
                      ),
                ),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _hex,
                    focusNode: _hexFocus,
                    style: OcxText.body(context),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
                      LengthLimitingTextInputFormatter(7),
                    ],
                    onSubmitted: (_) => _commitHex(),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(vertical: 7),
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: TextField(
                    controller: _alpha,
                    focusNode: _alphaFocus,
                    textAlign: TextAlign.right,
                    style: OcxText.body(context),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    onSubmitted: (_) => _commitAlpha(),
                    decoration: const InputDecoration(
                      suffixText: '%',
                      contentPadding: EdgeInsets.only(
                        right: Space.sm,
                        top: 7,
                        bottom: 7,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.trailing case final trailing?) ...[
          const SizedBox(width: Space.xs),
          trailing,
        ],
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.size});

  final ArgbColor color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: toUiColor(color),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: context.ocx.borderStrong),
    ),
  );
}

class _PalettePanel extends StatelessWidget {
  const _PalettePanel({required this.selected, required this.onPick});

  final ArgbColor selected;
  final ValueChanged<ArgbColor> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    return Padding(
      padding: const EdgeInsets.all(Space.sm),
      child: SizedBox(
        width: 6 * 28,
        child: Wrap(
          children: [
            for (final color in defaultPalette)
              Tooltip(
                message: '#${hexOf(color)}',
                child: InkWell(
                  onTap: () => onPick(color),
                  borderRadius: BorderRadius.circular(Radii.xs),
                  child: Container(
                    width: 28,
                    height: 28,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.xs),
                      border: Border.all(
                        color:
                            (color.value & 0xFFFFFF) ==
                                    (selected.value & 0xFFFFFF)
                                ? c.accent
                                : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: _Swatch(color: color, size: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
