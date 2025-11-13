// lib/notificaciones/alarm_planificador.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'alarm_notifier.dart';

class AlarmScheduler {
  /// ID base por med para generar IDs únicos por horario.
  static int _baseIdFor(String medId) {
    final h = medId.hashCode & 0x7fffffff;
    return (h % 900000) + 100000; // 100k..999k
  }

  /// Programa todas las alarmas de una med a partir del doc Firestore.
  static Future<void> scheduleMedFromDoc(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final enabled = (data['enabled'] ?? true) as bool;
    final name = (data['name'] ?? '') as String;
    final schedule =
        (data['schedule'] ?? data['times24h'] as List?)?.cast<String>() ?? const [];

    // Limpia asignaciones previas para esta med
    final base = _baseIdFor(doc.id);
    await AlarmNotifier.cancelRange(base, base + 50);

    // 🔥 Espera breve para asegurar que Android procese las cancelaciones
    await Future.delayed(const Duration(milliseconds: 200));

    if (!enabled) return;

    var idx = 0;
    for (final hhmm in schedule) {
      final p = hhmm.split(':');
      if (p.length != 2) continue;
      final h = int.tryParse(p[0]) ?? 0;
      final m = int.tryParse(p[1]) ?? 0;

      // ✅ Personalizamos título y cuerpo
      await AlarmNotifier.scheduleDaily(
        id: base + idx,
        title: 'Hora de tomar tu $name',
        body: 'Dosis: ${idx + 1}/${schedule.length}',
        hour: h,
        minute: m,
      );
      idx++;
    }
  }

  /// Cancela todas las alarmas de una med.
  static Future<void> cancelMed(String medId) async {
    final base = _baseIdFor(medId);
    await AlarmNotifier.cancelRange(base, base + 50);
  }

  /// Alias para compatibilidad con tu MedsRepository.
  static Future<void> cancelForMed(String medId) => cancelMed(medId);

  /// Reprograma todas las meds del usuario (al iniciar sesión o reabrir app).
  static Future<void> rescheduleAllForUser(String uid) async {
    final q = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('meds')
        .get();
    for (final d in q.docs) {
      await scheduleMedFromDoc(d);
    }
  }
}
