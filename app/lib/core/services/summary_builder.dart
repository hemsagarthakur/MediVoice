import '../models/medicine_instruction.dart';

class SummaryBuilder {
  const SummaryBuilder();

  String build(List<MedicineInstruction> medicines) {
    return medicines.indexed
        .map((entry) {
          final index = entry.$1;
          final medicine = entry.$2;
          final sentences = <String>[
            if (medicines.length > 1) 'Medicine ${index + 1}.',
            'Medicine: ${medicine.medicineName ?? 'Not detected'}.',
            'Strength: ${medicine.strength ?? 'Not detected'}.',
            'Dose: ${medicine.dose ?? 'Not detected'}.',
            if (medicine.frequency != null)
              'Frequency: ${medicine.frequency}.'
            else if (medicine.timing == null)
              'Frequency or timing was not detected.',
            if (medicine.timing != null) 'Timing: ${medicine.timing}.',
            'Duration: ${medicine.duration ?? 'Not detected'}.',
            if (medicine.foodInstruction != null)
              'Food instruction: ${medicine.foodInstruction}.',
            if (medicine.route != null) 'Route: ${medicine.route}.',
            if (medicine.additionalInstruction != null)
              'Additional instruction: ${medicine.additionalInstruction}.',
          ];
          return sentences.join(' ');
        })
        .join('\n\n');
  }
}
