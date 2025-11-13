// lib/data/services/meds_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/regimen_draft.dart';
import 'package:pillbox/notificaciones/planificador.dart'; // <-- importa tu MedScheduler

class MedsRepository {
  MedsRepository._();
  static final MedsRepository instance = MedsRepository._();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _medsCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('meds');

  Future<String> saveDraft(RegimenDraft draft) async {
    final uid = _auth.currentUser!.uid;
    final now = DateTime.now();
    final payload = draft.copyWith(
      createdAt: draft.createdAt ?? now,
      updatedAt: now,
    ).toJson();

    String id;
    if (draft.id == null) {
      final ref = await _medsCol(uid).add(payload);
      id = ref.id;
    } else {
      await _medsCol(uid).doc(draft.id).set(payload, SetOptions(merge: true));
      id = draft.id!;
    }

    // 🔔 Programar notificaciones al guardar/actualizar
    final doc = await _medsCol(uid).doc(id).get();
    await MedScheduler.scheduleMedFromDoc(doc);

    return id;
  }

  Future<void> delete(String medId) async {
    final uid = _auth.currentUser!.uid;
    await _medsCol(uid).doc(medId).delete();
    // ❌ Cancelar notificaciones de esa med
    await MedScheduler.cancelMed(medId);
  }

  Stream<List<RegimenDraft>> watchAll() {
    final uid = _auth.currentUser!.uid;
    return _medsCol(uid).orderBy('createdAt', descending: true).snapshots().map(
      (snap) => snap.docs.map(RegimenDraft.fromDoc).toList(),
    );
  }
}
