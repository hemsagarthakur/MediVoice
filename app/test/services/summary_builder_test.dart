import 'package:flutter_test/flutter_test.dart';
import 'package:medivoice/core/models/medicine_instruction.dart';
import 'package:medivoice/core/models/medicine_reference.dart';
import 'package:medivoice/core/services/summary_builder.dart';

void main() {
  const builder = SummaryBuilder();

  test('keeps missing dose explicit without inventing instructions', () {
    final text = builder.build(const [
      MedicineInstruction(medicineName: 'Cetirizine', strength: '10 mg'),
    ]);
    expect(text, contains('Cetirizine 10 mg.'));
    expect(text, isNot(contains('This medicine is')));
    expect(text, contains('The dose was not clear.'));
    expect(text, contains('When to take it was not clear.'));
    expect(text, isNot(contains('1 tablet')));
  });

  test('builds short plain-language instructions instead of field labels', () {
    final text = builder.build(const [
      MedicineInstruction(
        medicineName: 'Paracetamol',
        strength: '500 mg',
        dose: '1 tablet',
        frequency: '3 times daily',
        duration: '5 days',
        foodInstruction: 'After food',
      ),
    ]);
    expect(text, contains('Paracetamol 500 mg.'));
    expect(
      text,
      contains('Take 1 tablet after food, three times a day, for 5 days.'),
    );
    expect(text, contains("Follow your doctor's instructions."));
    expect(text, isNot(contains('Dose:')));
    expect(text, isNot(contains('Frequency:')));
    expect(text, isNot(contains('Duration:')));
    expect(text, isNot(contains('side effect')));
  });

  test(
    'adds concise trusted reference facts without changing instructions',
    () {
      final text = builder.build(
        const [
          MedicineInstruction(
            medicineName: 'Azithromycin',
            strength: '500 mg',
            dose: '1 tablet',
            frequency: 'Once daily',
          ),
        ],
        references: const [
          MedicineReference(
            requestedName: 'Azithromycin',
            canonicalName: 'Azithromycin',
            rxCui: '18631',
            commonlyUsedFor: ['certain bacterial infections'],
            commonSideEffects: ['nausea', 'diarrhea'],
            importantCaution: 'Seek help if a serious allergic reaction occurs',
            source: 'dailymed',
            matchQuality: 'exact',
            available: true,
          ),
        ],
      );
      expect(text, contains('Take 1 tablet once a day.'));
      expect(text, contains('Commonly used for certain bacterial infections'));
      expect(text, contains('Common side effects: nausea, diarrhea.'));
      expect(text, contains('Important caution: seek help'));
      expect(text, isNot(contains('RxCUI')));
      expect(text, isNot(contains('DailyMed')));
    },
  );

  test('long regulatory reference text is omitted and facts are capped', () {
    final longText = List.filled(
      30,
      'For those adult patients who have not healed after treatment',
    ).join(' ');
    final text = builder.build(
      const [
        MedicineInstruction(
          medicineName: 'Pantoprazole',
          strength: '40 mg',
          dose: '1 tablet',
          frequency: 'Once daily',
          timing: 'Before breakfast',
          duration: '5 days',
        ),
      ],
      references: [
        MedicineReference(
          requestedName: 'Pantoprazole',
          commonlyUsedFor: [longText, 'reducing stomach acid'],
          commonSideEffects: const [
            'headache',
            'nausea',
            'stomach discomfort',
            'a fourth item that must not be included',
          ],
          importantCaution: 'WARNINGS AND PRECAUTIONS (5.1) Stop and seek medical help if you have a serious allergic reaction.',
          matchQuality: 'exact',
          available: true,
        ),
      ],
    );

    expect(text, contains('Commonly used for reducing stomach acid.'));
    expect(
      text,
      contains('Common side effects: headache, nausea, stomach discomfort.'),
    );
    expect(text, contains('Important caution: stop and seek medical help'));
    expect(text, isNot(contains('adult patients')));
    expect(text, isNot(contains('(5.1)')));
    expect(text, isNot(contains('fourth item')));
  });
}
