import 'package:medivoice/core/models/medicine_instruction.dart';
import 'package:medivoice/core/models/medicine_reference.dart';
import 'package:medivoice/core/models/scan_mode.dart';
import 'package:medivoice/core/models/scan_result.dart';
import 'package:medivoice/core/models/translation_result.dart';
import 'package:medivoice/core/services/extraction_api.dart';
import 'package:medivoice/core/services/image_input_service.dart';
import 'package:medivoice/core/services/medicine_reference_api.dart';
import 'package:medivoice/core/services/ocr_service.dart';
import 'package:medivoice/core/services/safety_validator.dart';
import 'package:medivoice/core/services/speech_service.dart';
import 'package:medivoice/core/services/summary_builder.dart';
import 'package:medivoice/core/services/translation_service.dart';
import 'package:medivoice/features/scan/scan_controller.dart';

class FakeImageInputService implements ImageInputService {
  FakeImageInputService({this.path = '/tmp/medivoice-test.png'});

  final String path;

  @override
  Future<PreparedImage?> recoverLostImage() async => null;

  @override
  Future<PreparedImage?> select(ImageInputKind kind) async =>
      PreparedImage(path: path, hasLowResolutionWarning: false);
}

class FakeOcrService implements OcrService {
  FakeOcrService({this.text = 'Paracetamol 500 mg one tablet twice daily'});

  final String text;

  @override
  void close() {}

  @override
  Future<String> recognize(String imagePath) async => text;
}

class FakeExtractionApi implements ExtractionApi {
  FakeExtractionApi({List<MedicineInstruction>? medicines})
    : medicines =
          medicines ??
          const [
            MedicineInstruction(
              medicineName: 'Paracetamol',
              strength: '500 mg',
              dose: '1 tablet',
              frequency: 'Twice daily',
              timing: 'Morning and evening',
              duration: '5 days',
              foodInstruction: 'After food',
            ),
          ];

  final List<MedicineInstruction> medicines;
  int calls = 0;
  String? lastSourceText;

  @override
  void close() {}

  @override
  Future<ScanResult> extract({
    required ScanMode mode,
    required String sourceText,
  }) async {
    calls += 1;
    lastSourceText = sourceText;
    return ScanResult(
      mode: mode,
      sourceText: sourceText,
      medicines: medicines,
      requestId: 'test-request',
    );
  }
}

class FakeTranslationService implements TranslationService {
  String? lastText;
  AppLanguage? lastLanguage;
  List<String>? lastProtectedTerms;

  @override
  Future<TranslationResult> translate(
    String text,
    AppLanguage language, {
    List<String> protectedTerms = const [],
  }) async {
    lastText = text;
    lastLanguage = language;
    lastProtectedTerms = protectedTerms;
    return TranslationResult(
      language: language,
      verifiedEnglishText: text,
      translatedText: language == AppLanguage.english
          ? text
          : '${language.label} explanation: $text',
    );
  }
}

class FakeMedicineReferenceApi implements MedicineReferenceApi {
  FakeMedicineReferenceApi({this.references = const []});

  final List<MedicineReference> references;
  List<MedicineInstruction>? lastMedicines;

  @override
  Future<List<MedicineReference>> lookup(
    List<MedicineInstruction> medicines,
  ) async {
    lastMedicines = medicines;
    if (references.isNotEmpty) return references;
    return [
      for (final medicine in medicines)
        MedicineReference.unavailable(
          medicine.medicineName ?? 'Unknown medicine',
          uncertain: medicine.uncertainFields.contains(
            MedicineField.medicineName,
          ),
        ),
    ];
  }

  @override
  void close() {}
}

class FakeSpeechService implements SpeechService {
  String? lastSpoken;
  AppLanguage? lastLanguage;

  @override
  Future<void> speak(String text, AppLanguage language) async {
    lastSpoken = text;
    lastLanguage = language;
  }

  @override
  Future<void> stop() async {}
}

ScanController buildTestController({
  String imagePath = '/tmp/medivoice-test.png',
  List<MedicineInstruction>? medicines,
  bool demoMode = false,
  bool enableOcrDebugViewer = false,
  FakeExtractionApi? extractionApi,
  TranslationService? translationService,
  SpeechService? speechService,
  MedicineReferenceApi? medicineReferenceApi,
}) => ScanController(
  imageInputService: FakeImageInputService(path: imagePath),
  ocrService: FakeOcrService(),
  extractionApi: extractionApi ?? FakeExtractionApi(medicines: medicines),
  medicineReferenceApi: medicineReferenceApi ?? FakeMedicineReferenceApi(),
  safetyValidator: const SafetyValidator(),
  summaryBuilder: const SummaryBuilder(),
  translationService: translationService ?? FakeTranslationService(),
  speechService: speechService ?? FakeSpeechService(),
  demoMode: demoMode,
  enableOcrDebugViewer: enableOcrDebugViewer,
);
