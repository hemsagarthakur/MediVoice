import 'package:flutter_test/flutter_test.dart';
import 'package:medivoice/core/errors/app_error.dart';
import 'package:medivoice/core/models/scan_mode.dart';
import 'package:medivoice/core/models/translation_result.dart';
import 'package:medivoice/core/services/safety_validator.dart';
import 'package:medivoice/core/services/speech_service.dart';
import 'package:medivoice/core/services/summary_builder.dart';
import 'package:medivoice/core/services/translation_service.dart';
import 'package:medivoice/features/scan/scan_controller.dart';

import '../fakes.dart';

class _FailingTranslationService implements TranslationService {
  @override
  Future<TranslationResult> translate(String text, AppLanguage language) async {
    throw const AppError(
      code: AppErrorCode.translation,
      message: 'Translation failed safely.',
      retryable: true,
    );
  }
}

class _FailingSpeechService implements SpeechService {
  @override
  Future<void> speak(String text, AppLanguage language) async {
    throw const AppError(
      code: AppErrorCode.speech,
      message: 'Voice unavailable.',
      retryable: false,
    );
  }

  @override
  Future<void> stop() async {}
}

ScanController _controller({
  TranslationService? translation,
  SpeechService? speech,
}) => ScanController(
  imageInputService: FakeImageInputService(),
  ocrService: FakeOcrService(),
  extractionApi: FakeExtractionApi(),
  safetyValidator: const SafetyValidator(),
  summaryBuilder: const SummaryBuilder(),
  translationService: translation ?? FakeTranslationService(),
  speechService: speech ?? FakeSpeechService(),
);

Future<void> _prepare(ScanController controller) async {
  await controller.selectImage(ScanMode.prescription, ImageInputKind.camera);
  await controller.processImage();
}

void main() {
  test(
    'synthetic demo uses the normal extraction and confirmation gate',
    () async {
      final controller = buildTestController(demoMode: true);
      addTearDown(controller.dispose);

      await controller.startSyntheticDemo();

      expect(controller.state, ScanWorkflowState.awaitingConfirmation);
      expect(controller.mode, ScanMode.prescription);
      expect(controller.sourceText, ScanController.demoOcrText);
      expect(controller.result?.medicines.single.medicineName, 'Paracetamol');
      expect(controller.translation, isNull);
    },
  );

  test('synthetic demo is unavailable unless explicitly enabled', () async {
    final controller = buildTestController();
    addTearDown(controller.dispose);

    await controller.startSyntheticDemo();

    expect(controller.state, ScanWorkflowState.idle);
    expect(controller.result, isNull);
  });

  test('translation failure preserves English and blocks audio', () async {
    final controller = _controller(translation: _FailingTranslationService());
    addTearDown(controller.dispose);
    await _prepare(controller);
    controller.setLanguage(AppLanguage.hindi);

    await controller.confirmAndPrepareResult();

    expect(controller.state, ScanWorkflowState.ready);
    expect(controller.translation?.usedFallback, isTrue);
    expect(controller.translation?.translatedText, contains('Paracetamol'));
    expect(controller.canPlayAudio, isFalse);
    expect(controller.error?.code, AppErrorCode.translation);
  });

  test('speech failure keeps the readable result', () async {
    final controller = _controller(speech: _FailingSpeechService());
    addTearDown(controller.dispose);
    await _prepare(controller);
    await controller.confirmAndPrepareResult();

    await controller.play();

    expect(controller.state, ScanWorkflowState.ready);
    expect(controller.translation?.translatedText, contains('Paracetamol'));
    expect(controller.error?.code, AppErrorCode.speech);
  });
}
