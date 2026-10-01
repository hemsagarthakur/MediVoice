import 'package:flutter/foundation.dart';

enum AppErrorCode {
  permission,
  imageDecode,
  ocr,
  emptyOcr,
  network,
  timeout,
  api,
  invalidExtraction,
  translation,
  speech,
  unknown,
}

class AppError implements Exception {
  const AppError({
    required this.code,
    required this.message,
    required this.retryable,
    Object? debugCause,
  }) : debugCause = kDebugMode ? debugCause : null;

  final AppErrorCode code;
  final String message;
  final bool retryable;
  final Object? debugCause;

  factory AppError.unknown(Object cause) => AppError(
    code: AppErrorCode.unknown,
    message: 'Something went wrong. Please retry or start a new scan.',
    retryable: true,
    debugCause: cause,
  );

  @override
  String toString() => 'AppError(${code.name}): $message';
}
