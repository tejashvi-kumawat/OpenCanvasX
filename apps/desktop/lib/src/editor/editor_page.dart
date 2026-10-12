import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/ocx_theme.dart';
import 'bottom_bar.dart';
import 'canvas_view.dart';
import 'editor_controller.dart';
import 'editor_shortcuts.dart';
import 'inspector_panel.dart';
import 'left_panel.dart';
import 'top_bar.dart';
import 'viewport.dart';

/// The editor (P1.10.1): top bar, left rail and panels, canvas with bottom
/// bar, and the inspector on the right.
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
    await ref.read(editorProvider.notifier).close();
    ref.read(viewportProvider.notifier).reset();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasSession = ref.watch(editorProvider.select((s) => s != null));
    if (!hasSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final border = context.ocx.border;
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
            body: Column(
              children: [
                EditorTopBar(onHome: _goHome),
                Expanded(
                  child: Row(
                    children: [
                      const LeftSide(),
                      VerticalDivider(color: border),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(child: DesignCanvas(focusNode: _focus)),
                            const EditorBottomBar(),
                          ],
                        ),
                      ),
                      VerticalDivider(color: border),
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
