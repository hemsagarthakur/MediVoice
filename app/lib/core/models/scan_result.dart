import 'medicine_instruction.dart';
import 'scan_mode.dart';

class ScanResult {
  const ScanResult({
    required this.mode,
    required this.sourceText,
    required this.medicines,
    this.warnings = const [],
    this.requestId,
  });

  final ScanMode mode;
  final String sourceText;
  final List<MedicineInstruction> medicines;
  final List<String> warnings;
  final String? requestId;

  ScanResult copyWith({List<MedicineInstruction>? medicines}) => ScanResult(
    mode: mode,
    sourceText: sourceText,
    medicines: medicines ?? this.medicines,
    warnings: warnings,
    requestId: requestId,
  );
}
