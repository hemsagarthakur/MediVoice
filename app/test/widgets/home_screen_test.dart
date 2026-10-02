import 'package:flutter_test/flutter_test.dart';
import 'package:medivoice/app/app.dart';

import '../fakes.dart';

void main() {
  testWidgets('home exposes the three primary entry points', (tester) async {
    final controller = buildTestController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MediVoiceApp(controller: controller));

    expect(find.text('Scan prescription'), findsOneWidget);
    expect(find.text('Scan medicine strip'), findsOneWidget);
    expect(find.text('Upload image'), findsOneWidget);
    expect(find.textContaining('does not replace'), findsOneWidget);
    expect(find.text('Try synthetic demo'), findsNothing);
  });

  testWidgets('demo mode exposes a clearly labelled synthetic flow', (
    tester,
  ) async {
    final controller = buildTestController(demoMode: true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(MediVoiceApp(controller: controller));

    expect(find.text('Try synthetic demo'), findsOneWidget);
    expect(find.textContaining('does not call Groq'), findsOneWidget);
  });
}
