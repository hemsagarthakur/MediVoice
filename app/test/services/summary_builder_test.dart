import 'package:flutter_test/flutter_test.dart';
import 'package:medivoice/core/models/medicine_instruction.dart';
import 'package:medivoice/core/services/summary_builder.dart';

void main() {
  const builder = SummaryBuilder();

  test('keeps missing dose and duration explicit', () {
    final text = builder.build(const [
      MedicineInstruction(medicineName: 'Cetirizine', strength: '10 mg'),
    ]);
    expect(text, contains('Dose: Not detected.'));
    expect(text, contains('Duration: Not detected.'));
    expect(text, isNot(contains('1 tablet')));
  });

  test('includes each medicine without adding fields', () {
    final text = builder.build(const [
      MedicineInstruction(medicineName: 'A', dose: '1 tablet'),
      MedicineInstruction(medicineName: 'B', dose: '2 drops'),
    ]);
    expect(text, contains('Medicine 1.'));
    expect(text, contains('Medicine 2.'));
    expect(text, contains('2 drops'));
  });
}
