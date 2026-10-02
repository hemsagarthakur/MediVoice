import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medivoice/app/app.dart';
import 'package:medivoice/core/models/scan_mode.dart';
import 'package:medivoice/core/models/medicine_reference.dart';
import 'package:medivoice/core/models/translation_result.dart';
import 'package:medivoice/features/scan/capture_screen.dart';
import 'package:medivoice/features/scan/result_screen.dart';
import 'package:provider/provider.dart';

import '../fakes.dart';

void main() {
  testWidgets('selecting Hindi replaces the visible explanation', (
    tester,
  ) async {
    final controller = buildTestController();
    addTearDown(controller.dispose);
    await controller.selectImage(ScanMode.prescription, ImageInputKind.camera);
    await controller.processImage();
    await controller.confirmAndPrepareResult();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: ResultScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Explanation language'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hindi').last);
    await tester.pumpAndSettle();

    expect(controller.selectedLanguage, AppLanguage.hindi);
    expect(controller.translation?.language, AppLanguage.hindi);
    expect(find.textContaining('Hindi explanation:'), findsOneWidget);
  });

  testWidgets('result separates doctor instructions from reference facts', (
    tester,
  ) async {
    final controller = buildTestController(
      medicineReferenceApi: FakeMedicineReferenceApi(
        references: const [
          MedicineReference(
            requestedName: 'Paracetamol',
            canonicalName: 'acetaminophen',
            commonlyUsedFor: ['reducing fever'],
            commonSideEffects: ['nausea'],
            importantCaution: 'Do not exceed the recommended amount',
            source: 'dailymed',
            matchQuality: 'exact',
            available: true,
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    await controller.selectImage(ScanMode.prescription, ImageInputKind.camera);
    await controller.processImage();
    await controller.confirmAndPrepareResult();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: ResultScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Your doctor's instructions"), findsOneWidget);
    expect(find.text('About this medicine'), findsOneWidget);
    await tester.tap(find.text('About this medicine'));
    await tester.pumpAndSettle();
    expect(find.text('Used for: reducing fever'), findsOneWidget);
    expect(find.text('Common side effects: nausea'), findsOneWidget);
    expect(
      find.text('Important caution: Do not exceed the recommended amount'),
      findsOneWidget,
    );
  });

  testWidgets('synthetic demo reaches review without camera or Groq', (
    tester,
  ) async {
    final controller = buildTestController(demoMode: true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(MediVoiceApp(controller: controller));
    await tester.tap(find.text('Try synthetic demo'));
    await tester.pumpAndSettle();

    expect(find.text('We found 1 medicine'), findsOneWidget);
    expect(
      find.textContaining('deterministic mock extraction'),
      findsOneWidget,
    );

    final confirm = find.text('Looks correct');
    await tester.scrollUntilVisible(
      confirm,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.text('Your medicines'), findsWidgets);
    expect(find.textContaining('not Groq'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Easy explanation'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Easy explanation'), findsOneWidget);
    expect(find.textContaining('Paracetamol'), findsWidgets);
  });

  testWidgets('synthetic scan reaches the verified result', (tester) async {
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('medivoice_widget_'),
    );
    if (directory == null) throw StateError('Could not create test directory.');
    addTearDown(() => directory.deleteSync(recursive: true));
    final image = File('${directory.path}/sample.png');
    await tester.runAsync(
      () => image.writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
      ),
    );
    final controller = buildTestController(imagePath: image.path);
    addTearDown(controller.dispose);

    await tester.pumpWidget(MediVoiceApp(controller: controller));
    await tester.tap(find.text('Scan prescription'));
    await tester.pumpAndSettle();
    expect(find.text('Use this image'), findsOneWidget);

    await tester.tap(find.text('Use this image'));
    await tester.pumpAndSettle();
    expect(find.text('We found 1 medicine'), findsOneWidget);

    final confirm = find.text('Looks correct');
    await tester.scrollUntilVisible(
      confirm,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.text('Your medicines'), findsWidgets);
    expect(find.textContaining('Paracetamol'), findsWidgets);
    final playAudio = find.text('Listen');
    await tester.scrollUntilVisible(
      playAudio,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(playAudio, findsOneWidget);
  });

  testWidgets('release flow goes directly to review without OCR viewer', (
    tester,
  ) async {
    final extractionApi = FakeExtractionApi();
    final controller = buildTestController(
      enableOcrDebugViewer: false,
      extractionApi: extractionApi,
    );
    addTearDown(controller.dispose);

    await controller.selectImage(ScanMode.prescription, ImageInputKind.camera);
    await controller.processImage();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: CaptureScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('We found 1 medicine'), findsOneWidget);
    expect(find.byKey(const ValueKey('developer_ocr_viewer')), findsNothing);
    expect(find.text(controller.sourceText!), findsNothing);
    expect(extractionApi.calls, 1);
  });

  testWidgets('development action opens the in-memory OCR viewer', (
    tester,
  ) async {
    final extractionApi = FakeExtractionApi();
    final controller = buildTestController(
      enableOcrDebugViewer: true,
      extractionApi: extractionApi,
    );
    addTearDown(controller.dispose);

    await controller.selectImage(ScanMode.prescription, ImageInputKind.camera);
    await controller.processImage();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: CaptureScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('We found 1 medicine'), findsOneWidget);
    expect(extractionApi.calls, 1);
    await tester.tap(find.byKey(const ValueKey('developer_ocr_viewer')));
    await tester.pumpAndSettle();

    expect(find.text('Developer OCR viewer'), findsOneWidget);
    expect(find.text('Copy OCR text'), findsOneWidget);
    expect(find.text(controller.sourceText!), findsOneWidget);
  });
}
