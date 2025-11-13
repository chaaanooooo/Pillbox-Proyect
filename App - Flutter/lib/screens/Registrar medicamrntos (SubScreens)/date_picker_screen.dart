import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pillbox/core/colores.dart';
import 'pantalla_base.dart';
import 'dose_count_screen.dart';
import 'time_picker_flow_screen.dart';
import 'package:pillbox/data/models/regimen_draft.dart';

class DatePickerScreen extends StatefulWidget {
  final RegimenDraft draft; // 👈 NUEVO

  const DatePickerScreen({
    super.key,
    required this.draft,     // 👈 NUEVO
  });

  @override
  State<DatePickerScreen> createState() => _DatePickerScreenState();
}

class _DatePickerScreenState extends State<DatePickerScreen> {
  final int _currentYear = DateTime.now().year;

  // Meses abreviados (podés cambiarlos a gusto)
  final List<String> _months = const [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
  ];

  int _monthIndex = DateTime.now().month - 1; // 0..11
  int _dayIndex = DateTime.now().day - 1;     // 0..30 (se ajusta)
  late List<int> _daysForMonth;

  @override
  void initState() {
    super.initState();
    _daysForMonth = _computeDays(_monthIndex, _currentYear);
    // Asegurar que dayIndex no exceda la cantidad del mes
    if (_dayIndex >= _daysForMonth.length) _dayIndex = _daysForMonth.length - 1;
  }

  List<int> _computeDays(int monthIndex, int year) {
    final month = monthIndex + 1;
    final lastDay = DateTime(year, month + 1, 0).day; // truco para último día del mes
    return List<int>.generate(lastDay, (i) => i + 1);
  }

  DateTime get _selectedDate =>
      DateTime(_currentYear, _monthIndex + 1, _daysForMonth[_dayIndex]);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PantallaBase(
      titulo: 'Elegí la fecha de inicio (día por medio)',
      icono: Icons.event,
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
                    // ignore: deprecated_member_use
                  ),
                  height: size.height * 0.35,
                  child: Row(
                    children: [
                      // MES
                      Expanded(
                        child: CupertinoPicker(
                          magnification: 1.1,
                          itemExtent: 36,
                          useMagnifier: true,
                          scrollController: FixedExtentScrollController(initialItem: _monthIndex),
                          onSelectedItemChanged: (i) {
                            setState(() {
                              _monthIndex = i;
                              _daysForMonth = _computeDays(_monthIndex, _currentYear);
                              if (_dayIndex >= _daysForMonth.length) {
                                _dayIndex = _daysForMonth.length - 1;
                              }
                            });
                          },
                          children: _months
                              .map((m) => Center(
                                    child: Text(
                                      m,
                                      style: const TextStyle(
                                          color: AppColors.secundario, fontSize: 18),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      // DÍA
                      Expanded(
                        child: CupertinoPicker(
                          magnification: 1.1,
                          itemExtent: 36,
                          useMagnifier: true,
                          scrollController: FixedExtentScrollController(initialItem: _dayIndex),
                          onSelectedItemChanged: (i) {
                            setState(() => _dayIndex = i);
                          },
                          children: _daysForMonth
                              .map((d) => Center(
                                    child: Text(
                                      d.toString(),
                                      style: const TextStyle(
                                          color: AppColors.secundario, fontSize: 18),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: size.width * 0.85,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.prueba1),
                onPressed: () {
                  final updatedDraft = widget.draft.copyWith(startDate: _selectedDate);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DoseCountScreen(
                        next: (count) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TimePickerFlowScreen(
                                titulo: 'Horario 1 de $count',
                                remaining: count,
                                collectedTimes: const [],
                                draft: updatedDraft.copyWith(dosesPerDay: count),
                              ),
                            ),
                          );
                        },
                        draft: updatedDraft,
                      ),
                    ),
                  );
                },
                child: const Text('Guardar',
                    style: TextStyle(color: AppColors.secundario, fontSize: 18)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
