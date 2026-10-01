import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../errors/app_error.dart';
import '../models/translation_result.dart';

abstract interface class TranslationService {
  Future<TranslationResult> translate(String text, AppLanguage language);
}

class MlKitTranslationService implements TranslationService {
  @override
  Future<TranslationResult> translate(String text, AppLanguage language) async {
    if (language == AppLanguage.english) {
      return TranslationResult(
        language: language,
        verifiedEnglishText: text,
        translatedText: text,
      );
    }

    final target = switch (language) {
      AppLanguage.hindi => TranslateLanguage.hindi,
      AppLanguage.telugu => TranslateLanguage.telugu,
      AppLanguage.english => TranslateLanguage.english,
    };
    final manager = OnDeviceTranslatorModelManager();
    final translator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.english,
      targetLanguage: target,
    );
    try {
      final downloaded = await manager.isModelDownloaded(target.bcpCode);
      if (!downloaded) {
        final success = await manager.downloadModel(target.bcpCode);
        if (!success) {
          throw StateError('Translation model download failed.');
        }
      }
      final translated = await translator.translateText(text);
      if (translated.trim().isEmpty) {
        throw StateError('Translation was empty.');
      }
      return TranslationResult(
        language: language,
        verifiedEnglishText: text,
        translatedText: translated.trim(),
      );
    } catch (error) {
      throw AppError(
        code: AppErrorCode.translation,
        message: 'Translation failed. The confirmed English result is still available.',
        retryable: true,
        debugCause: error,
      );
    } finally {
      translator.close();
    }
  }
}
