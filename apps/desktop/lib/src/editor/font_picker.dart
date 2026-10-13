import 'dart:async';
import 'dart:isolate';

import 'package:asset_engine/asset_engine.dart';
import 'package:asset_packs/asset_packs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/ocx_theme.dart';

/// Scans the computer's font folders; tests replace it.
final fontDiscoveryProvider = Provider<Future<List<FontFace>> Function()>(
  (ref) => () => Isolate.run(discoverSystemFontFaces),
);

/// Every installed font face (family, weight, style, file), scanned once
/// per run in the background; used for the font list and to embed fonts
/// in vector PDFs.
final systemFontFacesProvider = FutureProvider<List<FontFace>>(
  (ref) => ref.read(fontDiscoveryProvider)(),
);

/// Font families installed on this computer (P1.5.5). Starts with the
/// list found last time (setting `fonts.system`) and refreshes it in the
/// background, since scanning can take seconds.
final systemFontsProvider =
    NotifierProvider<SystemFontsController, List<String>>(
      SystemFontsController.new,
    );

class SystemFontsController extends Notifier<List<String>> {
  static const _key = 'fonts.system';
  bool _refreshing = false;

  @override
  List<String> build() {
    final cached = ref.read(appIndexProvider).settings.get(_key);
    unawaited(_refresh());
    if (cached == null || cached.isEmpty) return const [];
    return cached.split('\n');
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final fresh = familiesOf(await ref.read(systemFontFacesProvider.future));
      if (!ref.mounted) return;
      if (fresh.isNotEmpty && fresh.join('\n') != state.join('\n')) {
        ref.read(appIndexProvider).settings.set(_key, fresh.join('\n'));
        state = fresh;
      }
    } on Object {
      // Keep the cached list.
    } finally {
      _refreshing = false;
    }
  }
}

/// Common fonts shown while the computer's fonts are being scanned for
/// the first time.
const fallbackFontFamilies = [
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

/// Bundled, installed (or fallback) families, for availability checks.
Set<String> availableFontFamilies(WidgetRef ref) => {
  for (final f
      in ref.watch(bundledFontsProvider).value ?? const <BundledFont>[])
    f.family,
  ...switch (ref.watch(systemFontsProvider)) {
    final List<String> system when system.isNotEmpty => system,
    _ => fallbackFontFamilies,
  },
};

/// Whether [family] can be drawn as itself (case-insensitive).
bool isFontAvailable(Set<String> available, String family) {
  final lower = family.toLowerCase();
  return available.any((f) => f.toLowerCase() == lower);
}

/// A field showing [value] in its own font; opens a searchable list of
/// bundled and installed fonts.
class FontPickerField extends ConsumerWidget {
  const FontPickerField({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Current family, or `null` when the selection mixes fonts.
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ocx;
    return Tooltip(
      message: 'Font',
      waitDuration: const Duration(milliseconds: 600),
      child: Material(
        color: c.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.xs),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.xs),
          onTap: () async {
            final picked = await showDialog<String>(
              context: context,
              builder: (_) => _FontPickerDialog(current: value),
            );
            if (picked != null) onChanged(picked);
          },
          child: SizedBox(
            height: Chrome.control,
            child: Padding(
              padding: const EdgeInsets.only(left: Space.sm, right: Space.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value ?? 'Mixed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OcxText.body(context).copyWith(fontFamily: value),
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
  }
}

class _FontPickerDialog extends ConsumerStatefulWidget {
  const _FontPickerDialog({required this.current});

  final String? current;

  @override
  ConsumerState<_FontPickerDialog> createState() => _FontPickerDialogState();
}

class _FontPickerDialogState extends ConsumerState<_FontPickerDialog> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final q = _query.text.trim().toLowerCase();
    bool match(String f) => q.isEmpty || f.toLowerCase().contains(q);
    final bundled = [
      for (final f
          in ref.watch(bundledFontsProvider).value ?? const <BundledFont>[])
        if (match(f.family)) f.family,
    ];
    final bundledLower = {for (final f in bundled) f.toLowerCase()};
    final system = ref.watch(systemFontsProvider);
    final installed = [
      for (final f in system.isEmpty ? fallbackFontFamilies : system)
        if (match(f) && !bundledLower.contains(f.toLowerCase())) f,
    ];
    // (text, isHeader)
    final rows = <(String, bool)>[
      if (bundled.isNotEmpty) ('Included with OpenCanvasX', true),
      for (final f in bundled) (f, false),
      if (installed.isNotEmpty)
        (
          system.isEmpty
              ? 'On this computer (still looking…)'
              : 'On this computer (${installed.length})',
          true,
        ),
      for (final f in installed) (f, false),
    ];

    return Dialog(
      alignment: Alignment.centerRight,
      insetPadding: const EdgeInsets.only(right: 300, top: 60, bottom: 60),
      child: SizedBox(
        width: 320,
        height: 560,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(Space.sm),
              child: TextField(
                controller: _query,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search fonts',
                  prefixIcon: Icon(Icons.search, size: 18),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  final first = [...bundled, ...installed].firstOrNull;
                  if (first != null) Navigator.pop(context, first);
                },
              ),
            ),
            Expanded(
              child:
                  rows.isEmpty
                      ? Center(
                        child: Text(
                          'No fonts match "${_query.text}"',
                          style: OcxText.body(
                            context,
                          ).copyWith(color: c.textTertiary),
                        ),
                      )
                      : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final (text, header) = rows[i];
                          if (header) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(
                                Space.md,
                                Space.md,
                                Space.md,
                                Space.xs,
                              ),
                              child: Text(
                                text,
                                style: OcxText.caption(
                                  context,
                                ).copyWith(color: c.textTertiary),
                              ),
                            );
                          }
                          final family = text;
                          final selected = family == widget.current;
                          return InkWell(
                            onTap: () => Navigator.pop(context, family),
                            child: Container(
                              height: 34,
                              color: selected ? c.accentSubtle : null,
                              padding: const EdgeInsets.symmetric(
                                horizontal: Space.md,
                              ),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                family,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: family,
                                  fontSize: 15,
                                  color: c.text,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
