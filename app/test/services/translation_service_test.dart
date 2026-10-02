import 'package:flutter_test/flutter_test.dart';
import 'package:medivoice/core/models/translation_result.dart';
import 'package:medivoice/core/services/translation_service.dart';

void main() {
  test(
    'translation protection preserves medicine names strengths and numbers',
    () {
      const source = 'Paracetamol 500 mg. Take 1 tablet for 5 days.';
      final protected = TranslationTextProtector.protect(source, const [
        'Paracetamol',
        '500 mg',
        '1 tablet',
        '5 days',
      ]);

      expect(protected.maskedText, isNot(contains('Paracetamol')));
      expect(protected.maskedText, isNot(contains('500 mg')));
      expect(protected.maskedText, isNot(contains('5 days')));

      final localized = protected.restore('यह दवा ${protected.maskedText}');

      expect(localized, contains('Paracetamol'));
      expect(localized, contains('500 mg'));
      expect(localized, contains('5 days'));
      expect(localized, contains('1 tablet'));
    },
  );

  test('indexed protection markers survive case and spacing changes', () {
    const source = 'Paracetamol 500 mg. Take 1 tablet for 5 days.';
    final protected = TranslationTextProtector.protect(source, const [
      'Paracetamol',
      '500 mg',
      '1 tablet',
      '5 days',
    ]);
    final alteredMarkers = protected.maskedText.replaceAllMapped(
      RegExp(r'ZXQ(\d+)QXZ'),
      (match) => 'z x q ${match.group(1)} q x z',
    );

    final restored = protected.restore('हिंदी $alteredMarkers');

    expect(restored, contains('Paracetamol'));
    expect(restored, contains('500 mg'));
    expect(restored, contains('1 tablet'));
    expect(restored, contains('5 days'));
  });

  test('supported languages use Indian device speech locales', () {
    expect(AppLanguage.english.ttsLocale, 'en-IN');
    expect(AppLanguage.hindi.ttsLocale, 'hi-IN');
    expect(AppLanguage.telugu.ttsLocale, 'te-IN');
  });
}
