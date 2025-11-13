// lib/screens/SubScreens/historial_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pillbox/core/colores.dart';
import 'package:pillbox/data/models/regimen_draft.dart';
import 'package:pillbox/data/services/meds_repository.dart';
import 'package:pillbox/app.dart' show AppRoutes;

class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RegimenDraft>>(
      stream: MedsRepository.instance.watchAll(),
      builder: (context, snap) {
        final items = snap.data ?? const <RegimenDraft>[];

        return Scaffold(
          backgroundColor: AppColors.prueba1,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.secundario),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Medicamentos asignados',
              style: TextStyle(color: AppColors.secundario),
            ),
            centerTitle: false,
          ),
          body: Container(
            decoration: const BoxDecoration(
              color: AppColors.prueba2,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: snap.connectionState == ConnectionState.waiting
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primario),
                  )
                : snap.hasError
                    ? _ErrorState(
                        message:
                            'No se pudo cargar el historial.\n${snap.error}',
                      )
                    : items.isEmpty
                        ? _EmptyState(
                            onAdd: () =>
                                Navigator.pushNamed(context, AppRoutes.medsName),
                          )
                        : ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) => _MedCard(
                              draft: items[i],
                              onEdit: () async {
                                final updated = await showModalBottomSheet<
                                    RegimenDraft?>(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) =>
                                      EditMedSheet(initial: items[i]),
                                );
                                if (updated != null) {
                                  try {
                                    await MedsRepository.instance
                                        .saveDraft(updated);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Medicamento actualizado')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Error al actualizar: $e')),
                                      );
                                    }
                                  }
                                }
                              },
                              onDelete: () async {
                                final ok = await _confirmDelete(
                                  context,
                                  items[i].name ?? 'esta pastilla',
                                );
                                if (ok != true) return;

                                final id = items[i].id;
                                if (id == null) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'No se puede eliminar: id inexistente')),
                                    );
                                  }
                                  return;
                                }
                                try {
                                  await MedsRepository.instance.delete(id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Medicamento eliminado')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('Error al eliminar: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
          ),

          // ✅ FAB solo visible si hay medicamentos
          floatingActionButton: (items.isNotEmpty)
              ? FloatingActionButton.extended(
                  backgroundColor: AppColors.botones,
                  icon: const Icon(Icons.add, color: AppColors.secundario),
                  label: const Text(
                    'Agregar',
                    style: TextStyle(color: AppColors.secundario),
                  ),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.medsName),
                )
              : null,
        );
      },
    );
  }
}

/// Estado vacío
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.medication_outlined,
                size: 72, color: AppColors.terciario),
            const SizedBox(height: 12),
            const Text(
              'No tienes ningún medicamento asignado.\nAgrega uno',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.secundario, fontSize: 18, height: 1.3),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: w * 0.7,
              height: 48,
              child: ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.botones),
                onPressed: onAdd,
                child: const Text(
                  'Agregar medicamento',
                  style: TextStyle(
                    color: AppColors.secundario,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado error
class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }
}

/// Tarjeta con Editar + Eliminar
class _MedCard extends StatelessWidget {
  final RegimenDraft draft;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _MedCard({
    required this.draft,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = draft.name ?? 'Sin nombre';
    final typeLabel = _typeToLabel(draft.type);
    final doses = draft.dosesPerDay ??
        (draft.times24h.isNotEmpty ? draft.times24h.length : null);
    final times = draft.times24h;
    final hasWeekdays = draft.weekdays.isNotEmpty;

    return Material(
      color: AppColors.prueba2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primario.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.medication, color: AppColors.secundario),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.secundario,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (typeLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primario.withOpacity(.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primario.withOpacity(.35)),
                      ),
                      child: Text(
                        typeLabel,
                        style: const TextStyle(
                          color: AppColors.secundario,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: onEdit,
                    icon:
                        const Icon(Icons.edit, color: AppColors.secundario),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    onPressed: onDelete,
                    icon:
                        const Icon(Icons.delete, color: Colors.redAccent),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (doses != null)
                Row(
                  children: [
                    const Icon(Icons.local_hospital_outlined,
                        size: 18, color: AppColors.terciario),
                    const SizedBox(width: 6),
                    Text(
                      '$doses dosis por día',
                      style: const TextStyle(color: AppColors.secundario),
                    ),
                  ],
                ),
              if (hasWeekdays) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: -6,
                  children: draft.weekdays
                      .map(
                        (d) => Chip(
                          label: Text(d),
                          backgroundColor: AppColors.prueba1,
                          labelStyle:
                              const TextStyle(color: AppColors.secundario),
                          side: BorderSide.none,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
                ),
              ],
              if (times.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.access_time,
                        size: 18, color: AppColors.terciario),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        times.join('  ·  '),
                        style:
                            const TextStyle(color: AppColors.secundario),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _typeToLabel(ScheduleType? t) {
    switch (t) {
      case ScheduleType.everyDay:
        return 'Cada día';
      case ScheduleType.everyOtherDay:
        return 'Día por medio';
      case ScheduleType.specificWeekdays:
        return 'Días específicos';
      case ScheduleType.once:
        return 'Una vez';
      default:
        return null;
    }
  }
}

/// Confirmación de borrado
Future<bool?> _confirmDelete(BuildContext context, String nombre) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.prueba2,
      title: const Text('Eliminar',
          style: TextStyle(color: AppColors.secundario)),
      content: Text(
        '¿Seguro que querés eliminar "$nombre"?',
        style: const TextStyle(color: AppColors.secundario),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar',
              style: TextStyle(color: AppColors.secundario)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.pop(ctx, true),
          child:
              const Text('Eliminar', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

/// Hoja inferior de edición
class EditMedSheet extends StatefulWidget {
  final RegimenDraft initial;
  const EditMedSheet({super.key, required this.initial});

  @override
  State<EditMedSheet> createState() => _EditMedSheetState();
}

class _EditMedSheetState extends State<EditMedSheet> {
  late TextEditingController _nameCtrl;
  int _doses = 1;
  late List<DateTime> _times;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial.name ?? '');
    final initialDoses = widget.initial.dosesPerDay ??
        (widget.initial.times24h.isNotEmpty
            ? widget.initial.times24h.length
            : 1);
    _doses = initialDoses.clamp(1, 4);
    final parsed = widget.initial.times24h
        .map(_parseHHmmToday)
        .whereType<DateTime>()
        .toList();
    if (parsed.length >= _doses) {
      _times = parsed.take(_doses).toList();
    } else {
      _times = [
        ...parsed,
        ..._defaultTimesForCount(_doses).skip(parsed.length),
      ];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  List<DateTime> _defaultTimesForCount(int n) {
    final now = DateTime.now();
    DateTime at(int h, int m) => DateTime(now.year, now.month, now.day, h, m);
    switch (n) {
      case 1:
        return [at(8, 0)];
      case 2:
        return [at(8, 0), at(20, 0)];
      case 3:
        return [at(8, 0), at(14, 0), at(20, 0)];
      default:
        return [at(8, 0), at(12, 0), at(16, 0), at(20, 0)];
    }
  }

  DateTime? _parseHHmmToday(String s) {
    final re = RegExp(r'^(\d{2}):(\d{2})$');
    final m = re.firstMatch(s.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final mm = int.parse(m.group(2)!);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, h, mm);
  }

  String _toHHmm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _decDoses() {
    if (_doses <= 1) return;
    setState(() {
      _doses--;
      _times = _times.take(_doses).toList();
    });
  }

  void _incDoses() {
    if (_doses >= 4) return;
    setState(() {
      _doses++;
      final defaultTimes = _defaultTimesForCount(_doses);
      if (_times.length < _doses) {
        _times = [..._times, defaultTimes[_times.length]];
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) {
        throw Exception('El nombre no puede estar vacío.');
      }
      final updated = widget.initial.copyWith(
        name: name,
        dosesPerDay: _doses,
        times24h: _times.map(_toHHmm).toList(),
        updatedAt: DateTime.now(),
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final h = media.size.height * 0.85;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        height: h,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16 + 8),
        decoration: const BoxDecoration(
          color: AppColors.prueba2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: ListView(
          controller: controller,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.terciario,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Text(
              'Editar medicamento',
              style: TextStyle(
                color: AppColors.secundario,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'Nombre',
              child: TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: AppColors.secundario),
                decoration: _inputDecoration(),
              ),
            ),
            _LabeledField(
              label: 'Dosis por día (máx. 4)',
              child: Row(
                children: [
                  IconButton(
                    onPressed: _doses > 1 ? _decDoses : null,
                    icon:
                        const Icon(Icons.remove, color: AppColors.secundario),
                  ),
                  Text(
                    '$_doses',
                    style: const TextStyle(
                      color: AppColors.secundario,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: _doses < 4 ? _incDoses : null,
                    icon: const Icon(Icons.add, color: AppColors.secundario),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(_doses, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.prueba1,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primario.withOpacity(.3)),
                  ),
                  height: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: Text(
                          'Horario ${i + 1}',
                          style: const TextStyle(
                            color: AppColors.secundario,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: CupertinoTheme(
                          data: const CupertinoThemeData(
                            textTheme: CupertinoTextThemeData(
                              dateTimePickerTextStyle: TextStyle(
                                color: AppColors.secundario, // 👈 cambia solo el color del texto
                              ),
                            ),
                          ),
                          child: CupertinoDatePicker(
                            mode: CupertinoDatePickerMode.time,
                            use24hFormat: true,
                            initialDateTime: _times[i],
                            onDateTimeChanged: (dt) {
                              setState(() => _times[i] = dt);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.botones),
                child: Text(
                  _saving ? 'Guardando…' : 'Guardar cambios',
                  style: const TextStyle(
                    color: AppColors.secundario,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.prueba1,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(color: AppColors.primario, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(color: AppColors.primario, width: 2),
      ),
      hintStyle: const TextStyle(color: AppColors.terciario),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.secundario,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
