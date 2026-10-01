import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../errors/app_error.dart';

abstract interface class OcrService {
  Future<String> recognize(String imagePath);

  void close();
}

class MlKitOcrService implements OcrService {
  MlKitOcrService({TextRecognizer? recognizer})
    : _recognizer =
          recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  @override
  Future<String> recognize(String imagePath) async {
    try {
      final input = InputImage.fromFilePath(imagePath);
      final result = await _recognizer.processImage(input);
      final text = result.text.trim();
      if (text.runes.where((rune) {
            final character = String.fromCharCode(rune);
            return RegExp(r'[A-Za-z0-9]').hasMatch(character);
          }).length <
          8) {
        throw const AppError(
          code: AppErrorCode.emptyOcr,
          message: 'We could not find enough readable text. Improve lighting, focus, and crop, then rescan.',
          retryable: false,
        );
      }
      return text;
    } on AppError {
      rethrow;
    } catch (error) {
      throw AppError(
        code: AppErrorCode.ocr,
        message: 'Text recognition failed. Please rescan the image.',
        retryable: true,
        debugCause: error,
      );
    }
  }

  @override
  void close() => _recognizer.close();
}
