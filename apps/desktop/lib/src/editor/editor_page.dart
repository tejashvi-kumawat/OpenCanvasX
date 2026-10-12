import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/ocx_theme.dart';
import '../export/export_dialog.dart';
import '../present/present_page.dart';
import 'canvas_view.dart';
import 'editor_controller.dart';
import 'editor_shortcuts.dart';
import 'inspector_panel.dart';
import 'floating_toolbar.dart';
import 'side_rail.dart';
import 'tools.dart';
import 'top_bar.dart';
import 'viewport.dart';

/// The editor (P1.10.1), laid out as in design-system.md §5: slim top
/// bar, content rail with its panel, canvas with a floating tool bar,
/// inspector on the right.
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key});

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  final FocusNode _focus = FocusNode(debugLabel: 'editor');
  bool _closing = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _goHome() async {
    if (_closing) return;
    // Rebuild first so PopScope allows the pop below.
    setState(() => _closing = true);
    final editor = ref.read(editorProvider.notifier);
    if (ref.read(textEditingProvider) != null) editor.finishTextEdit();
    await editor.close();
    ref.read(viewportProvider.notifier).reset();
    ref.read(toolProvider.notifier).reset();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasSession = ref.watch(editorProvider.select((s) => s != null));
    if (!hasSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final c = context.ocx;
    return PopScope(
      canPop: _closing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome();
      },
      child: CallbackShortcuts(
        bindings: editorShortcuts(
          ref,
          onExport: () => showExportDialog(context),
          onPresent: () => presentDesign(context),
        ),
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          child: Scaffold(
            backgroundColor: c.workspace,
            body: Column(
              children: [
                EditorToolbar(onHome: _goHome),
                const Divider(),
                Expanded(
                  child: Row(
                    children: [
                      const SideRail(),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: DesignCanvas(focusNode: _focus),
                            ),
                            const Positioned(
                              left: 0,
                              right: 0,
                              bottom: Space.lg,
                              child: Center(child: FloatingToolbar()),
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      const InspectorPanel(),
                    ],
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
