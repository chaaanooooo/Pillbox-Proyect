import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wifi_iot/wifi_iot.dart';

import 'package:pillbox/data/services/provision_service.dart';

class ClaimQrPage extends StatefulWidget {
  const ClaimQrPage({super.key});

  @override
  State<ClaimQrPage> createState() => _ClaimQrPageState();
}

class _ClaimQrPageState extends State<ClaimQrPage> {
  bool _processing = false;

  // Config del AP del ESP32 (SoftAP)
  static const String _apSsid = 'Pillbox-Setup';
  static const String _apPass = 'pillbox1234';
  static const String _espIp  = '192.168.4.1';

  Future<void> _claim(String deviceId, String claimCode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw 'Sesión no iniciada';
    }

    final uid = user.uid;
    final ref = FirebaseFirestore.instance.collection('devices').doc(deviceId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw 'El dispositivo no existe';
      }

      final data = snap.data() as Map<String, dynamic>;
      final storedCode   = (data['claimCode'] ?? '').toString();
      final currentOwner = (data['ownerUID'] ?? '').toString();

      if (storedCode != claimCode) {
        throw 'QR inválido (código no coincide)';
      }
      if (currentOwner.isNotEmpty && currentOwner != uid) {
        throw 'Este PillBox ya está vinculado a otro usuario';
      }

      tx.update(ref, {
        'ownerUID': uid,
        // Si preferís limpiar el claimCode luego de reclamar:
        // 'claimCode': FieldValue.delete(),
      });
    });
  }

  Future<bool> _connectToPillboxAP() async {
    // En Android requiere permisos de ubicación activos.
    try {
      final ok = await WiFiForIoTPlugin.connect(
        _apSsid,
        password: _apPass,
        security: NetworkSecurity.WPA,
        joinOnce: true,
        withInternet: false, // AP local sin internet
      );
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleScan(String raw) async {
    if (_processing) return;
    _processing = true;

    String title;
    String message;

    // Posibles extras del QR: wifi { ssid, password } y opcionales de Firebase
    String? wifiSsidCasa;
    String? wifiPassCasa;
    String? firebaseProjectId;
    String? firebaseApiKey;

    try {
      // 1) Parsear QR
      final data = json.decode(raw) as Map<String, dynamic>;
      final deviceId  = (data['deviceId']  ?? '').toString();
      final claimCode = (data['claimCode'] ?? '').toString();

      if (deviceId.isEmpty || claimCode.isEmpty) {
        throw 'QR inválido (faltan campos)';
      }

      // Leer Wi-Fi de la casa desde el QR (si viene)
      if (data['wifi'] is Map) {
        final w = data['wifi'] as Map;
        wifiSsidCasa = (w['ssid'] ?? '').toString();
        wifiPassCasa = (w['password'] ?? '').toString();
      }
      // Opcionales de Firebase en el QR (si querés)
      firebaseProjectId = (data['projectId'] ?? '').toString();
      firebaseApiKey    = (data['apiKey']    ?? '').toString();

      if (wifiSsidCasa == null || wifiSsidCasa.isEmpty) {
        throw 'QR sin SSID de la red de casa';
      }
      wifiPassCasa ??= ''; // puede ser vacía (red abierta o mal QR)

      // 2) Reclamar el dispositivo en Firestore
      await _claim(deviceId, claimCode);

      // 3) Conectarse automáticamente al AP del ESP32
      //    Mostramos un modal de progreso para que el usuario vea feedback
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ProgressDialog(texto: 'Conectando al PillBox...'),
      );
      final apOk = await _connectToPillboxAP();
      if (mounted) Navigator.of(context).pop(); // cerrar progress

      if (!apOk) {
        throw 'No se pudo conectar al AP $_apSsid';
      }

      // 4) Enviar credenciales de la casa al ESP32
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ProgressDialog(texto: 'Enviando Wi-Fi al PillBox...'),
      );

      final user = FirebaseAuth.instance.currentUser;
      final ownerUid = user?.uid;
      final authEmail = user?.email; // si querés pasarlo, es opcional

      await ProvisionService.provisionDispenser(
        espIp: _espIp,
        wifiSsid: wifiSsidCasa,
        wifiPass: wifiPassCasa,

        firebaseProjectId: firebaseProjectId.isEmpty ? null : firebaseProjectId,
        firebaseApiKey:    firebaseApiKey.isEmpty    ? null : firebaseApiKey,
        authEmail:   (authEmail?.isEmpty ?? true) ? null : authEmail,
        authPassword: null, 
        ownerUID:    (ownerUid?.isEmpty ?? true) ? null : ownerUid,
      );


      if (mounted) Navigator.of(context).pop(); // cerrar progress

      title = 'PillBox configurado';
      message = '✅ Se vinculó y se enviaron las credenciales de Wi-Fi con éxito.';
    } catch (e) {
      title = 'Error al configurar';
      message = 'Error: $e';
    }

    if (!mounted) return;

    // Diálogo final SIEMPRE (éxito o error)
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    // Volver a la pantalla anterior
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vincular y Configurar PillBox'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final code = capture.barcodes.first.rawValue;
              if (code == null) return;
              _handleScan(code);
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Apuntá la cámara al QR del PillBox',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog de progreso simple
class _ProgressDialog extends StatelessWidget {
  final String texto;
  const _ProgressDialog({required this.texto});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}
