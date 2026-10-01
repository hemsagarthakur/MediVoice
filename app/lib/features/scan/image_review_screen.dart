import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/scan_mode.dart';
import '../../shared/widgets/primary_action_button.dart';
import 'scan_controller.dart';

class ImageReviewScreen extends StatelessWidget {
  const ImageReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScanController>();
    final image = controller.image;
    return Scaffold(
      appBar: AppBar(
        title: Text('Review ${controller.mode?.label ?? 'image'}'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(image.path),
                  height: 380,
                  fit: BoxFit.contain,
                  semanticLabel: 'Selected medicine image',
                ),
              ),
            if (image?.hasLowResolutionWarning ?? false) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This image is low resolution. A closer, well-lit photo may be easier to read.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            PrimaryActionButton(
              label: 'Use this image',
              icon: Icons.check_circle_outline,
              onPressed: controller.processImage,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => controller.retake(ImageInputKind.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Retake photo'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                await controller.newScan();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Cancel scan'),
            ),
          ],
        ),
      ),
    );
  }
}
