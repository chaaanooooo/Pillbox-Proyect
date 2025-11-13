import 'package:cloud_firestore/cloud_firestore.dart';

enum ScheduleType {
  once,          // Solo una vez
  everyDay,      // Cada día (n dosis/día, times[])
  everyOtherDay, // Día por medio (startDate + times[])
  specificWeekdays, // Días específicos (weekdays[] + times[])
}

class RegimenDraft {
  final String? id;            // null = crear
  final String? name;          // nombre medicamento
  final ScheduleType? type;
  final DateTime? startDate;   // para Día por medio (fecha base) o “Solo una vez”
  final int? dosesPerDay;      // 1..N
  final List<String> weekdays; // ['Lun','Mié','Vie'] si aplica
  final List<String> times24h; // ['08:30','21:00'] (formato 24h)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RegimenDraft({
    this.id,
    this.name,
    this.type,
    this.startDate,
    this.dosesPerDay,
    this.weekdays = const [],
    this.times24h = const [],
    this.createdAt,
    this.updatedAt,
  });

  RegimenDraft copyWith({
    String? id,
    String? name,
    ScheduleType? type,
    DateTime? startDate,
    int? dosesPerDay,
    List<String>? weekdays,
    List<String>? times24h,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RegimenDraft(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      dosesPerDay: dosesPerDay ?? this.dosesPerDay,
      weekdays: weekdays ?? this.weekdays,
      times24h: times24h ?? this.times24h,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type?.name,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'dosesPerDay': dosesPerDay,
      'weekdays': weekdays,
      'times24h': times24h,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  static RegimenDraft fromDoc(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return RegimenDraft(
      id: doc.id,
      name: data['name'] as String?,
      type: _typeFromName(data['type'] as String?),
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      dosesPerDay: data['dosesPerDay'] as int?,
      weekdays: List<String>.from(data['weekdays'] ?? const []),
      times24h: List<String>.from(data['times24h'] ?? const []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  static ScheduleType? _typeFromName(String? n) {
    if (n == null) return null;
    return ScheduleType.values.firstWhere((e) => e.name == n, orElse: () => ScheduleType.once);
  }
}
