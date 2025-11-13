// lib/services/pillbox_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PillboxService {
  static final _db = FirebaseFirestore.instance;

  /// Desvincula un dispositivo si pertenece al usuario actual
  static Future<void> unclaimDevice(String deviceId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'Sesión no iniciada';

    final ref = _db.collection('devices').doc(deviceId);
    final doc = await ref.get();

    if (!doc.exists) throw 'Dispositivo no encontrado';

    final data = doc.data()!;
    final currentOwner = data['ownerUID'] ?? '';

    if (currentOwner != user.uid) throw 'No sos el dueño de este PillBox';

    await ref.update({'ownerUID': ''});
  }
}
