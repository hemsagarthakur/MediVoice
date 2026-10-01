import '../models/medicine_instruction.dart';

class SafetyValidationResult {
  const SafetyValidationResult({
    required this.blockingMessages,
    required this.attentionMessages,
    required this.requiresAcknowledgement,
  });

  final List<String> blockingMessages;
  final List<String> attentionMessages;
  final bool requiresAcknowledgement;

  bool get hasBlockingIssues => blockingMessages.isNotEmpty;
}

class SafetyValidator {
  const SafetyValidator();

  SafetyValidationResult validate(List<MedicineInstruction> medicines) {
    final blocking = <String>[];
    final attention = <String>[];
    var requiresAcknowledgement = false;
    if (medicines.isEmpty) {
      blocking.add('No medicine was detected. Please rescan.');
    }
    for (var index = 0; index < medicines.length; index++) {
      final medicine = medicines[index];
      if (medicine.medicineName == null) {
        blocking.add('Medicine ${index + 1} needs a name before confirmation.');
      }
      for (final field in criticalMedicineFields) {
        if (field == MedicineField.medicineName) continue;
        if (medicine.valueFor(field) == null ||
            medicine.uncertainFields.contains(field)) {
          requiresAcknowledgement = true;
        }
      }
      if (medicine.uncertainFields.contains(MedicineField.medicineName)) {
        requiresAcknowledgement = true;
      }
      if (_hasSuspiciousUnitCount(medicine.dose)) {
        requiresAcknowledgement = true;
        attention.add(
          'Medicine ${index + 1} has an unusually high per-dose unit count. Verify it against the original image or with a pharmacist.',
        );
      }
    }
    return SafetyValidationResult(
      blockingMessages: blocking,
      attentionMessages: attention,
      requiresAcknowledgement: requiresAcknowledgement,
    );
  }

  bool _hasSuspiciousUnitCount(String? dose) {
    if (dose == null) return false;
    final match = RegExp(
      r'\b(\d+(?:\.\d+)?)\s*(?:tablets?|tabs?|capsules?|caps?|puffs?)\b',
      caseSensitive: false,
    ).firstMatch(dose);
    final count = double.tryParse(match?.group(1) ?? '');
    return count != null && count >= 5;
  }
}
