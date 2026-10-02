import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medivoice/core/models/medicine_instruction.dart';
import 'package:medivoice/core/services/medicine_reference_api.dart';

void main() {
  test(
    'sends only medicine identity and parses trusted reference data',
    () async {
      late Map<String, dynamic> requestBody;
      final client = MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          '''{"schema_version":"1.0","request_id":"r1","references":[{"requested_name":"Paracetamol","canonical_name":"acetaminophen","rx_cui":"161","commonly_used_for":["reducing fever"],"common_side_effects":[],"important_caution":"Do not exceed the recommended amount","source":"dailymed","source_reference":"https://dailymed.example/label","match_quality":"exact","available":true}]}''',
          200,
        );
      });
      final api = HttpMedicineReferenceApi(
        baseUrl: 'https://example.test',
        client: client,
      );
      final result = await api.lookup(const [
        MedicineInstruction(
          medicineName: 'Paracetamol',
          strength: '500 mg',
          dose: '1 tablet',
          frequency: 'Twice daily',
        ),
      ]);

      expect(result.single.available, isTrue);
      expect(result.single.commonlyUsedFor, ['reducing fever']);
      expect(requestBody, {
        'schema_version': '1.0',
        'medicines': [
          {'medicine_name': 'Paracetamol', 'name_uncertain': false},
        ],
      });
      expect(requestBody.toString(), isNot(contains('500 mg')));
      expect(requestBody.toString(), isNot(contains('Twice daily')));
    },
  );

  test('source failure returns unavailable data without blocking', () async {
    final api = HttpMedicineReferenceApi(
      baseUrl: 'https://example.test',
      client: MockClient((_) async => throw const SocketException('offline')),
    );
    final result = await api.lookup(const [
      MedicineInstruction(medicineName: 'Paracetamol'),
    ]);
    expect(result.single.available, isFalse);
  });

  test(
    'uncertain identity is explicitly marked for safe backend handling',
    () async {
      late Map<String, dynamic> requestBody;
      final api = HttpMedicineReferenceApi(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requestBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            '''{"schema_version":"1.0","request_id":"r1","references":[{"requested_name":"UnclearName","canonical_name":null,"rx_cui":null,"commonly_used_for":[],"common_side_effects":[],"important_caution":null,"source":null,"source_reference":null,"match_quality":"ambiguous","available":false}]}''',
            200,
          );
        }),
      );
      await api.lookup(const [
        MedicineInstruction(
          medicineName: 'UnclearName',
          uncertainFields: {MedicineField.medicineName},
        ),
      ]);
      final medicines = requestBody['medicines'] as List;
      expect((medicines.single as Map)['name_uncertain'], isTrue);
    },
  );
}
