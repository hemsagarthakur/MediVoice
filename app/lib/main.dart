import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/services/extraction_api.dart';
import 'core/services/image_input_service.dart';
import 'core/services/medicine_reference_api.dart';
import 'core/services/ocr_service.dart';
import 'core/services/safety_validator.dart';
import 'core/services/speech_service.dart';
import 'core/services/summary_builder.dart';
import 'core/services/translation_service.dart';
import 'features/scan/scan_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final controller = ScanController(
    imageInputService: DeviceImageInputService(),
    ocrService: MlKitOcrService(),
    extractionApi: HttpExtractionApi(baseUrl: config.apiBaseUrl),
    medicineReferenceApi: HttpMedicineReferenceApi(baseUrl: config.apiBaseUrl),
    safetyValidator: const SafetyValidator(),
    summaryBuilder: const SummaryBuilder(),
    translationService: MlKitTranslationService(),
    speechService: DeviceSpeechService(),
    demoMode: config.demoMode,
  );
  runApp(MediVoiceApp(controller: controller));
}
