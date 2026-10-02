import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medivoice/core/models/medicine_instruction.dart';
import 'package:medivoice/core/models/scan_mode.dart';
import 'package:medivoice/features/scan/confirmation_screen.dart';
import 'package:provider/provider.dart';

import '../fakes.dart';

Future<void> _showReview(
  WidgetTester tester,
  List<MedicineInstruction> medicines,
) async {
  final controller = buildTestController(medicines: medicines);
  addTearDown(controller.dispose);
  await controller.selectImage(ScanMode.prescription, ImageInputKind.camera);
  await controller.processImage();
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: controller,
      child: const MaterialApp(home: ConfirmationScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text, skipOffstage: false),
    300,
    scrollable: find.byType(Scrollable),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'confident medicines use one simple review without field editors',
    (tester) async {
      await _showReview(tester, const [
        MedicineInstruction(
          medicineName: 'Paracetamol',
          strength: '500 mg',
          dose: '1 tablet',
          frequency: 'Three times daily',
          timing: 'Morning, afternoon, and evening',
          duration: '5 days',
          foodInstruction: 'After food',
        ),
      ]);

      expect(find.text('We found 1 medicine'), findsOneWidget);
      expect(find.text('High confidence'), findsOneWidget);
      await _scrollTo(tester, 'Looks correct');
      expect(find.text('Looks correct'), findsOneWidget);
      expect(find.text('Review unclear details'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Looks correct'),
      );
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets('uncertain fields remain highlighted and require review', (
    tester,
  ) async {
    await _showReview(tester, const [
      MedicineInstruction(
        medicineName: 'Paracetamol',
        strength: '500 mg',
        dose: '1 tablet?',
        frequency: 'Three times daily',
        uncertainFields: {MedicineField.dose},
      ),
    ]);

    expect(
      find.text(
        'Please check the highlighted information. Everything else can be accepted together.',
      ),
      findsOneWidget,
    );
    expect(find.text('Low confidence'), findsOneWidget);
    await _scrollTo(
      tester,
      'I reviewed the unclear details against the prescription.',
    );
    expect(find.byType(CheckboxListTile), findsOneWidget);
    await _scrollTo(tester, 'Looks correct');
    var button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Looks correct'),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Looks correct'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('review unclear details reveals only fields needing attention', (
    tester,
  ) async {
    await _showReview(tester, const [
      MedicineInstruction(medicineName: 'Paracetamol', strength: '500 mg'),
    ]);

    await _scrollTo(tester, 'Review unclear details');
    await tester.tap(find.text('Review unclear details'));
    await tester.pumpAndSettle();

    expect(find.text('Review unclear details'), findsWidgets);
    expect(find.byType(TextFormField), findsWidgets);
    expect(find.byKey(const ValueKey('0_dose')), findsOneWidget);
    expect(find.byKey(const ValueKey('0_duration')), findsNothing);
  });

  testWidgets('optional missing information shows medium confidence', (
    tester,
  ) async {
    await _showReview(tester, const [
      MedicineInstruction(
        medicineName: 'Paracetamol',
        strength: '500 mg',
        dose: '1 tablet',
        frequency: 'Twice daily',
        timing: 'Morning and evening',
        foodInstruction: 'After food',
      ),
    ]);

    expect(find.text('Medium confidence'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
  });
}
