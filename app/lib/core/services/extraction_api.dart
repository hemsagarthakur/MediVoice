import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../errors/app_error.dart';
import '../models/medicine_instruction.dart';
import '../models/scan_mode.dart';
import '../models/scan_result.dart';

abstract interface class ExtractionApi {
  Future<ScanResult> extract({
    required ScanMode mode,
    required String sourceText,
  });

  void close();
}

class HttpExtractionApi implements ExtractionApi {
  HttpExtractionApi({required String baseUrl, http.Client? client})
    : _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  @override
  Future<ScanResult> extract({
    required ScanMode mode,
    required String sourceText,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/api/v1/extractions'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'schema_version': '1.0',
              'scan_mode': mode.wireValue,
              'ocr_text': sourceText,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Response is not an object.');
      }

      if (response.statusCode != 200) {
        final error = decoded['error'];
        final message = error is Map<String, dynamic> ? error['message'] : null;
        final retryable = error is Map<String, dynamic>
            ? error['retryable']
            : null;
        throw AppError(
          code: response.statusCode == 429
              ? AppErrorCode.api
              : AppErrorCode.invalidExtraction,
          message: message is String && message.length <= 240 ? message : 'We could not reliably read this image. Please retry or rescan.',
          retryable: retryable is bool ? retryable : true,
        );
      }

      if (decoded['schema_version'] != '1.0') {
        throw const FormatException('Unsupported schema version.');
      }
      final rawMedicines = decoded['medicines'];
      final rawWarnings = decoded['warnings'];
      if (rawMedicines is! List ||
          rawMedicines.isEmpty ||
          rawMedicines.length > 10 ||
          rawWarnings is! List) {
        throw const FormatException('Invalid extraction payload.');
      }
      final medicines = rawMedicines
          .map((value) {
            if (value is! Map<String, dynamic>) {
              throw const FormatException('Invalid medicine item.');
            }
            return MedicineInstruction.fromJson(value);
          })
          .toList(growable: false);
      final warnings = rawWarnings
          .map((value) {
            if (value is! String) {
              throw const FormatException('Invalid extraction warning.');
            }
            return value;
          })
          .toList(growable: false);

      return ScanResult(
        mode: mode,
        sourceText: sourceText,
        medicines: medicines,
        warnings: warnings,
        requestId: decoded['request_id'] is String
            ? decoded['request_id'] as String
            : null,
      );
    } on AppError {
      rethrow;
    } on TimeoutException catch (error) {
      throw AppError(
        code: AppErrorCode.timeout,
        message: 'The extraction service timed out. Please retry.',
        retryable: true,
        debugCause: error,
      );
    } on SocketException catch (error) {
      throw AppError(
        code: AppErrorCode.network,
        message: 'No network connection. Reconnect and retry.',
        retryable: true,
        debugCause: error,
      );
    } on FormatException catch (error) {
      throw AppError(
        code: AppErrorCode.invalidExtraction,
        message: 'We could not reliably read this prescription. Please retry or rescan.',
        retryable: true,
        debugCause: error,
      );
    } catch (error) {
      throw AppError(
        code: AppErrorCode.network,
        message: 'The extraction service could not be reached. Please retry.',
        retryable: true,
        debugCause: error,
      );
    }
  }

  @override
  void close() => _client.close();
}
