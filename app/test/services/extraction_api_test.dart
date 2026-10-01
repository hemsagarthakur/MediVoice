import 'package:flutter_test/flutter_test.dart';

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medivoice/core/errors/app_error.dart';
import 'package:medivoice/core/models/scan_mode.dart';
import 'package:medivoice/core/services/extraction_api.dart';

void main() {
  test('parses a valid multi-medicine response', () async {
    final client = MockClient(
      (request) async => http.Response(
        '''{"schema_version":"1.0","request_id":"r1","medicines":[{"medicine_name":"A","strength":null,"dose":null,"frequency":null,"timing":null,"duration":null,"food_instruction":null,"route":null,"additional_instruction":null,"uncertain_fields":[],"warnings":[]},{"medicine_name":"B","strength":"5 mg","dose":null,"frequency":null,"timing":null,"duration":null,"food_instruction":null,"route":null,"additional_instruction":null,"uncertain_fields":[],"warnings":[]}],"warnings":[]}''',
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    final api = HttpExtractionApi(
      baseUrl: 'https://example.test',
      client: client,
    );

    final result = await api.extract(
      mode: ScanMode.prescription,
      sourceText: 'Synthetic medicine text',
    );

    expect(result.medicines, hasLength(2));
    expect(result.requestId, 'r1');
  });

  test('malformed success fails closed', () async {
    final client = MockClient((request) async => http.Response('{}', 200));
    final api = HttpExtractionApi(
      baseUrl: 'https://example.test',
      client: client,
    );

    expect(
      api.extract(
        mode: ScanMode.prescription,
        sourceText: 'Synthetic medicine text',
      ),
      throwsA(
        isA<AppError>().having(
          (error) => error.code,
          'code',
          AppErrorCode.invalidExtraction,
        ),
      ),
    );
  });

  test('network failure becomes a retryable network error', () async {
    final client = MockClient((request) async {
      throw const SocketException('offline');
    });
    final api = HttpExtractionApi(
      baseUrl: 'https://example.test',
      client: client,
    );

    expect(
      api.extract(
        mode: ScanMode.prescription,
        sourceText: 'Synthetic medicine text',
      ),
      throwsA(
        isA<AppError>()
            .having((error) => error.code, 'code', AppErrorCode.network)
            .having((error) => error.retryable, 'retryable', isTrue),
      ),
    );
  });
}
