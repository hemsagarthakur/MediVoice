import 'package:flutter_test/flutter_test.dart';
import 'package:medivoice/core/models/medicine_instruction.dart';
import 'package:medivoice/core/services/safety_validator.dart';

void main() {
  const validator = SafetyValidator();

  test('missing medicine name blocks confirmation', () {
    final result = validator.validate(const [
      MedicineInstruction(dose: '1 tablet'),
    ]);
    expect(result.hasBlockingIssues, isTrue);
  });

  test('missing critical fields require acknowledgement', () {
    final result = validator.validate(const [
      MedicineInstruction(medicineName: 'Paracetamol'),
    ]);
    expect(result.hasBlockingIssues, isFalse);
    expect(result.requiresAcknowledgement, isTrue);
  });

  test('complete certain fields need no extra acknowledgement', () {
    final result = validator.validate(const [
      MedicineInstruction(
        medicineName: 'Paracetamol',
        strength: '500 mg',
        dose: '1 tablet',
        frequency: 'Twice daily',
        timing: 'Morning and evening',
      ),
    ]);
    expect(result.hasBlockingIssues, isFalse);
    expect(result.requiresAcknowledgement, isFalse);
  });

  test('an uncertain dose requires acknowledgement', () {
    final result = validator.validate(const [
      MedicineInstruction(
        medicineName: 'Paracetamol',
        strength: '500 mg',
        dose: '1?',
        frequency: 'Twice daily',
        timing: 'Morning and evening',
        uncertainFields: {MedicineField.dose},
      ),
    ]);
    expect(result.requiresAcknowledgement, isTrue);
  });

  test('a suspicious per-dose unit count requires acknowledgement', () {
    final result = validator.validate(const [
      MedicineInstruction(
        medicineName: 'Example medicine',
        strength: '500 mg',
        dose: '10 tablets',
        frequency: 'Twice daily',
        timing: 'Morning and evening',
      ),
    ]);

    expect(result.requiresAcknowledgement, isTrue);
    expect(result.attentionMessages, hasLength(1));
    expect(result.attentionMessages.single, contains('per-dose unit count'));
  });
}
