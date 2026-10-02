import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_error.dart';
import '../../core/models/medicine_instruction.dart';
import '../../core/models/medicine_reference.dart';
import '../../core/models/scan_mode.dart';
import '../../core/models/translation_result.dart';
import '../../core/services/summary_builder.dart';
import '../../shared/widgets/demo_mode_banner.dart';
import '../../shared/widgets/disclaimer_banner.dart';
import '../../shared/widgets/error_panel.dart';
import '../../shared/widgets/primary_action_button.dart';
import 'scan_controller.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScanController>();
    final result = controller.result;
    final translation = controller.translation;
    if (result == null || translation == null) return const SizedBox.shrink();
    final translationError = controller.error?.code == AppErrorCode.translation;

    return Scaffold(
      appBar: AppBar(title: const Text('Your medicines')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Your medicines',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('A simple explanation of the prescription you checked.'),
            if (controller.demoMode) ...[
              const SizedBox(height: 14),
              const DemoModeBanner(),
            ],
            const SizedBox(height: 14),
            for (final entry in result.medicines.indexed)
              _MedicineResultCard(
                index: entry.$1,
                medicine: entry.$2,
                reference: entry.$1 < controller.references.length
                    ? controller.references[entry.$1]
                    : null,
              ),
            if (result.mode == ScanMode.medicineStrip) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Dosage may not be available from this image. Check your prescription or pharmacist.',
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Easy explanation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SelectableText(
                translation.translatedText,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            if (translation.language != AppLanguage.english) ...[
              const SizedBox(height: 10),
              ExpansionTile(
                title: const Text('Show checked English explanation'),
                childrenPadding: const EdgeInsets.all(12),
                children: [SelectableText(translation.verifiedEnglishText)],
              ),
            ],
            const SizedBox(height: 18),
            DropdownButtonFormField<AppLanguage>(
              key: ValueKey(controller.selectedLanguage),
              initialValue: controller.selectedLanguage,
              decoration: const InputDecoration(
                labelText: 'Explanation language',
                prefixIcon: Icon(Icons.translate),
              ),
              items: [
                for (final language in AppLanguage.values)
                  DropdownMenuItem(
                    value: language,
                    child: Text(language.label),
                  ),
              ],
              onChanged: controller.isTranslating
                  ? null
                  : (language) {
                      if (language != null) {
                        unawaited(controller.changeLanguage(language));
                      }
                    },
            ),
            if (controller.isTranslating) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Preparing ${controller.selectedLanguage.label}. First use may download the language pack.',
                ),
              ),
            ],
            if (controller.error != null) ...[
              const SizedBox(height: 14),
              ErrorPanel(
                error: controller.error!,
                onRetry: translationError ? controller.retryTranslation : null,
              ),
            ],
            const SizedBox(height: 20),
            PrimaryActionButton(
              label: controller.isSpeaking ? 'Listening…' : 'Listen',
              semanticLabel: controller.isSpeaking
                  ? 'Medicine explanation is playing'
                  : 'Listen to medicine explanation',
              icon: Icons.volume_up_outlined,
              onPressed: controller.canPlayAudio ? controller.play : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.isSpeaking ? controller.stop : null,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Stop'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.canPlayAudio ? controller.play : null,
                    icon: const Icon(Icons.replay),
                    label: const Text('Replay'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const DisclaimerBanner(),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                await controller.newScan();
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Scan another prescription'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicineResultCard extends StatelessWidget {
  const _MedicineResultCard({
    required this.index,
    required this.medicine,
    required this.reference,
  });

  final int index;
  final MedicineInstruction medicine;
  final MedicineReference? reference;

  @override
  Widget build(BuildContext context) {
    final name = medicine.medicineName ?? 'Medicine ${index + 1}';
    final instructions = const SummaryBuilder().buildDoctorInstructions(
      medicine,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text('${index + 1}')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (medicine.strength != null) Text(medicine.strength!),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Your doctor\'s instructions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(instructions),
            const Divider(height: 28),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text('About this medicine'),
              subtitle: const Text(
                'General information, not your prescribed reason',
              ),
              children: [_ReferenceDetails(reference: reference)],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceDetails extends StatelessWidget {
  const _ReferenceDetails({required this.reference});

  final MedicineReference? reference;

  @override
  Widget build(BuildContext context) {
    final value = reference;
    if (value == null || !value.available) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Medicine information unavailable because the medicine name could not be confirmed or the reference service could not be reached.',
        ),
      );
    }
    const builder = SummaryBuilder();
    final usedFor = builder.conciseUse(value);
    final sideEffects = builder.conciseSideEffects(value);
    final caution = builder.conciseCaution(value);
    if (usedFor == null && sideEffects.isEmpty && caution == null) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('Short medicine information is not available.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (usedFor != null) _ReferenceFact(title: 'Used for', value: usedFor),
        if (sideEffects.isNotEmpty)
          _ReferenceFact(
            title: 'Common side effects',
            value: sideEffects.join(', '),
          ),
        if (caution != null)
          _ReferenceFact(title: 'Important caution', value: caution),
      ],
    );
  }
}

class _ReferenceFact extends StatelessWidget {
  const _ReferenceFact({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text('$title: $value'),
    ),
  );
}
