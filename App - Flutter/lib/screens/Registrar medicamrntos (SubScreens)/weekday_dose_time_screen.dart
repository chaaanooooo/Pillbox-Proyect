import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pillbox/core/colores.dart';
import 'pantalla_base.dart';
import 'package:pillbox/componentes/dose_selector.dart';
import 'package:pillbox/data/models/regimen_draft.dart';

class WeekdayDoseTimeScreen extends StatefulWidget {
  final List<String> selectedWeekdays;
  final RegimenDraft draft;
  const WeekdayDoseTimeScreen({super.key, required this.selectedWeekdays, required this.draft});

  @override
  State<WeekdayDoseTimeScreen> createState() => _WeekdayDoseTimeScreenState();
}

class _WeekdayDoseTimeScreenState extends State<WeekdayDoseTimeScreen> {
  int _count = 1;
  int _currentIndex = 1;
  DateTime _selected = DateTime.now();
  final List<DateTime> _collected = [];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PantallaBase(
      titulo: 'Seleccionar dosis y horario',
      icono: Icons.schedule,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            // Selector de dosis “lindo”
            DoseSelector(
              initial: _count,
              min: 1,
              max: 4,
              onChanged: (v) {
                setState(() {
                  _count = v;
                  _currentIndex = 1;
                  _collected.clear();
                });
              },
            ),
            const SizedBox(height: 16),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Horario $_currentIndex de $_count',
                style: const TextStyle(
                  color: AppColors.secundario,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Picker de hora estilizado
            Expanded(
              child: Center(
                child: Container(
                  width: size.width * 0.9,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.prueba2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primario.withOpacity(.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.2),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  height: size.height * 0.35,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: _selected,
                    onDateTimeChanged: (dt) => _selected = dt,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: size.width * 0.85,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.botones),
                onPressed: () {
                  _collected.add(_selected);
                  if (_currentIndex < _count) {
                    setState(() {
                      _currentIndex++;
                      _selected = DateTime.now();
                    });
                  } else {
                    // TODO: persistir (widget.selectedWeekdays, _collected)
                    Navigator.pushNamedAndRemoveUntil(context, '/menu', (_) => false);
                  }
                },
                child: Text(
                  _currentIndex < _count ? 'Guardar y siguiente' : 'Guardar',
                  style: const TextStyle(color: AppColors.secundario, fontSize: 18),
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
