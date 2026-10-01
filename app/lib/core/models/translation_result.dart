enum AppLanguage {
  english('en', 'English', 'en-IN'),
  hindi('hi', 'Hindi', 'hi-IN'),
  telugu('te', 'Telugu', 'te-IN');

  const AppLanguage(this.bcpCode, this.label, this.ttsLocale);

  final String bcpCode;
  final String label;
  final String ttsLocale;
}

class TranslationResult {
  const TranslationResult({
    required this.language,
    required this.verifiedEnglishText,
    required this.translatedText,
    this.usedFallback = false,
  });

  final AppLanguage language;
  final String verifiedEnglishText;
  final String translatedText;
  final bool usedFallback;
}
