import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medivoice/core/models/translation_result.dart';
import 'package:medivoice/core/services/speech_service.dart';
import 'package:medivoice/core/services/translation_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Hindi and Telugu translate protected synthetic medicine facts', (
    tester,
  ) async {
    const english =
        'Paracetamol 500 mg. Take 1 tablet after food, three times a day, for 5 days.';
    const protectedTerms = ['Paracetamol', '500 mg', '1 tablet', '5 days'];
    final service = MlKitTranslationService();

    final hindi = await service.translate(
      english,
      AppLanguage.hindi,
      protectedTerms: protectedTerms,
    );
    expect(hindi.language, AppLanguage.hindi);
    expect(hindi.translatedText, isNot(english));
    expect(hindi.translatedText, matches(RegExp(r'[\u0900-\u097F]')));
    for (final fact in protectedTerms) {
      expect(hindi.translatedText, contains(fact));
    }

    final telugu = await service.translate(
      english,
      AppLanguage.telugu,
      protectedTerms: protectedTerms,
    );
    expect(telugu.language, AppLanguage.telugu);
    expect(telugu.translatedText, matches(RegExp(r'[\u0C00-\u0C7F]')));
    for (final fact in protectedTerms) {
      expect(telugu.translatedText, contains(fact));
    }

    const multiMedicineEnglish =
        'Paracetamol 500 mg. Take 1 tablet after food, three times a day, for 5 days. '
        'Azithromycin 500 mg. Take 1 tablet once a day, for 3 days. '
        'Cetirizine 10 mg. Take 1 tablet at night, for 5 days. '
        'Pantoprazole 40 mg. Take 1 tablet before breakfast, for 5 days. '
        'Cough Syrup. Take 10 ml three times a day, for 5 days.';
    const multiMedicineFacts = [
      'Paracetamol',
      '500 mg',
      '1 tablet',
      '5 days',
      'Azithromycin',
      '3 days',
      'Cetirizine',
      '10 mg',
      'Pantoprazole',
      '40 mg',
      'Cough Syrup',
      '10 ml',
    ];
    final multiHindi = await service.translate(
      multiMedicineEnglish,
      AppLanguage.hindi,
      protectedTerms: multiMedicineFacts,
    );
    expect(multiHindi.translatedText, matches(RegExp(r'[\u0900-\u097F]')));
    for (final fact in multiMedicineFacts) {
      expect(multiHindi.translatedText, contains(fact));
    }
  });

  testWidgets('installed Hindi voice accepts hi-IN', (tester) async {
    final speech = DeviceSpeechService();
    await speech.speak(
      'Paracetamol 500 mg. दवा की जानकारी तैयार है।',
      AppLanguage.hindi,
    );
    await speech.stop();
  });
}
