import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:flutter/foundation.dart';

import '../errors/app_error.dart';
import '../models/translation_result.dart';

abstract interface class TranslationService {
  Future<TranslationResult> translate(
    String text,
    AppLanguage language, {
    List<String> protectedTerms = const [],
  });
}

class MlKitTranslationService implements TranslationService {
  @override
  Future<TranslationResult> translate(
    String text,
    AppLanguage language, {
    List<String> protectedTerms = const [],
  }) async {
    if (language == AppLanguage.english) {
      if (kDebugMode) {
        debugPrint(
          'MediVoice translation_success language=en model=not_required',
        );
      }
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
      final protectedText = TranslationTextProtector.protect(
        text,
        protectedTerms,
      );
      final downloaded = await manager.isModelDownloaded(target.bcpCode);
      if (kDebugMode) {
        debugPrint(
          'MediVoice translation_model language=${language.bcpCode} ready=$downloaded',
        );
      }
      if (!downloaded) {
        final success = await manager.downloadModel(target.bcpCode);
        if (!success) {
          throw StateError('Translation model download failed.');
        }
        if (kDebugMode) {
          debugPrint(
            'MediVoice translation_model language=${language.bcpCode} ready=true downloaded=true',
          );
        }
      }
      final translated = await translator.translateText(
        protectedText.maskedText,
      );
      if (translated.trim().isEmpty) {
        throw StateError('Translation was empty.');
      }
      final restored = protectedText.restore(translated.trim());
      if (kDebugMode) {
        debugPrint(
          'MediVoice translation_success language=${language.bcpCode}',
        );
      }
      return TranslationResult(
        language: language,
        verifiedEnglishText: text,
        translatedText: restored,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'MediVoice translation_failure language=${language.bcpCode} type=${error.runtimeType}',
        );
      }
      throw AppError(
        code: AppErrorCode.translation,
        message:
            'Could not prepare ${language.label}. Check your connection and try again.',
        retryable: true,
        debugCause: error,
      );
    } finally {
      translator.close();
    }
  }
}

class TranslationTextProtector {
  const TranslationTextProtector._();

  static ProtectedTranslationText protect(
    String text,
    List<String> exactTerms,
  ) {
    final terms = <String>{
      for (final term in exactTerms)
        if (term.trim().isNotEmpty) term.trim(),
      for (final match in RegExp(r'\b\d+(?:[.,]\d+)?\b').allMatches(text))
        match.group(0)!,
    }.toList()..sort((left, right) => right.length.compareTo(left.length));

    final replacements = <String, String>{};
    final tokenForTerm = <String, String>{};
    final pattern = terms.isEmpty
        ? null
        : RegExp(terms.map(RegExp.escape).join('|'));
    final masked = pattern == null
        ? text
        : text.replaceAllMapped(pattern, (match) {
            final term = match.group(0)!;
            return tokenForTerm.putIfAbsent(term, () {
              final token = 'ZXQ${tokenForTerm.length}QXZ';
              replacements[token] = term;
              return token;
            });
          });
    return ProtectedTranslationText(
      maskedText: masked,
      replacements: replacements,
    );
  }

  static RegExp _tokenPattern(String token) {
    final index = RegExp(r'\d+').firstMatch(token)?.group(0);
    if (index == null) {
      return RegExp(RegExp.escape(token), caseSensitive: false);
    }
    return RegExp(
      r'Z\s*X\s*Q\s*' + RegExp.escape(index) + r'\s*Q\s*X\s*Z',
      caseSensitive: false,
    );
  }

  static String restoreToken(String text, String token, String value) {
    return text.replaceAll(_tokenPattern(token), value);
  }

  static bool containsToken(String text, String token) {
    return _tokenPattern(token).hasMatch(text);
  }
}

class ProtectedTranslationText {
  const ProtectedTranslationText({
    required this.maskedText,
    required this.replacements,
  });

  final String maskedText;
  final Map<String, String> replacements;

  String restore(String translatedText) {
    var restored = translatedText;
    for (final entry in replacements.entries) {
      restored = TranslationTextProtector.restoreToken(
        restored,
        entry.key,
        entry.value,
      );
    }
    if (replacements.entries.any(
      (entry) =>
          TranslationTextProtector.containsToken(restored, entry.key) ||
          !restored.contains(entry.value),
    )) {
      throw StateError('Translation changed a protected medicine fact.');
    }
    return restored;
  }
}
