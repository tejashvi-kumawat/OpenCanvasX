import 'package:flutter_test/flutter_test.dart';
import 'package:open_design_studio/main.dart';

void main() {
  testWidgets('shell shows title', (tester) async {
    await tester.pumpWidget(const OpenDesignStudioApp());
    expect(find.text('Open Design Studio'), findsOneWidget);
    expect(find.text('Canvas area (Phase 1)'), findsOneWidget);
  });
}
