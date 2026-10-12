import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/ocx_theme.dart';
import 'canvas_view.dart';
import 'editor_controller.dart';
import 'editor_shortcuts.dart';
import 'inspector_panel.dart';
import 'left_panel.dart';
import 'tools.dart';
import 'top_bar.dart';
import 'viewport.dart';

/// The editor (P1.10.1), laid out as in design-system.md §5: toolbar on
/// top, left sidebar, canvas, inspector on the right.
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
        bindings: editorShortcuts(ref),
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
                      const LeftSidebar(),
                      const VerticalDivider(width: 1),
                      Expanded(child: DesignCanvas(focusNode: _focus)),
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
