// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/errors/app_error.dart';
import '../../core/models/medicine_instruction.dart';
import '../../core/models/scan_mode.dart';
import '../../core/models/scan_result.dart';
import '../../core/models/translation_result.dart';
import '../../core/services/extraction_api.dart';
import '../../core/services/image_input_service.dart';
import '../../core/services/ocr_service.dart';
import '../../core/services/safety_validator.dart';
import '../../core/services/speech_service.dart';
import '../../core/services/summary_builder.dart';
import '../../core/services/translation_service.dart';

enum ScanWorkflowState {
  idle,
  imageSelected,
  processingOcr,
  processingExtraction,
  awaitingConfirmation,
  preparingResult,
  ready,
  failure,
}

class ScanController extends ChangeNotifier {
  static const demoOcrText =
      'Paracetamol 500 mg\nTake one tablet twice daily after meals for 5 days.';

  ScanController({
    required ImageInputService imageInputService,
    required OcrService ocrService,
    required ExtractionApi extractionApi,
    required SafetyValidator safetyValidator,
    required SummaryBuilder summaryBuilder,
    required TranslationService translationService,
    required SpeechService speechService,
    this.demoMode = false,
  }) : _imageInputService = imageInputService,
       _ocrService = ocrService,
       _extractionApi = extractionApi,
       _safetyValidator = safetyValidator,
       _summaryBuilder = summaryBuilder,
       _translationService = translationService,
       _speechService = speechService;

  final ImageInputService _imageInputService;
  final OcrService _ocrService;
  final ExtractionApi _extractionApi;
  final SafetyValidator _safetyValidator;
  final SummaryBuilder _summaryBuilder;
  final TranslationService _translationService;
  final SpeechService _speechService;
  final bool demoMode;

  ScanWorkflowState _state = ScanWorkflowState.idle;
  ScanMode? _mode;
  PreparedImage? _image;
  String? _sourceText;
  ScanResult? _originalResult;
  ScanResult? _editableResult;
  AppLanguage _selectedLanguage = AppLanguage.english;
  TranslationResult? _translation;
  AppError? _error;
  bool _acknowledgedUncertainty = false;
  bool _isSpeaking = false;

  ScanWorkflowState get state => _state;
  ScanMode? get mode => _mode;
  PreparedImage? get image => _image;
  String? get sourceText => _sourceText;
  ScanResult? get originalResult => _originalResult;
  ScanResult? get result => _editableResult;
  AppLanguage get selectedLanguage => _selectedLanguage;
  TranslationResult? get translation => _translation;
  AppError? get error => _error;
  bool get acknowledgedUncertainty => _acknowledgedUncertainty;
  bool get isSpeaking => _isSpeaking;

  SafetyValidationResult get safety => _safetyValidator.validate(
    _editableResult?.medicines ?? const <MedicineInstruction>[],
  );

  bool get canConfirm =>
      !safety.hasBlockingIssues &&
      (!safety.requiresAcknowledgement || _acknowledgedUncertainty);

  bool get canPlayAudio =>
      _translation != null && !_translation!.usedFallback && !_isSpeaking;

  Future<bool> selectImage(ScanMode mode, ImageInputKind kind) async {
    final previousState = _state;
    try {
      final selected = await _imageInputService.select(kind);
      if (selected == null) return false;
      await _speechService.stop();
      _clearSession(keepMode: false);
      _mode = mode;
      _image = selected;
      _state = ScanWorkflowState.imageSelected;
      notifyListeners();
      return true;
    } on AppError catch (error) {
      _error = error;
      if (previousState != ScanWorkflowState.imageSelected) {
        _state = ScanWorkflowState.idle;
      }
      notifyListeners();
      return false;
    } catch (error) {
      _error = AppError.unknown(error);
      if (previousState != ScanWorkflowState.imageSelected) {
        _state = ScanWorkflowState.idle;
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> recoverLostImage() async {
    try {
      final recovered = await _imageInputService.recoverLostImage();
      if (recovered == null) return false;
      _clearSession(keepMode: false);
      _image = recovered;
      _state = ScanWorkflowState.imageSelected;
      notifyListeners();
      return true;
    } on AppError catch (error) {
      _error = error;
      notifyListeners();
      return false;
    }
  }

  void setRecoveredImageMode(ScanMode mode) {
    if (_image == null || _mode != null) return;
    _mode = mode;
    notifyListeners();
  }

  Future<void> retake(ImageInputKind kind) async {
    final activeMode = _mode;
    if (activeMode == null) return;
    await selectImage(activeMode, kind);
  }

  Future<void> startSyntheticDemo() async {
    if (!demoMode) return;
    _clearSession(keepMode: false);
    _mode = ScanMode.prescription;
    _sourceText = demoOcrText;
    _state = ScanWorkflowState.processingExtraction;
    notifyListeners();
    try {
      await _speechService.stop();
      await _extractCurrentText();
    } on AppError catch (error) {
      _fail(error);
    } catch (error) {
      _fail(AppError.unknown(error));
    }
  }

  Future<void> processImage() async {
    final activeImage = _image;
    final activeMode = _mode;
    if (activeImage == null || activeMode == null) return;
    _error = null;
    try {
      _state = ScanWorkflowState.processingOcr;
      notifyListeners();
      _sourceText = await _ocrService.recognize(activeImage.path);
      await _extractCurrentText();
    } on AppError catch (error) {
      _fail(error);
    } catch (error) {
      _fail(AppError.unknown(error));
    }
  }

  Future<void> retryProcessing() async {
    if (_sourceText != null && _mode != null) {
      try {
        _error = null;
        await _extractCurrentText();
      } on AppError catch (error) {
        _fail(error);
      } catch (error) {
        _fail(AppError.unknown(error));
      }
      return;
    }
    await processImage();
  }

  Future<void> _extractCurrentText() async {
    final text = _sourceText;
    final activeMode = _mode;
    if (text == null || activeMode == null) return;
    _state = ScanWorkflowState.processingExtraction;
    notifyListeners();
    final extracted = await _extractionApi.extract(
      mode: activeMode,
      sourceText: text,
    );
    _originalResult = extracted;
    _editableResult = extracted.copyWith(
      medicines: List<MedicineInstruction>.of(extracted.medicines),
    );
    _acknowledgedUncertainty = false;
    _state = ScanWorkflowState.awaitingConfirmation;
    notifyListeners();
  }

  void updateMedicine(int index, MedicineField field, String value) {
    final active = _editableResult;
    if (active == null || index < 0 || index >= active.medicines.length) return;
    final medicines = List<MedicineInstruction>.of(active.medicines);
    medicines[index] = medicines[index].updateField(field, value);
    _editableResult = active.copyWith(medicines: medicines);
    _acknowledgedUncertainty = false;
    notifyListeners();
  }

  void setAcknowledgedUncertainty(bool value) {
    _acknowledgedUncertainty = value;
    notifyListeners();
  }

  void setLanguage(AppLanguage language) {
    _selectedLanguage = language;
    notifyListeners();
  }

  Future<void> confirmAndPrepareResult() async {
    final active = _editableResult;
    if (active == null || !canConfirm) return;
    _state = ScanWorkflowState.preparingResult;
    _error = null;
    notifyListeners();
    final english = _summaryBuilder.build(active.medicines);
    try {
      _translation = await _translationService.translate(
        english,
        _selectedLanguage,
      );
    } on AppError catch (error) {
      _error = error;
      _translation = TranslationResult(
        language: _selectedLanguage,
        verifiedEnglishText: english,
        translatedText: english,
        usedFallback: true,
      );
    } catch (error) {
      _error = AppError(
        code: AppErrorCode.translation,
        message: 'Translation failed. The confirmed English result is still available.',
        retryable: true,
        debugCause: error,
      );
      _translation = TranslationResult(
        language: _selectedLanguage,
        verifiedEnglishText: english,
        translatedText: english,
        usedFallback: true,
      );
    }
    _state = ScanWorkflowState.ready;
    notifyListeners();
  }

  Future<void> retryTranslation() async {
    final current = _translation;
    if (current == null) return;
    _state = ScanWorkflowState.preparingResult;
    _error = null;
    notifyListeners();
    try {
      _translation = await _translationService.translate(
        current.verifiedEnglishText,
        _selectedLanguage,
      );
      _state = ScanWorkflowState.ready;
    } on AppError catch (error) {
      _error = error;
      _translation = TranslationResult(
        language: _selectedLanguage,
        verifiedEnglishText: current.verifiedEnglishText,
        translatedText: current.verifiedEnglishText,
        usedFallback: true,
      );
      _state = ScanWorkflowState.ready;
    }
    notifyListeners();
  }

  Future<void> play() async {
    final current = _translation;
    if (current == null || current.usedFallback) return;
    _error = null;
    _isSpeaking = true;
    notifyListeners();
    try {
      await _speechService.speak(current.translatedText, current.language);
    } on AppError catch (error) {
      _error = error;
    } catch (error) {
      _error = AppError(
        code: AppErrorCode.speech,
        message: 'Audio playback failed. The verified text is still available.',
        retryable: false,
        debugCause: error,
      );
    } finally {
      _isSpeaking = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _speechService.stop();
    _isSpeaking = false;
    notifyListeners();
  }

  Future<void> newScan() async {
    await _speechService.stop();
    _clearSession(keepMode: false);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _fail(AppError error) {
    _error = error;
    _state = ScanWorkflowState.failure;
    notifyListeners();
  }

  void _clearSession({required bool keepMode}) {
    if (!keepMode) _mode = null;
    _image = null;
    _sourceText = null;
    _originalResult = null;
    _editableResult = null;
    _selectedLanguage = AppLanguage.english;
    _translation = null;
    _error = null;
    _acknowledgedUncertainty = false;
    _isSpeaking = false;
    _state = ScanWorkflowState.idle;
  }

  @override
  void dispose() {
    unawaited(_speechService.stop());
    _ocrService.close();
    _extractionApi.close();
    super.dispose();
  }
}
