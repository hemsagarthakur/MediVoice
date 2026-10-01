import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/widgets/error_panel.dart';
import 'confirmation_screen.dart';
import 'image_review_screen.dart';
import 'processing_screen.dart';
import 'result_screen.dart';
import 'scan_controller.dart';

class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ScanController>(
      builder: (context, controller, _) {
        final processing = {
          ScanWorkflowState.processingOcr,
          ScanWorkflowState.processingExtraction,
          ScanWorkflowState.preparingResult,
        }.contains(controller.state);
        final screen = switch (controller.state) {
          ScanWorkflowState.imageSelected => const ImageReviewScreen(),
          ScanWorkflowState.processingOcr ||
          ScanWorkflowState.processingExtraction ||
          ScanWorkflowState.preparingResult => const ProcessingScreen(),
          ScanWorkflowState.awaitingConfirmation => const ConfirmationScreen(),
          ScanWorkflowState.ready => const ResultScreen(),
          ScanWorkflowState.failure => _FailureScreen(controller: controller),
          ScanWorkflowState.idle => const _EmptyFlowScreen(),
        };
        return PopScope(
          canPop: !processing,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) unawaited(controller.newScan());
          },
          child: screen,
        );
      },
    );
  }
}

class _FailureScreen extends StatelessWidget {
  const _FailureScreen({required this.controller});

  final ScanController controller;

  @override
  Widget build(BuildContext context) {
    final error = controller.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Could not complete scan')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null)
                ErrorPanel(
                  error: error,
                  onRetry: error.retryable ? controller.retryProcessing : null,
                ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () async {
                  await controller.newScan();
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Start a new scan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFlowScreen extends StatelessWidget {
  const _EmptyFlowScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MediVoice')),
      body: Center(
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Return home'),
        ),
      ),
    );
  }
}
