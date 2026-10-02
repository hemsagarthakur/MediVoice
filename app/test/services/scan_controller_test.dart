import 'package:flutter_test/flutter_test.dart';
import 'package:medivoice/core/errors/app_error.dart';
import 'package:medivoice/core/models/medicine_reference.dart';
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
  Future<TranslationResult> translate(
    String text,
    AppLanguage language, {
    List<String> protectedTerms = const [],
  }) async {
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
  medicineReferenceApi: FakeMedicineReferenceApi(),
  safetyValidator: const SafetyValidator(),
  summaryBuilder: const SummaryBuilder(),
  translationService: translation ?? FakeTranslationService(),
  speechService: speech ?? FakeSpeechService(),
  enableOcrDebugViewer: false,
);

Future<void> _prepare(ScanController controller) async {
  await controller.selectImage(ScanMode.prescription, ImageInputKind.camera);
  await controller.processImage();
}

void main() {
  test('reference failure does not block result or audio', () async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await _prepare(controller);
    await controller.confirmAndPrepareResult();
    expect(controller.state, ScanWorkflowState.ready);
    expect(controller.translation?.translatedText, contains('Paracetamol'));
    expect(controller.references.single.available, isFalse);
  });

  test('TTS receives trusted reference explanation without metadata', () async {
    final speech = FakeSpeechService();
    final controller = ScanController(
      imageInputService: FakeImageInputService(),
      ocrService: FakeOcrService(),
      extractionApi: FakeExtractionApi(),
      medicineReferenceApi: FakeMedicineReferenceApi(
        references: const [
          MedicineReference(
            requestedName: 'Paracetamol',
            canonicalName: 'acetaminophen',
            rxCui: '161',
            commonlyUsedFor: ['pain and fever'],
            commonSideEffects: [],
            importantCaution: 'Do not take more than the recommended amount',
            source: 'dailymed',
            sourceReference: 'https://example.test/label',
            matchQuality: 'exact',
            available: true,
          ),
        ],
      ),
      safetyValidator: const SafetyValidator(),
      summaryBuilder: const SummaryBuilder(),
      translationService: FakeTranslationService(),
      speechService: speech,
      enableOcrDebugViewer: false,
    );
    addTearDown(controller.dispose);
    await _prepare(controller);
    await controller.confirmAndPrepareResult();
    await controller.play();
    expect(speech.lastSpoken, contains('Commonly used for pain and fever'));
    expect(speech.lastSpoken, isNot(contains('161')));
    expect(speech.lastSpoken, isNot(contains('example.test')));
  });

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

  test('debug OCR viewer does not pause extraction', () async {
    final extractionApi = FakeExtractionApi();
    final controller = buildTestController(
      enableOcrDebugViewer: true,
      extractionApi: extractionApi,
    );
    addTearDown(controller.dispose);

    await controller.selectImage(ScanMode.prescription, ImageInputKind.camera);
    await controller.processImage();

    expect(controller.state, ScanWorkflowState.awaitingConfirmation);
    expect(controller.sourceText, contains('Paracetamol'));
    expect(extractionApi.calls, 1);
    expect(extractionApi.lastSourceText, controller.sourceText);
    expect(controller.isOcrDebugViewerEnabled, isTrue);
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

  test(
    'TTS receives the selected localized plain-language explanation',
    () async {
      final translation = FakeTranslationService();
      final speech = FakeSpeechService();
      final controller = _controller(translation: translation, speech: speech);
      addTearDown(controller.dispose);
      await _prepare(controller);
      await controller.confirmAndPrepareResult();

      await controller.changeLanguage(AppLanguage.hindi);
      await controller.play();

      expect(translation.lastLanguage, AppLanguage.hindi);
      expect(
        translation.lastProtectedTerms,
        containsAll(<String>['Paracetamol', '500 mg']),
      );
      expect(speech.lastLanguage, AppLanguage.hindi);
      expect(speech.lastLanguage?.ttsLocale, 'hi-IN');
      expect(speech.lastSpoken, controller.translation?.translatedText);
      expect(speech.lastSpoken, contains('Hindi explanation:'));
      expect(speech.lastSpoken, isNot(contains('Dose:')));
    },
  );

  test('English Hindi Telugu English switching updates every result', () async {
    final translation = FakeTranslationService();
    final controller = _controller(translation: translation);
    addTearDown(controller.dispose);
    await _prepare(controller);
    await controller.confirmAndPrepareResult();

    expect(controller.translation?.language, AppLanguage.english);
    await controller.changeLanguage(AppLanguage.hindi);
    expect(controller.selectedLanguage, AppLanguage.hindi);
    expect(controller.translation?.language, AppLanguage.hindi);
    expect(
      controller.translation?.translatedText,
      startsWith('Hindi explanation:'),
    );
    await controller.changeLanguage(AppLanguage.telugu);
    expect(controller.selectedLanguage, AppLanguage.telugu);
    expect(controller.translation?.language, AppLanguage.telugu);
    expect(
      controller.translation?.translatedText,
      startsWith('Telugu explanation:'),
    );
    await controller.changeLanguage(AppLanguage.english);
    expect(controller.selectedLanguage, AppLanguage.english);
    expect(controller.translation?.language, AppLanguage.english);
    expect(
      controller.translation?.translatedText,
      isNot(contains('explanation:')),
    );
  });
}
