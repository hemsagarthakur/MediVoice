import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/medicine_instruction.dart';
import '../models/medicine_reference.dart';

abstract interface class MedicineReferenceApi {
  Future<List<MedicineReference>> lookup(List<MedicineInstruction> medicines);

  void close();
}

class HttpMedicineReferenceApi implements MedicineReferenceApi {
  HttpMedicineReferenceApi({required String baseUrl, http.Client? client})
    : _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  @override
  Future<List<MedicineReference>> lookup(
    List<MedicineInstruction> medicines,
  ) async {
    final eligible = medicines
        .where((medicine) => medicine.medicineName != null)
        .toList(growable: false);
    if (eligible.isEmpty) return const [];
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/api/v1/medicine-references'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'schema_version': '1.0',
              'medicines': [
                for (final medicine in eligible)
                  {
                    'medicine_name': medicine.medicineName,
                    'name_uncertain': medicine.uncertainFields.contains(
                      MedicineField.medicineName,
                    ),
                  },
              ],
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw const HttpException('Reference lookup failed.');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> || decoded['references'] is! List) {
        throw const FormatException('Invalid reference response.');
      }
      final values = (decoded['references'] as List)
          .map((value) {
            if (value is! Map<String, dynamic>) {
              throw const FormatException('Invalid reference item.');
            }
            return MedicineReference.fromJson(value);
          })
          .toList(growable: false);
      if (values.length != eligible.length) {
        throw const FormatException('Reference count mismatch.');
      }
      return values;
    } catch (_) {
      return [
        for (final medicine in eligible)
          MedicineReference.unavailable(
            medicine.medicineName!,
            uncertain: medicine.uncertainFields.contains(
              MedicineField.medicineName,
            ),
          ),
      ];
    }
  }

  @override
  void close() => _client.close();
}
