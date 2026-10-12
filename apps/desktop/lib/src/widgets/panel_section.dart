import 'package:flutter/material.dart';

import '../theme/ocx_theme.dart';

/// Titled group of controls in side panels and the inspector.
class PanelSection extends StatelessWidget {
  const PanelSection({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 24,
            child: Row(
              children: [
                Text(title.toUpperCase(), style: theme.textTheme.labelSmall),
                const Spacer(),
                if (trailing case final widget?) widget,
              ],
            ),
          ),
          const SizedBox(height: Space.sm),
          child,
        ],
      ),
    );
  }
}

/// Row of equal-width children with a small gap.
class FieldRow extends StatelessWidget {
  const FieldRow({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, child) in children.indexed) ...[
        if (i > 0) const SizedBox(width: Space.sm),
        Expanded(child: child),
      ],
    ],
  );
}

/// Square icon button used in compact tool rows.
class ToolIconButton extends StatelessWidget {
  const ToolIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ocx = context.ocx;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? ocx.selectedFill : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: SizedBox(
            height: 34,
            child: Center(
              child: Icon(
                icon,
                size: 19,
                color:
                    onPressed == null
                        ? ocx.subtleText.withValues(alpha: 0.5)
                        : (selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
