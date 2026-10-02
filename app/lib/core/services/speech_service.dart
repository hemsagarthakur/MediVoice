import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

import '../errors/app_error.dart';
import '../models/translation_result.dart';

abstract interface class SpeechService {
  Future<void> speak(String text, AppLanguage language);

  Future<void> stop();
}

class DeviceSpeechService implements SpeechService {
  DeviceSpeechService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<void> speak(String text, AppLanguage language) async {
    try {
      final rawLanguages = await _tts.getLanguages;
      final languages = rawLanguages is List
          ? rawLanguages.map((value) => value.toString().toLowerCase()).toList()
          : <String>[];
      final requested = language.ttsLocale.toLowerCase();
      final base = language.bcpCode.toLowerCase();
      if (!languages.any(
        (available) => available == requested || available.startsWith('$base-'),
      )) {
        throw StateError('Requested TTS locale is not installed.');
      }
      await _tts.stop();
      if (kDebugMode) {
        debugPrint('MediVoice tts_locale=${language.ttsLocale}');
      }
      await _tts.setLanguage(language.ttsLocale);
      await _tts.setSpeechRate(0.42);
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(text);
    } catch (error) {
      throw AppError(
        code: AppErrorCode.speech,
        message:
            'A ${language.label} voice is not available. Install it in device text-to-speech settings.',
        retryable: false,
        debugCause: error,
      );
    }
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}
