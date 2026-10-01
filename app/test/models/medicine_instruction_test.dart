import 'package:flutter_test/flutter_test.dart';
import 'package:medivoice/core/models/medicine_instruction.dart';

void main() {
  test('normalizes unknown strings to null', () {
    final medicine = MedicineInstruction.fromJson({
      'medicine_name': ' Paracetamol ',
      'strength': '500 mg',
      'dose': 'unknown',
      'frequency': null,
      'timing': null,
      'duration': 'Not detected',
      'food_instruction': null,
      'route': null,
      'additional_instruction': null,
      'uncertain_fields': <String>[],
      'warnings': <String>[],
    });

    expect(medicine.medicineName, 'Paracetamol');
    expect(medicine.dose, isNull);
    expect(medicine.duration, isNull);
  });

  test('editing clears uncertainty only for the edited field', () {
    const medicine = MedicineInstruction(
      dose: '1?',
      uncertainFields: {MedicineField.dose, MedicineField.frequency},
    );
    final edited = medicine.updateField(MedicineField.dose, '1 tablet');
    expect(edited.dose, '1 tablet');
    expect(edited.uncertainFields, {MedicineField.frequency});
  });
}
