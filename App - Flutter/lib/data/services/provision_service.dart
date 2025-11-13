import 'dart:convert';
import 'package:http/http.dart' as http;

class ProvisionService {
  /// Envía credenciales de Wi-Fi (y opcionales de Firebase) al ESP32 en modo AP.
  /// - espIp: normalmente 192.168.4.1 mientras el ESP32 está en SoftAP.
  /// - wifiSsid / wifiPass: red del hogar (del QR).
  /// - firebaseProjectId/apiKey/authEmail/authPassword/ownerUID: OPCIONALES.
  static Future<void> provisionDispenser({
    String espIp = '192.168.4.1',
    required String wifiSsid,
    required String wifiPass,
    String? firebaseProjectId,
    String? firebaseApiKey,
    String? authEmail,
    String? authPassword,
    String? ownerUID,
  }) async {
    final uri = Uri.parse('http://$espIp/provision');

    // Armamos el JSON y solo incluimos campos no nulos/ni vacíos
    final Map<String, dynamic> body = {
      'wifiSsid': wifiSsid,
      'wifiPass': wifiPass,
    };

    void putIfNotEmpty(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        body[key] = value.trim();
      }
    }

    putIfNotEmpty('projectId', firebaseProjectId);
    putIfNotEmpty('apiKey', firebaseApiKey);
    putIfNotEmpty('authEmail', authEmail);
    putIfNotEmpty('authPassword', authPassword);
    putIfNotEmpty('ownerUID', ownerUID);

    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));

    if (resp.statusCode != 200) {
      throw Exception('Error de provisión: ${resp.statusCode} ${resp.body}');
    }
  }
}
