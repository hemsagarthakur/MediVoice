import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'scan_controller.dart';

class OcrDebugScreen extends StatelessWidget {
  const OcrDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScanController>();
    final sourceText = controller.sourceText ?? '';

    if (!kDebugMode || !controller.isOcrDebugViewerEnabled) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Developer OCR viewer')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: 'Development only OCR text viewer.',
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Development only: this is the exact on-device OCR output. '
                    'It is kept only for the active scan and is never shown in the release flow.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Extracted OCR text',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      sourceText,
                      semanticsLabel: 'Extracted OCR text: $sourceText',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: sourceText));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('OCR text copied for development testing.'),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy OCR text'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('Close viewer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
