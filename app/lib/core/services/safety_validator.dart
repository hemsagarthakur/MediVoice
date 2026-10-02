import '../models/medicine_instruction.dart';

enum ScanConfidenceLevel { high, medium, low }

class SafetyValidationResult {
  const SafetyValidationResult({
    required this.blockingMessages,
    required this.attentionMessages,
    required this.requiresAcknowledgement,
    required this.confidence,
  });

  final List<String> blockingMessages;
  final List<String> attentionMessages;
  final bool requiresAcknowledgement;
  final ScanConfidenceLevel confidence;

  bool get hasBlockingIssues => blockingMessages.isNotEmpty;
}

class SafetyValidator {
  const SafetyValidator();

  SafetyValidationResult validate(
    List<MedicineInstruction> medicines, {
    List<String> scanWarnings = const [],
  }) {
    final blocking = <String>[];
    final attention = <String>[];
    var requiresAcknowledgement = false;
    var hasLowConfidenceSignal = scanWarnings.isNotEmpty;
    var hasMediumConfidenceSignal = false;
    if (medicines.isEmpty) {
      blocking.add('No medicine was detected. Please rescan.');
      hasLowConfidenceSignal = true;
    }
    for (var index = 0; index < medicines.length; index++) {
      final medicine = medicines[index];
      if (medicine.medicineName == null) {
        blocking.add('Medicine ${index + 1} needs a name before confirmation.');
      }

      final missingCritical = criticalMedicineFields
          .where((field) => medicine.valueFor(field) == null)
          .toSet();
      if (missingCritical.isNotEmpty) {
        hasLowConfidenceSignal = true;
        requiresAcknowledgement = true;
        attention.add(
          'Medicine ${index + 1} has important information that was not detected. Review the highlighted details.',
        );
      }

      if (medicine.uncertainFields.isNotEmpty) {
        requiresAcknowledgement = true;
        if (medicine.uncertainFields.any(criticalMedicineFields.contains)) {
          hasLowConfidenceSignal = true;
        } else {
          hasMediumConfidenceSignal = true;
        }
      }
      if (_hasSuspiciousUnitCountForReview(medicine.dose)) {
        requiresAcknowledgement = true;
        hasLowConfidenceSignal = true;
        attention.add(
          'Medicine ${index + 1} has an unusually high per-dose unit count. Verify it against the original image or with a pharmacist.',
        );
      }
      if (medicine.warnings.isNotEmpty) {
        hasLowConfidenceSignal = true;
      }
      if (medicine.duration == null || medicine.foodInstruction == null) {
        hasMediumConfidenceSignal = true;
      }
    }
    return SafetyValidationResult(
      blockingMessages: blocking,
      attentionMessages: attention,
      requiresAcknowledgement: requiresAcknowledgement,
      confidence: hasLowConfidenceSignal
          ? ScanConfidenceLevel.low
          : hasMediumConfidenceSignal
          ? ScanConfidenceLevel.medium
          : ScanConfidenceLevel.high,
    );
  }
}

Set<MedicineField> medicineFieldsRequiringReview(MedicineInstruction medicine) {
  final fields = <MedicineField>{...medicine.uncertainFields};
  for (final field in criticalMedicineFields) {
    if (medicine.valueFor(field) == null) fields.add(field);
  }
  if (_hasSuspiciousUnitCountForReview(medicine.dose)) {
    fields.add(MedicineField.dose);
  }
  return fields;
}

bool _hasSuspiciousUnitCountForReview(String? dose) {
  if (dose == null) return false;
  final match = RegExp(
    r'\b(\d+(?:\.\d+)?)\s*(?:tablets?|tabs?|capsules?|caps?|puffs?)\b',
    caseSensitive: false,
  ).firstMatch(dose);
  final count = double.tryParse(match?.group(1) ?? '');
  return count != null && count >= 5;
}
