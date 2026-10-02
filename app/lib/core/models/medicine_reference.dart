class MedicineReference {
  const MedicineReference({
    required this.requestedName,
    required this.matchQuality,
    required this.available,
    this.canonicalName,
    this.rxCui,
    this.commonlyUsedFor = const [],
    this.commonSideEffects = const [],
    this.importantCaution,
    this.source,
    this.sourceReference,
  });

  factory MedicineReference.fromJson(Map<String, Object?> json) {
    List<String> stringList(String key, {required int maximum}) {
      final value = json[key];
      if (value is! List ||
          value.length > maximum ||
          value.any((item) => item is! String)) {
        throw const FormatException('Invalid medicine reference list.');
      }
      return value.cast<String>();
    }

    final requestedName = json['requested_name'];
    final matchQuality = json['match_quality'];
    final available = json['available'];
    if (requestedName is! String ||
        matchQuality is! String ||
        available is! bool) {
      throw const FormatException('Invalid medicine reference.');
    }
    return MedicineReference(
      requestedName: requestedName,
      canonicalName: json['canonical_name'] as String?,
      rxCui: json['rx_cui'] as String?,
      commonlyUsedFor: stringList('commonly_used_for', maximum: 3),
      commonSideEffects: stringList('common_side_effects', maximum: 4),
      importantCaution: json['important_caution'] as String?,
      source: json['source'] as String?,
      sourceReference: json['source_reference'] as String?,
      matchQuality: matchQuality,
      available: available,
    );
  }

  factory MedicineReference.unavailable(
    String requestedName, {
    bool uncertain = false,
  }) => MedicineReference(
    requestedName: requestedName,
    matchQuality: uncertain ? 'ambiguous' : 'none',
    available: false,
  );

  final String requestedName;
  final String? canonicalName;
  final String? rxCui;
  final List<String> commonlyUsedFor;
  final List<String> commonSideEffects;
  final String? importantCaution;
  final String? source;
  final String? sourceReference;
  final String matchQuality;
  final bool available;
}
