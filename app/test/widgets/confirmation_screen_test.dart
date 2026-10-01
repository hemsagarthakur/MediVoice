import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medivoice/core/models/medicine_instruction.dart';
import 'package:medivoice/core/models/scan_mode.dart';
import 'package:medivoice/features/scan/confirmation_screen.dart';
import 'package:provider/provider.dart';

import '../fakes.dart';

void main() {
  testWidgets('missing name blocks confirmation and uncertainty needs review', (
    tester,
  ) async {
    final controller = buildTestController(
      medicines: const [
        MedicineInstruction(
          medicineName: null,
          strength: '500 mg',
          dose: '1?',
          uncertainFields: {MedicineField.dose},
        ),
      ],
    );
    addTearDown(controller.dispose);
    await controller.selectImage(ScanMode.prescription, ImageInputKind.camera);
    await controller.processImage();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: ConfirmationScreen()),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.textContaining('needs a name'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Confirm and continue'),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('Uncertain'), findsOneWidget);
  });
}
