import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/translation_result.dart';
import 'scan_controller.dart';

class ProcessingScreen extends StatelessWidget {
  const ProcessingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select<ScanController, ScanWorkflowState>(
      (controller) => controller.state,
    );
    final language = context.select<ScanController, AppLanguage>(
      (controller) => controller.selectedLanguage,
    );
    final message = switch (state) {
      ScanWorkflowState.processingOcr => 'Reading text on the device…',
      ScanWorkflowState.processingExtraction =>
        'Structuring medicine information…',
      ScanWorkflowState.preparingResult =>
        language == AppLanguage.english
            ? 'Preparing verified English output…'
            : 'Preparing ${language.label} output. First use may download the on-device language model…',
      _ => 'Working…',
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing'),
        automaticallyImplyLeading: false,
      ),
      body: Semantics(
        liveRegion: true,
        label: message,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(strokeWidth: 6),
                ),
                const SizedBox(height: 24),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Do not rely on the result until you have reviewed every field.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
