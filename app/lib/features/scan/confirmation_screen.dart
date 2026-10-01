import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/scan_mode.dart';
import '../../core/models/translation_result.dart';
import '../../shared/widgets/demo_mode_banner.dart';
import '../../shared/widgets/medicine_fields_card.dart';
import '../../shared/widgets/primary_action_button.dart';
import 'scan_controller.dart';

class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScanController>();
    final result = controller.result;
    final safety = controller.safety;
    if (result == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Review medicine information')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Check before continuing',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Compare every field with the image. Edit anything that is incorrect. Missing information will stay missing.',
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
              MedicineFieldsCard(
                index: entry.$1,
                medicine: entry.$2,
                onChanged: (field, value) =>
                    controller.updateMedicine(entry.$1, field, value),
              ),
            if (safety.blockingMessages.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Required corrections',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    for (final message in safety.blockingMessages)
                      Text(message),
                  ],
                ),
              ),
            if (safety.attentionMessages.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Double-check this value',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    for (final message in safety.attentionMessages)
                      Text(message),
                  ],
                ),
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
                  'I checked the highlighted or missing information and understand it may be incomplete.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AppLanguage>(
              initialValue: controller.selectedLanguage,
              decoration: const InputDecoration(
                labelText: 'Result language',
                prefixIcon: Icon(Icons.translate),
              ),
              items: [
                for (final language in AppLanguage.values)
                  DropdownMenuItem(
                    value: language,
                    child: Text(language.label),
                  ),
              ],
              onChanged: (language) {
                if (language != null) controller.setLanguage(language);
              },
            ),
            if (kDebugMode && controller.sourceText != null) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('Developer: raw OCR text'),
                childrenPadding: const EdgeInsets.all(12),
                children: [SelectableText(controller.sourceText!)],
              ),
            ],
            const SizedBox(height: 22),
            PrimaryActionButton(
              label: 'Confirm and continue',
              icon: Icons.verified_outlined,
              onPressed: controller.canConfirm
                  ? controller.confirmAndPrepareResult
                  : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await controller.newScan();
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Rescan'),
            ),
          ],
        ),
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
