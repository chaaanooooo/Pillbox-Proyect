import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:pillbox/core/colores.dart';
import 'pantalla_base.dart';
import 'weekday_dose_time_screen.dart';
import 'package:pillbox/data/models/regimen_draft.dart';

class WeekdaySelectorScreen extends StatefulWidget {
  final RegimenDraft draft; // 👈 ahora recibe el borrador

  const WeekdaySelectorScreen({super.key, required this.draft});

  @override
  State<WeekdaySelectorScreen> createState() => _WeekdaySelectorScreenState();
}

class _WeekdaySelectorScreenState extends State<WeekdaySelectorScreen> {
  final Map<String, bool> _days = {
    'Lun': false, 'Mar': false, 'Mié': false, 'Jue': false,
    'Vie': false, 'Sáb': false, 'Dom': false,
  };

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PantallaBase(
      titulo: 'Elegí los días de la semana',
      icono: Icons.event_repeat,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                children: _days.keys.map((k) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.prueba2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primario.withOpacity(.25)),
                    ),
                    child: CheckboxListTile(
                      value: _days[k],
                      onChanged: (v) => setState(() => _days[k] = v ?? false),
                      title: Text(k, style: const TextStyle(color: AppColors.secundario)),
                      activeColor: AppColors.botones,
                      checkColor: AppColors.secundario,
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: size.width * 0.85,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.botones),
                onPressed: () {
                  final selected = _days.entries.where((e) => e.value).map((e) => e.key).toList();
                  if (selected.isEmpty) return;

                  final next = widget.draft.copyWith(
                    weekdays: selected,
                    // por si todavía no estaba definido:
                    type: widget.draft.type ?? ScheduleType.specificWeekdays,
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WeekdayDoseTimeScreen(selectedWeekdays: selected, draft: next), // 👈 pasamos selectedWeekdays y draft
                    ),
                  );
                },
                child: const Text(
                  'Continuar',
                  style: TextStyle(color: AppColors.secundario, fontSize: 18),
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
