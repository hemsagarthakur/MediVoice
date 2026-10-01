enum MedicineField {
  medicineName('medicine_name', 'Medicine name'),
  strength('strength', 'Strength'),
  dose('dose', 'Dose'),
  frequency('frequency', 'Frequency'),
  timing('timing', 'Timing'),
  duration('duration', 'Duration'),
  foodInstruction('food_instruction', 'Food instruction'),
  route('route', 'Route'),
  additionalInstruction('additional_instruction', 'Additional instruction');

  const MedicineField(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static MedicineField fromWire(Object? value) => values.firstWhere(
    (field) => field.wireValue == value,
    orElse: () => throw const FormatException('Unknown uncertain field.'),
  );
}

const criticalMedicineFields = <MedicineField>{
  MedicineField.medicineName,
  MedicineField.strength,
  MedicineField.dose,
  MedicineField.frequency,
  MedicineField.timing,
};

class MedicineInstruction {
  const MedicineInstruction({
    this.medicineName,
    this.strength,
    this.dose,
    this.frequency,
    this.timing,
    this.duration,
    this.foodInstruction,
    this.route,
    this.additionalInstruction,
    this.uncertainFields = const {},
    this.warnings = const [],
  });

  factory MedicineInstruction.fromJson(Map<String, Object?> json) {
    final uncertain = json['uncertain_fields'];
    final warnings = json['warnings'];
    if (uncertain is! List || warnings is! List) {
      throw const FormatException('Invalid medicine metadata.');
    }
    return MedicineInstruction(
      medicineName: _nullableText(json['medicine_name']),
      strength: _nullableText(json['strength']),
      dose: _nullableText(json['dose']),
      frequency: _nullableText(json['frequency']),
      timing: _nullableText(json['timing']),
      duration: _nullableText(json['duration']),
      foodInstruction: _nullableText(json['food_instruction']),
      route: _nullableText(json['route']),
      additionalInstruction: _nullableText(json['additional_instruction']),
      uncertainFields: uncertain.map(MedicineField.fromWire).toSet(),
      warnings: warnings
          .map((value) {
            if (value is! String) {
              throw const FormatException('Invalid medicine warning.');
            }
            return value;
          })
          .toList(growable: false),
    );
  }

  final String? medicineName;
  final String? strength;
  final String? dose;
  final String? frequency;
  final String? timing;
  final String? duration;
  final String? foodInstruction;
  final String? route;
  final String? additionalInstruction;
  final Set<MedicineField> uncertainFields;
  final List<String> warnings;

  String? valueFor(MedicineField field) => switch (field) {
    MedicineField.medicineName => medicineName,
    MedicineField.strength => strength,
    MedicineField.dose => dose,
    MedicineField.frequency => frequency,
    MedicineField.timing => timing,
    MedicineField.duration => duration,
    MedicineField.foodInstruction => foodInstruction,
    MedicineField.route => route,
    MedicineField.additionalInstruction => additionalInstruction,
  };

  MedicineInstruction updateField(MedicineField field, String value) {
    final normalized = _normalize(value);
    final nextUncertain = {...uncertainFields}..remove(field);
    return MedicineInstruction(
      medicineName: field == MedicineField.medicineName
          ? normalized
          : medicineName,
      strength: field == MedicineField.strength ? normalized : strength,
      dose: field == MedicineField.dose ? normalized : dose,
      frequency: field == MedicineField.frequency ? normalized : frequency,
      timing: field == MedicineField.timing ? normalized : timing,
      duration: field == MedicineField.duration ? normalized : duration,
      foodInstruction: field == MedicineField.foodInstruction
          ? normalized
          : foodInstruction,
      route: field == MedicineField.route ? normalized : route,
      additionalInstruction: field == MedicineField.additionalInstruction
          ? normalized
          : additionalInstruction,
      uncertainFields: nextUncertain,
      warnings: warnings,
    );
  }

  Map<String, Object?> toJson() => {
    'medicine_name': medicineName,
    'strength': strength,
    'dose': dose,
    'frequency': frequency,
    'timing': timing,
    'duration': duration,
    'food_instruction': foodInstruction,
    'route': route,
    'additional_instruction': additionalInstruction,
    'uncertain_fields': uncertainFields
        .map((field) => field.wireValue)
        .toList(growable: false),
    'warnings': warnings,
  };

  static String? _nullableText(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw const FormatException('Invalid medicine field.');
    }
    return _normalize(value);
  }

  static String? _normalize(String value) {
    final text = value.trim();
    if (text.isEmpty ||
        const {
          'unknown',
          'not detected',
          'not available',
          'n/a',
          'null',
        }.contains(text.toLowerCase())) {
      return null;
    }
    return text;
  }
}
