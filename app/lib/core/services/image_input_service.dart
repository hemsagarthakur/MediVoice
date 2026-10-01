import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../errors/app_error.dart';
import '../models/scan_mode.dart';

class PreparedImage {
  const PreparedImage({
    required this.path,
    required this.hasLowResolutionWarning,
  });

  final String path;
  final bool hasLowResolutionWarning;
}

abstract interface class ImageInputService {
  Future<PreparedImage?> select(ImageInputKind kind);

  Future<PreparedImage?> recoverLostImage();
}

class DeviceImageInputService implements ImageInputService {
  DeviceImageInputService({ImagePicker? picker, ImageCropper? cropper})
    : _picker = picker ?? ImagePicker(),
      _cropper = cropper ?? ImageCropper();

  final ImagePicker _picker;
  final ImageCropper _cropper;

  @override
  Future<PreparedImage?> select(ImageInputKind kind) async {
    try {
      final selected = await _picker.pickImage(
        source: kind == ImageInputKind.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 100,
        requestFullMetadata: false,
      );
      if (selected == null) {
        return null;
      }
      return await _cropAndInspect(selected.path);
    } catch (error) {
      throw AppError(
        code: AppErrorCode.permission,
        message: 'Camera or photo access failed. Check permissions and retry.',
        retryable: true,
        debugCause: error,
      );
    }
  }

  @override
  Future<PreparedImage?> recoverLostImage() async {
    try {
      final lost = await _picker.retrieveLostData();
      if (lost.isEmpty || lost.files == null || lost.files!.isEmpty) {
        return null;
      }
      return await _cropAndInspect(lost.files!.first.path);
    } catch (error) {
      throw AppError(
        code: AppErrorCode.imageDecode,
        message: 'The previous image could not be restored. Please scan again.',
        retryable: false,
        debugCause: error,
      );
    }
  }

  Future<PreparedImage?> _cropAndInspect(String sourcePath) async {
    final cropped = await _cropper.cropImage(
      sourcePath: sourcePath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 95,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Prepare medicine image',
          toolbarColor: const Color(0xFF0B6B57),
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
      ],
    );
    if (cropped == null) return null;

    try {
      final bytes = await File(cropped.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final shortestEdge = image.width < image.height
          ? image.width
          : image.height;
      image.dispose();
      codec.dispose();
      return PreparedImage(
        path: cropped.path,
        hasLowResolutionWarning: shortestEdge < 720,
      );
    } catch (error) {
      throw AppError(
        code: AppErrorCode.imageDecode,
        message: 'This image could not be opened. Please choose another image.',
        retryable: false,
        debugCause: error,
      );
    }
  }
}
