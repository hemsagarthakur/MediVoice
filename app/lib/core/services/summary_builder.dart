import '../models/medicine_instruction.dart';
import '../models/medicine_reference.dart';

class SummaryBuilder {
  const SummaryBuilder();

  String build(
    List<MedicineInstruction> medicines, {
    List<MedicineReference> references = const [],
  }) {
    final explanations = <String>[
      for (final entry in medicines.indexed)
        buildMedicine(
          entry.$2,
          reference: entry.$1 < references.length ? references[entry.$1] : null,
        ),
    ].join('\n\n');
    return '$explanations\n\nFollow your doctor\'s instructions. Do not change the dose yourself.';
  }

  String buildMedicine(
    MedicineInstruction medicine, {
    MedicineReference? reference,
  }) {
    final name = medicine.medicineName;
    final strength = medicine.strength;
    final sentences = <String>[
      if (name != null)
        '$name${strength == null ? '' : ' $strength'}.'
      else
        'The medicine name was not clear.',
      if (name != null && strength == null) 'The strength was not clear.',
      _instructionSentence(medicine),
      if (_usefulRoute(medicine.route) case final route?)
        'Use it ${_sentenceValue(route)}.',
      if (_shortInstruction(medicine.additionalInstruction)
          case final instruction?)
        '${_sentenceValue(instruction, lowerFirst: false)}.',
    ];
    final doctorInstructions = sentences.join(' ');
    final about = buildReferenceExplanation(reference);
    return about == null ? doctorInstructions : '$doctorInstructions $about';
  }

  String buildDoctorInstructions(MedicineInstruction medicine) =>
      _instructionSentence(medicine);

  String? buildReferenceExplanation(MedicineReference? reference) {
    if (reference == null || !reference.available) return null;
    final usedFor = conciseUse(reference);
    final sideEffects = conciseSideEffects(reference);
    final caution = conciseCaution(reference);
    final sentences = <String>[
      if (usedFor != null) 'Commonly used for ${_sentenceValue(usedFor)}.',
      if (sideEffects.isNotEmpty)
        'Common side effects: ${_joinNaturally(sideEffects.map(_sentenceValue).toList())}.',
      if (caution != null) 'Important caution: ${_sentenceValue(caution)}.',
    ];
    return sentences.isEmpty ? null : sentences.join(' ');
  }

  String? conciseUse(MedicineReference? reference) =>
      _firstCleanFact(reference?.commonlyUsedFor, maximumLength: 100);

  List<String> conciseSideEffects(MedicineReference? reference) =>
      (reference?.commonSideEffects ?? const <String>[])
          .map((value) => _cleanFact(value, maximumLength: 50))
          .whereType<String>()
          .take(3)
          .toList(growable: false);

  String? conciseCaution(MedicineReference? reference) =>
      _cleanFact(reference?.importantCaution, maximumLength: 120);

  String _instructionSentence(MedicineInstruction medicine) {
    final dose = medicine.dose;
    final schedule = <String>[
      if (medicine.foodInstruction != null)
        _sentenceValue(medicine.foodInstruction!),
      if (medicine.timing != null) _sentenceValue(medicine.timing!),
      if (medicine.frequency != null) _naturalFrequency(medicine.frequency!),
      if (medicine.duration != null)
        'for ${_speakableQuantity(medicine.duration!)}',
    ];

    if (dose != null) {
      final suffix = schedule.isEmpty ? '' : ' ${_joinNaturally(schedule)}';
      return 'Take ${_sentenceValue(dose)}$suffix.';
    }

    final sentences = <String>['The dose was not clear.'];
    if (schedule.isNotEmpty) {
      sentences.add('The prescription also says ${_joinNaturally(schedule)}.');
    } else {
      sentences.add('When to take it was not clear.');
    }
    return sentences.join(' ');
  }

  String _naturalFrequency(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'once daily' || 'once a day' => 'once a day',
      'twice daily' || 'twice a day' => 'twice a day',
      'three times daily' ||
      '3 times daily' ||
      'three times a day' => 'three times a day',
      'four times daily' ||
      '4 times daily' ||
      'four times a day' => 'four times a day',
      _ => _sentenceValue(value),
    };
  }

  String _joinNaturally(List<String> parts) {
    if (parts.length == 1) return parts.single;
    if (parts.length == 2) return '${parts.first}, ${parts.last}';
    return '${parts.sublist(0, parts.length - 1).join(', ')}, ${parts.last}';
  }

  String _sentenceValue(String value, {bool lowerFirst = true}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    if (!lowerFirst) return trimmed;
    return '${trimmed[0].toLowerCase()}${trimmed.substring(1)}';
  }

  String _speakableQuantity(String value) => _sentenceValue(value);

  String? _usefulRoute(String? value) {
    final route = value?.trim();
    if (route == null || route.isEmpty || route.length > 40) return null;
    if (const {'oral', 'by mouth', 'po'}.contains(route.toLowerCase())) {
      return null;
    }
    return route;
  }

  String? _shortInstruction(String? value) =>
      _cleanFact(value, maximumLength: 100);

  String? _firstCleanFact(List<String>? values, {required int maximumLength}) {
    for (final value in values ?? const <String>[]) {
      final clean = _cleanFact(value, maximumLength: maximumLength);
      if (clean != null) return clean;
    }
    return null;
  }

  String? _cleanFact(String? value, {required int maximumLength}) {
    if (value == null) return null;
    var clean = value
        .replaceAll(RegExp(r'\(\s*\d+(?:\.\d+)?\s*\)'), '')
        .replaceAll(
          RegExp(
            r'^(?:warnings?(?: and precautions)?|adverse reactions?|indications? and usage)\s*[:.-]?\s*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    clean = clean.replaceAll(RegExp(r'[.;:,\s]+$'), '');
    if (clean.isEmpty || clean.length > maximumLength) return null;
    if (RegExp(
      r'\b(?:section|clinical trials?|study patients?)\b',
      caseSensitive: false,
    ).hasMatch(clean)) {
      return null;
    }
    return clean;
  }
}
