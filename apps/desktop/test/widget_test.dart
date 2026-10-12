import 'package:flutter_test/flutter_test.dart';
import 'package:opencanvasx/main.dart';

void main() {
  testWidgets('shell shows title', (tester) async {
    await tester.pumpWidget(const OpenCanvasXApp());
    expect(find.text('OpenCanvasX'), findsOneWidget);
    expect(find.text('Canvas area (Phase 1)'), findsOneWidget);
  });
}
