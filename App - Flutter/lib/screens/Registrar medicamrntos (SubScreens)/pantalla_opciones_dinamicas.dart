import 'package:flutter/material.dart';
import 'pantalla_base.dart';
import 'package:pillbox/core/colores.dart';
import 'time_picker_flow_screen.dart';
import 'date_picker_screen.dart';
import 'weekday_selector_screen.dart';
import 'package:pillbox/data/models/regimen_draft.dart';

// ====== Labels centralizados (evita problemas por tildes) ======
const kTituloFrecuencia = '¿Con qué frecuencia tomará la pastilla?';
const kCadaDia         = 'Cada día';
const kDiaPorMedio     = 'Día por medio';
const kDiasEspecificos = 'Días específicos de la semana';
const kSoloUnaVez      = 'Solo una vez';

const kUnaVezDia   = 'Una vez al día';
const kDosVecesDia = 'Dos veces al día';
const kTresVecesDia= 'Tres veces al día';

// ====== Menú de opciones ======
final Map<String, List<String>> opcionesMenu = {
  kTituloFrecuencia: [
    kCadaDia,
    kDiaPorMedio,
    kDiasEspecificos,
    kSoloUnaVez,
  ],
  kCadaDia: [
    kUnaVezDia,
    kDosVecesDia,
    kTresVecesDia,
  ],
};

class PantallaOpcionesDinamica extends StatelessWidget {
  final String titulo;
  final List<String> opciones;
  final List<String> historial;

  /// Requerimos siempre el borrador
  final RegimenDraft draft;

  const PantallaOpcionesDinamica({
    super.key,
    required this.titulo,
    required this.opciones,
    this.historial = const [],
    required this.draft,
  });

  @override
  Widget build(BuildContext context) {
    return PantallaBase(
      titulo: titulo,
      icono: Icons.calendar_month_outlined,
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: opciones.map((opcion) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                height: 50,
                child: TextButton(
                  onPressed: () => _handleTap(context, opcion),
                  style: const ButtonStyle(
                    backgroundColor: MaterialStatePropertyAll(AppColors.prueba2),
                    overlayColor: MaterialStatePropertyAll(Colors.white12),
                    foregroundColor: MaterialStatePropertyAll(AppColors.secundario),
                    padding: MaterialStatePropertyAll(EdgeInsets.zero),
                  ),
                  child: Container(
                    alignment: Alignment.centerLeft,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.secundario, width: 2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 5, bottom: 15),
                      child: Text(
                        opcion,
                        style: const TextStyle(color: AppColors.secundario, fontSize: 18),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, String opcion) {
    final base = draft;

    // Si la opción tiene subopciones (p. ej. "Cada día")
    if (opcionesMenu.containsKey(opcion)) {
      final subOpciones = opcionesMenu[opcion]!;
      final nextDraft = (opcion == kCadaDia)
          ? base.copyWith(type: ScheduleType.everyDay)
          : base;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaOpcionesDinamica(
            titulo: opcion,
            opciones: subOpciones,
            historial: [...historial, opcion],
            draft: nextDraft,
          ),
        ),
      );
      return;
    }

    // Primer nivel: día por medio
    if (opcion == kDiaPorMedio) {
      final next = base.copyWith(type: ScheduleType.everyOtherDay);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DatePickerScreen(draft: next)),
      );
      return;
    }

    // Primer nivel: días específicos
    if (opcion == kDiasEspecificos) {
      final next = base.copyWith(type: ScheduleType.specificWeekdays);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => WeekdaySelectorScreen(draft: next)),
      );
      return;
    }

    // Primer nivel: solo una vez
    if (opcion == kSoloUnaVez) {
      final next = base.copyWith(type: ScheduleType.once, dosesPerDay: 1);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TimePickerFlowScreen(
            titulo: 'Elegí el horario',
            remaining: 1,
            collectedTimes: const [],
            draft: next,
          ),
        ),
      );
      return;
    }

    // Submenú "Cada día"
    if (opcion == kUnaVezDia) {
      final next = base.copyWith(type: ScheduleType.everyDay, dosesPerDay: 1);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TimePickerFlowScreen(
            titulo: 'Elegí el horario',
            remaining: 1,
            collectedTimes: const [],
            draft: next,
          ),
        ),
      );
      return;
    }

    if (opcion == kDosVecesDia) {
      final next = base.copyWith(type: ScheduleType.everyDay, dosesPerDay: 2);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TimePickerFlowScreen(
            titulo: 'Horario 1 de 2',
            remaining: 2,
            collectedTimes: const [],
            draft: next,
          ),
        ),
      );
      return;
    }

    if (opcion == kTresVecesDia) {
      final next = base.copyWith(type: ScheduleType.everyDay, dosesPerDay: 3);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TimePickerFlowScreen(
            titulo: 'Horario 1 de 3',
            remaining: 3,
            collectedTimes: const [],
            draft: next,
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opción aún no implementada')),
    );
  }
}
