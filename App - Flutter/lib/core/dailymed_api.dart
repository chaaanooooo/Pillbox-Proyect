// lib/core/dailymed_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class DailyMedApi {
  static const _base = 'https://dailymed.nlm.nih.gov/dailymed/services/v2';

  /// Devuelve nombres que contienen el texto buscado.
  static Future<List<String>> fetchDrugNames(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];

    final uri = Uri.parse('$_base/drugnames.json').replace(queryParameters: {
      'drug_name': q,
      'name_type': 'both', // genérico y marca
      'pagesize': '20',
      'page': '1',
    });

    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) return [];

    final data = json.decode(res.body);
    final list = (data['data'] ?? data['drugnames'] ?? []) as List;

    return list.map((e) {
      if (e is Map && e['name'] != null) return e['name'].toString();
      return e.toString();
    }).toList(growable: false);
  }
}