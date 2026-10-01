import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_error.dart';
import '../../core/models/medicine_instruction.dart';
import '../../core/models/scan_mode.dart';
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
      appBar: AppBar(title: const Text('Verified result')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Confirmed medicine information',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (controller.demoMode) ...[
              const SizedBox(height: 14),
              const DemoModeBanner(),
            ],
            const SizedBox(height: 14),
            for (final entry in result.medicines.indexed)
              _ConfirmedMedicineCard(index: entry.$1, medicine: entry.$2),
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
            const SizedBox(height: 22),
            Text(
              'Explanation in ${translation.language.label}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SelectableText(
                translation.translatedText,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            if (translation.language.bcpCode != 'en') ...[
              const SizedBox(height: 10),
              ExpansionTile(
                title: const Text('Show confirmed English'),
                childrenPadding: const EdgeInsets.all(12),
                children: [SelectableText(translation.verifiedEnglishText)],
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
              label: controller.isSpeaking ? 'Playing audio' : 'Play audio',
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
              label: const Text('Scan another'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmedMedicineCard extends StatelessWidget {
  const _ConfirmedMedicineCard({required this.index, required this.medicine});

  final int index;
  final MedicineInstruction medicine;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Medicine ${index + 1}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            for (final field in MedicineField.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 132,
                      child: Text(
                        field.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      child: Text(medicine.valueFor(field) ?? 'Not detected'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
