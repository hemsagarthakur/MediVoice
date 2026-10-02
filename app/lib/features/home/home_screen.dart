import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/scan_mode.dart';
import '../../shared/widgets/disclaimer_banner.dart';
import '../../shared/widgets/primary_action_button.dart';
import '../scan/capture_screen.dart';
import '../scan/scan_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLostImage());
  }

  Future<ScanMode?> _chooseMode({required String title}) =>
      showModalBottomSheet<ScanMode>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pop(sheetContext, ScanMode.prescription),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Prescription'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pop(sheetContext, ScanMode.medicineStrip),
                  icon: const Icon(Icons.medication_outlined),
                  label: const Text('Medicine strip'),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _recoverLostImage() async {
    final controller = context.read<ScanController>();
    final recovered = await controller.recoverLostImage();
    if (!mounted) return;
    if (!recovered) {
      final error = controller.error;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
        controller.clearError();
      }
      return;
    }

    final mode = await _chooseMode(title: 'Recovered image: what type is it?');
    if (!mounted) return;
    if (mode == null) {
      await controller.newScan();
      return;
    }
    controller.setRecoveredImageMode(mode);
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const CaptureScreen()));
  }

  Future<void> _start(
    BuildContext context,
    ScanMode mode,
    ImageInputKind kind,
  ) async {
    final controller = context.read<ScanController>();
    final selected = await controller.selectImage(mode, kind);
    if (!context.mounted) return;
    if (selected) {
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const CaptureScreen()));
      return;
    }
    final error = controller.error;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
      controller.clearError();
    }
  }

  Future<void> _upload(BuildContext context) async {
    final mode = await _chooseMode(title: 'What type of image is this?');
    if (mode != null && context.mounted) {
      await _start(context, mode, ImageInputKind.gallery);
    }
  }

  Future<void> _startDemo(BuildContext context) async {
    final controller = context.read<ScanController>();
    unawaited(controller.startSyntheticDemo());
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const CaptureScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MediVoice')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Understand your medicine instructions',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Take a clear photo or choose an existing image. You will review every detail before translation or audio.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (context.watch<ScanController>().demoMode) ...[
              const SizedBox(height: 20),
              Semantics(
                button: true,
                label: 'Start synthetic prescription demo',
                child: OutlinedButton.icon(
                  onPressed: () => _startDemo(context),
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Try synthetic demo'),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Demo mode uses bundled synthetic OCR text and deterministic backend data. It does not call Groq.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 28),
            PrimaryActionButton(
              label: 'Scan prescription',
              icon: Icons.document_scanner_outlined,
              onPressed: () =>
                  _start(context, ScanMode.prescription, ImageInputKind.camera),
            ),
            const SizedBox(height: 14),
            PrimaryActionButton(
              label: 'Scan medicine strip',
              icon: Icons.medication_outlined,
              onPressed: () => _start(
                context,
                ScanMode.medicineStrip,
                ImageInputKind.camera,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _upload(context),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Upload image'),
            ),
            const SizedBox(height: 28),
            const DisclaimerBanner(),
            const SizedBox(height: 16),
            Text(
              context.watch<ScanController>().demoMode
                  ? 'Privacy: the photo stays on this device. In demo mode, extracted text is sent only to the local mock backend and is not saved.'
                  : 'Privacy: the photo stays on this device. Extracted text is sent to Groq for structured processing and is not saved by MediVoice.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
