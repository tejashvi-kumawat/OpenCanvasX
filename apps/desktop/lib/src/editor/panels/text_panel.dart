import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/ocx_theme.dart';
import '../canvas_view.dart';
import '../editor_controller.dart';
import 'asset_tiles.dart';

/// A ready-made text style offered in the Text panel.
class TextPreset {
  const TextPreset(this.label, this.role, this.preview, this.restyle);

  final String label;
  final TextRole role;
  final TextStyle preview;
  final TextPayload Function(TextPayload payload) restyle;
}

TextPayload _same(TextPayload p) => p;

/// Text styles using fonts every desktop has (bundled OFL fonts are added
/// by `scripts/asset_packs` and appear in the font menu).
final List<TextPreset> textPresets = [
  TextPreset(
    'Display title',
    TextRole.heading,
    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.1),
    (p) => p.copyWith(
      text: 'Display title',
      fontWeight: 800,
      fontSize: p.fontSize * 1.4,
      letterSpacing: -p.fontSize * 0.02,
      lineHeight: 1.05,
    ),
  ),
  TextPreset(
    'Elegant serif',
    TextRole.heading,
    const TextStyle(
      fontSize: 18,
      fontFamily: 'Playfair Display',
      fontStyle: FontStyle.italic,
    ),
    (p) => p.copyWith(
      text: 'Elegant serif',
      fontFamily: 'Playfair Display',
      italic: true,
      fontWeight: 400,
    ),
  ),
  TextPreset(
    'SPACED LABEL',
    TextRole.subheading,
    const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 3,
    ),
    (p) => p.copyWith(
      text: 'SPACED LABEL',
      fontWeight: 600,
      letterSpacing: p.fontSize * 0.25,
    ),
  ),
  TextPreset(
    'Quote',
    TextRole.body,
    const TextStyle(
      fontSize: 14,
      fontFamily: 'Lora',
      fontStyle: FontStyle.italic,
    ),
    (p) => p.copyWith(
      text: '“A short quote that matters.”',
      fontFamily: 'Lora',
      italic: true,
      fontSize: p.fontSize * 1.3,
      lineHeight: 1.4,
    ),
  ),
  TextPreset(
    'Code label',
    TextRole.body,
    const TextStyle(fontSize: 12, fontFamily: 'JetBrains Mono'),
    (p) => p.copyWith(text: 'code_label', fontFamily: 'JetBrains Mono'),
  ),
  TextPreset(
    'BOLD POSTER',
    TextRole.heading,
    const TextStyle(fontSize: 22, fontFamily: 'Bebas Neue'),
    (p) => p.copyWith(
      text: 'BOLD POSTER',
      fontFamily: 'Bebas Neue',
      fontWeight: 400,
      fontSize: p.fontSize * 1.5,
      lineHeight: 1,
    ),
  ),
  TextPreset(
    'Handwritten note',
    TextRole.subheading,
    const TextStyle(fontSize: 20, fontFamily: 'Caveat'),
    (p) => p.copyWith(
      text: 'Handwritten note',
      fontFamily: 'Caveat',
      fontWeight: 500,
      fontSize: p.fontSize * 1.3,
    ),
  ),
  TextPreset(
    'Retro script',
    TextRole.heading,
    const TextStyle(fontSize: 18, fontFamily: 'Pacifico'),
    (p) => p.copyWith(
      text: 'Retro script',
      fontFamily: 'Pacifico',
      fontWeight: 400,
    ),
  ),
  TextPreset(
    'Caption',
    TextRole.body,
    const TextStyle(fontSize: 11, color: Color(0xFF5B616E)),
    (p) => p.copyWith(text: 'Caption text', fontSize: p.fontSize * 0.75),
  ),
];

/// Text (P1.5.1): add a heading, subheading or body box, or a styled
/// preset.
class TextPanel extends ConsumerWidget {
  const TextPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.read(editorProvider.notifier);
    final c = context.ocx;
    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, 0),
          child: FilledButton.icon(
            onPressed: () => editor.insertText(TextRole.body),
            icon: const Icon(Icons.title, size: Chrome.icon),
            label: const Text('Add a text box'),
          ),
        ),
        const SectionHeader(title: 'Default text styles'),
        for (final (role, style) in [
          (
            TextRole.heading,
            const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          (
            TextRole.subheading,
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          (TextRole.body, const TextStyle(fontSize: 12)),
        ])
          _TextRow(
            label: 'Add a ${role.label.toLowerCase()}',
            style: style.copyWith(color: c.text),
            drag: TextDrag(role),
            onTap: () => editor.insertText(role),
          ),
        const SectionHeader(title: 'Text presets'),
        for (final preset in textPresets)
          _TextRow(
            label: preset.label,
            style: preset.preview.copyWith(
              color: preset.preview.color ?? c.text,
            ),
            drag: TextDrag(preset.role, restyle: preset.restyle),
            onTap:
                () => editor.insertText(
                  preset.role,
                  restyle: preset.restyle == _same ? null : preset.restyle,
                ),
          ),
        Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Text(
            'Double-click text on the canvas to edit it. Fonts, sizes and '
            'spacing are in the inspector on the right.',
            style: OcxText.caption(
              context,
            ).copyWith(color: c.textTertiary, fontWeight: FontWeight.w400),
          ),
        ),
      ],
    );
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({
    required this.label,
    required this.style,
    required this.drag,
    required this.onTap,
  });

  final String label;
  final TextStyle style;
  final TextDrag drag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.sm),
      child: Draggable<ElementDrag>(
        data: drag,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Material(
          color: Colors.transparent,
          child: Text(label, style: style),
        ),
        child: Material(
          color: c.surfaceSunken,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.sm),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(
                horizontal: Space.md,
                vertical: Space.sm,
              ),
              child: Text(
                label,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
