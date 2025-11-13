import 'package:cloud_firestore/cloud_firestore.dart';
import 'local_notifier.dart';

class MedScheduler {
  /// ID base por med para generar IDs únicos por horario.
  static int _baseIdFor(String medId) {
    final h = medId.hashCode & 0x7fffffff;
    return (h % 900000) + 100000; // 100k..999k
  }

  /// Programa todas las notificaciones de una med a partir del doc Firestore.
  static Future<void> scheduleMedFromDoc(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>?; 
    if (data == null) return;

    final enabled  = (data['enabled']  ?? true) as bool;
    final name     = (data['name']     ?? '')   as String;
    final doseMg   = (data['doseMg']   ?? 0)    as int;
    final slot     = (data['slot']     ?? 0)    as int;
    final schedule = (data['schedule'] ?? data['times24h'] as List?)?.cast<String>() ?? const [];

    // Limpia asignaciones previas para esta med
    final base = _baseIdFor(doc.id);
    await LocalNotifier.cancelRange(base, base + 50);

    if (!enabled) return;

    var idx = 0;
    for (final hhmm in schedule) {
      final p = hhmm.split(':');
      if (p.length != 2) continue;
      final h = int.tryParse(p[0]) ?? 0;
      final m = int.tryParse(p[1]) ?? 0;

      await LocalNotifier.scheduleDaily(
        id: base + idx,
        title: 'Hora de tu medicación',
        body: '$name · ${doseMg}mg · Comp $slot',
        hour: h,
        minute: m,
      );
      idx++;
    }
  }

  /// Cancela todas las notificaciones de una med.
  static Future<void> cancelMed(String medId) async {
    final base = _baseIdFor(medId);
    await LocalNotifier.cancelRange(base, base + 50);
  }

  /// Alias para compatibilidad con tu MedsRepository.
  static Future<void> cancelForMed(String medId) => cancelMed(medId);

  /// Reprograma todas las meds del usuario (al iniciar sesión o reabrir app).
  static Future<void> rescheduleAllForUser(String uid) async {
    final q = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('meds').get();
    for (final d in q.docs) {
      await scheduleMedFromDoc(d);
    }
  }
}
