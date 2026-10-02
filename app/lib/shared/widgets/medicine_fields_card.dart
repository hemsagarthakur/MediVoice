import 'package:flutter/material.dart';

import '../../core/models/medicine_instruction.dart';

class MedicineFieldsCard extends StatelessWidget {
  const MedicineFieldsCard({
    required this.index,
    required this.medicine,
    required this.onChanged,
    this.fields = const {},
    super.key,
  });

  final int index;
  final MedicineInstruction medicine;
  final void Function(MedicineField field, String value) onChanged;
  final Set<MedicineField> fields;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Medicine ${index + 1}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              fields.length == MedicineField.values.length
                  ? 'Check each field against the original image.'
                  : 'Only unclear details are shown here.',
            ),
            const SizedBox(height: 18),
            for (final field in MedicineField.values.where(
              fields.contains,
            )) ...[
              _MedicineTextField(
                key: ValueKey('${index}_${field.name}'),
                field: field,
                value: medicine.valueFor(field),
                uncertain: medicine.uncertainFields.contains(field),
                onChanged: (value) => onChanged(field, value),
              ),
              const SizedBox(height: 12),
            ],
            for (final warning in medicine.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(warning)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MedicineTextField extends StatelessWidget {
  const _MedicineTextField({
    required this.field,
    required this.value,
    required this.uncertain,
    required this.onChanged,
    super.key,
  });

  final MedicineField field;
  final String? value;
  final bool uncertain;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final missingCritical =
        criticalMedicineFields.contains(field) && value == null;
    final highlighted = uncertain || missingCritical;
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      maxLines: field == MedicineField.additionalInstruction ? 2 : 1,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: field.label,
        hintText: 'Not detected',
        helperText: uncertain
            ? 'Uncertain: compare with the image and edit if needed.'
            : missingCritical
            ? 'Not detected: acknowledgement will be required.'
            : null,
        helperMaxLines: 2,
        filled: true,
        fillColor: highlighted
            ? Theme.of(context).colorScheme.errorContainer
                  .withValues(alpha: 0.55)
            : Colors.white,
        prefixIcon: highlighted
            ? const Icon(Icons.warning_amber_rounded)
            : null,
      ),
    );
  }
}
