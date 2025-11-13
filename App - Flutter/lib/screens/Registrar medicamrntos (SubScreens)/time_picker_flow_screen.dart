// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pillbox/core/colores.dart';
import 'pantalla_base.dart';
import 'package:pillbox/data/models/regimen_draft.dart';
import 'package:pillbox/data/services/meds_repository.dart';
import 'package:pillbox/app.dart';

// Helper para convertir DateTime a formato HH:mm
String dtTo24h(DateTime dt) {
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class TimePickerFlowScreen extends StatefulWidget {
  final String titulo;
  final int remaining;
  final List<DateTime> collectedTimes;
  final RegimenDraft draft;

  const TimePickerFlowScreen({
    super.key,
    required this.titulo,
    required this.remaining,
    required this.collectedTimes,
    required this.draft,
  });

  @override
  State<TimePickerFlowScreen> createState() => _TimePickerFlowScreenState();
}

class _TimePickerFlowScreenState extends State<TimePickerFlowScreen> {
  DateTime _selected = DateTime.now();
  bool _saving = false; // evita taps dobles

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final int total = widget.draft.dosesPerDay ??
        (widget.collectedTimes.length + widget.remaining);

    return PantallaBase(
      titulo: widget.titulo,
      icono: Icons.access_time,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Container(
                  width: size.width * 0.9,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.prueba2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  height: size.height * 0.35,

                  // 🔧 CupertinoTheme para forzar texto blanco y fondo transparente
                  child: CupertinoTheme(
                    data: const CupertinoThemeData(
                      brightness: Brightness.dark, // texto claro
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(
                          color: AppColors.secundario, // blanco
                          fontSize: 18,
                        ),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      backgroundColor: Colors.transparent, // evita fondo negro
                      mode: CupertinoDatePickerMode.time,
                      use24hFormat: true,
                      initialDateTime: _selected,
                      onDateTimeChanged: (dt) => _selected = dt,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: size.width * 0.85,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.prueba1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: _saving
                    ? null
                    : () async {
                        final updatedTimes = [...widget.collectedTimes, _selected];

                        // Si aún faltan horarios, seguir el flujo
                        if (widget.remaining > 1) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TimePickerFlowScreen(
                                titulo:
                                    'Horario ${updatedTimes.length + 1} de $total',
                                remaining: widget.remaining - 1,
                                collectedTimes: updatedTimes,
                                draft: widget.draft.copyWith(
                                  times24h: updatedTimes.map(dtTo24h).toList(),
                                  dosesPerDay:
                                      widget.draft.dosesPerDay ?? total,
                                ),
                              ),
                            ),
                          );
                          return;
                        }

                        // Último horario → guardar
                        setState(() => _saving = true);
                        try {
                          final finalDraft = widget.draft.copyWith(
                            times24h: updatedTimes.map(dtTo24h).toList(),
                            dosesPerDay:
                                widget.draft.dosesPerDay ?? updatedTimes.length,
                          );

                          await MedsRepository.instance.saveDraft(finalDraft);

                          if (!mounted) return;
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.home,
                            (_) => false,
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('No se pudo guardar: $e')),
                          );
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                child: Text(
                  _saving ? 'Guardando…' : 'Guardar',
                  style: const TextStyle(
                    color: AppColors.secundario,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
