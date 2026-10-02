import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/medicine_instruction.dart';
import '../../core/models/scan_mode.dart';
import '../../core/services/safety_validator.dart';
import '../../shared/widgets/demo_mode_banner.dart';
import '../../shared/widgets/medicine_fields_card.dart';
import '../../shared/widgets/primary_action_button.dart';
import 'ocr_debug_screen.dart';
import 'scan_controller.dart';

class ConfirmationScreen extends StatefulWidget {
  const ConfirmationScreen({super.key});

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  List<Set<MedicineField>>? _activeReviewFields;
  bool _reviewingOnlyUnclear = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScanController>();
    final result = controller.result;
    final safety = controller.safety;
    if (result == null) return const SizedBox.shrink();
    final count = result.medicines.length;
    final detectedReviewFields = [
      for (final medicine in result.medicines)
        medicineFieldsRequiringReview(medicine),
    ];
    final hasMarkedFields = detectedReviewFields.any(
      (fields) => fields.isNotEmpty,
    );
    final reviewFields = _activeReviewFields ?? detectedReviewFields;
    final reviewingDetails = _activeReviewFields != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check your medicines'),
        actions: [
          if (controller.isOcrDebugViewerEnabled &&
              controller.sourceText != null)
            IconButton(
              key: const ValueKey('developer_ocr_viewer'),
              tooltip: 'View OCR text (developer)',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: controller,
                    child: const OcrDebugScreen(),
                  ),
                ),
              ),
              icon: const Icon(Icons.code),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'We found $count ${count == 1 ? 'medicine' : 'medicines'}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            _ConfidenceCard(level: safety.confidence),
            const SizedBox(height: 8),
            Text(
              safety.requiresAcknowledgement
                  ? 'Please check the highlighted information. Everything else can be accepted together.'
                  : 'Take a quick look. You do not need to check each field separately.',
            ),
            if (controller.demoMode) ...[
              const SizedBox(height: 14),
              const DemoModeBanner(),
            ],
            if (controller.mode == ScanMode.medicineStrip) ...[
              const SizedBox(height: 14),
              const _WarningBox(
                message: 'Dosage may not be available from this image. Check your prescription or pharmacist.',
              ),
            ],
            for (final warning in result.warnings) ...[
              const SizedBox(height: 10),
              _WarningBox(message: warning),
            ],
            const SizedBox(height: 18),
            for (final entry in result.medicines.indexed)
              _MedicineReviewCard(index: entry.$1, medicine: entry.$2),
            if (safety.blockingMessages.isNotEmpty)
              _ReviewNotice(
                title: 'A medicine name needs correction',
                messages: safety.blockingMessages,
                isError: true,
              ),
            if (safety.attentionMessages.isNotEmpty)
              _ReviewNotice(
                title: 'Please double-check',
                messages: safety.attentionMessages,
              ),
            if (safety.requiresAcknowledgement)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: controller.acknowledgedUncertainty,
                onChanged: safety.hasBlockingIssues
                    ? null
                    : (value) =>
                          controller.setAcknowledgedUncertainty(value ?? false),
                title: const Text(
                  'I reviewed the unclear details against the prescription.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            if (reviewingDetails) ...[
              const SizedBox(height: 12),
              Text(
                _reviewingOnlyUnclear
                    ? 'Review unclear details'
                    : 'Correct medicine information',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Change only what you can verify from the prescription.',
              ),
              const SizedBox(height: 14),
              for (final entry in result.medicines.indexed)
                if (reviewFields[entry.$1].isNotEmpty)
                  MedicineFieldsCard(
                    index: entry.$1,
                    medicine: entry.$2,
                    fields: reviewFields[entry.$1],
                    onChanged: (field, value) =>
                        controller.updateMedicine(entry.$1, field, value),
                  ),
            ],
            const SizedBox(height: 18),
            PrimaryActionButton(
              label: 'Looks correct',
              icon: Icons.check_circle_outline,
              onPressed: controller.canConfirm
                  ? controller.confirmAndPrepareResult
                  : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                if (reviewingDetails) {
                  _activeReviewFields = null;
                  _reviewingOnlyUnclear = false;
                  return;
                }
                _reviewingOnlyUnclear = hasMarkedFields;
                _activeReviewFields = [
                  for (final fields in detectedReviewFields)
                    hasMarkedFields
                        ? Set<MedicineField>.of(fields)
                        : MedicineField.values.toSet(),
                ];
              }),
              icon: const Icon(Icons.edit_outlined),
              label: Text(
                reviewingDetails ? 'Hide details' : 'Review unclear details',
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () async {
                await controller.newScan();
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Scan again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceCard extends StatelessWidget {
  const _ConfidenceCard({required this.level});

  final ScanConfidenceLevel level;

  @override
  Widget build(BuildContext context) {
    final (label, description, icon, color) = switch (level) {
      ScanConfidenceLevel.high => (
        'High confidence',
        'The medicine details were clearly extracted and passed the safety checks.',
        Icons.verified_outlined,
        Colors.green,
      ),
      ScanConfidenceLevel.medium => (
        'Medium confidence',
        'The main instructions are clear, but some optional details are missing or uncertain.',
        Icons.info_outline,
        Colors.orange,
      ),
      ScanConfidenceLevel.low => (
        'Low confidence',
        'Important information is unclear, missing, suspicious, or conflicting. Review highlighted details.',
        Icons.warning_amber_rounded,
        Theme.of(context).colorScheme.error,
      ),
    };
    return Semantics(
      label: '$label. $description',
      container: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.55)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, semanticLabel: label),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicineReviewCard extends StatelessWidget {
  const _MedicineReviewCard({required this.index, required this.medicine});

  final int index;
  final MedicineInstruction medicine;

  @override
  Widget build(BuildContext context) {
    final name = medicine.medicineName ?? 'Medicine name not detected';
    final reviewFields = medicineFieldsRequiringReview(medicine);
    final nameUncertain = reviewFields.contains(MedicineField.medicineName);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(child: Text('${index + 1}')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                ),
                if (nameUncertain)
                  const Icon(
                    Icons.warning_amber_rounded,
                    semanticLabel: 'Needs review',
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _ReviewRow(
              label: 'Strength',
              value: medicine.strength,
              needsReview: reviewFields.contains(MedicineField.strength),
            ),
            _ReviewRow(
              label: 'How much',
              value: medicine.dose,
              needsReview: reviewFields.contains(MedicineField.dose),
            ),
            _ReviewRow(
              label: 'When',
              value: [
                medicine.frequency,
                medicine.timing,
              ].whereType<String>().join(', '),
              needsReview:
                  reviewFields.contains(MedicineField.frequency) ||
                  reviewFields.contains(MedicineField.timing),
            ),
            _ReviewRow(
              label: 'With food',
              value: medicine.foodInstruction,
              needsReview: medicine.uncertainFields.contains(
                MedicineField.foodInstruction,
              ),
            ),
            _ReviewRow(
              label: 'For how long',
              value: medicine.duration,
              needsReview: medicine.uncertainFields.contains(
                MedicineField.duration,
              ),
            ),
            if (medicine.route != null ||
                reviewFields.contains(MedicineField.route))
              _ReviewRow(
                label: 'How to use it',
                value: medicine.route,
                needsReview: medicine.uncertainFields.contains(
                  MedicineField.route,
                ),
              ),
            if (medicine.additionalInstruction != null ||
                reviewFields.contains(MedicineField.additionalInstruction))
              _ReviewRow(
                label: 'Other instruction',
                value: medicine.additionalInstruction,
                needsReview: medicine.uncertainFields.contains(
                  MedicineField.additionalInstruction,
                ),
              ),
            for (final warning in medicine.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(warning),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    required this.needsReview,
  });

  final String label;
  final String? value;
  final bool needsReview;

  @override
  Widget build(BuildContext context) {
    final displayed = value == null || value!.trim().isEmpty
        ? 'Not detected'
        : value!;
    return Semantics(
      label: needsReview
          ? '$label needs review. $displayed'
          : '$label. $displayed',
      container: true,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: needsReview
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (needsReview) ...[
                const Icon(Icons.warning_amber_rounded, size: 22),
                const SizedBox(width: 8),
              ],
              SizedBox(
                width: 105,
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(child: Text(displayed)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewNotice extends StatelessWidget {
  const _ReviewNotice({
    required this.title,
    required this.messages,
    this.isError = false,
  });

  final String title;
  final List<String> messages;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final message in messages) Text(message),
        ],
      ),
    );
  }
}

class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
