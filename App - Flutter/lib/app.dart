import 'package:flutter/material.dart';
import 'package:pillbox/data/models/regimen_draft.dart';
import 'screens/historial_medicamentos.dart';
import 'screens/dev_options.dart';

// Flujo de medicación
import 'screens/registrar medicamrntos (SubScreens)/pantalla_opciones_dinamicas.dart';
import 'screens/registrar medicamrntos (SubScreens)/date_picker_screen.dart';
import 'screens/registrar medicamrntos (SubScreens)/time_picker_flow_screen.dart';
import 'screens/registrar medicamrntos (SubScreens)/dose_count_screen.dart';
import 'screens/registrar medicamrntos (SubScreens)/weekday_selector_screen.dart' as weekday_selector;
import 'screens/registrar medicamrntos (SubScreens)/weekday_dose_time_screen.dart';
import 'screens/home_screen.dart';
import 'screens/registrar medicamrntos (SubScreens)/pillname_screen.dart';
import 'auth/auth_gate.dart';

class AppRoutes {
  static const String auth = '/auth';
  static const String home           = '/home';
  static const String medsName       = '/meds/name'; 
  static const String medsOpciones    = '/meds/opciones';
  static const String medsDate        = '/meds/date';
  static const String medsTime1       = '/meds/time1';
  static const String medsDose        = '/meds/dose';
  static const String medsWeekday     = '/meds/weekday';
  static const String medsWeekdayDose = '/meds/weekdayDose';
  static const String historial = '/historial';
  static const String dev = '/devoptions';



  static Map<String, WidgetBuilder> routes = {
    // Screen principal (home)
    auth:        (_) => const AuthGate(),
    home:        (_) => const HomeScreen(),
    
    // Flujo de medicación
    medsName:    (_) => const MedNameScreen(),
    medsDate:     (_) => DatePickerScreen(draft: RegimenDraft()),
    medsTime1:    (_) => TimePickerFlowScreen(
      titulo: 'Elegí el horario',
      remaining: 1,
      collectedTimes: [],
      draft: RegimenDraft(),
    ),
    medsDose:     (_) => DoseCountScreen(next: (count) {}, draft: RegimenDraft()),
    medsWeekday:  (_) => weekday_selector.WeekdaySelectorScreen(draft: RegimenDraft()),
    

  // Screen de historial de medicamentos
    historial: (_) => const HistorialScreen(),

    // Opciones de desarrollador
    dev:        (_) => const DevOptionsScreen(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  if (settings.name == AppRoutes.medsOpciones) {
    final args = (settings.arguments as Map?) ?? {};
    final draft = args['draft'] as RegimenDraft?;  // 👈 viene de MedNameScreen

    return MaterialPageRoute(
      builder: (_) => PantallaOpcionesDinamica(
        titulo: '¿Con qué frecuencia tomará la pastilla?',
        opciones: const [
          'Cada día',
          'Día por medio',
          'Días específicos de la semana',
          'Solo una vez',
        ],
        historial: const [],
        draft: draft ?? const RegimenDraft(), // 👈 importante
      ),
    );
  }

    // /meds/weekdayDose recibe lista de días seleccionados
    if (settings.name == medsWeekdayDose) {
      final args = settings.arguments as List<String>? ?? const ['Lun', 'Mié', 'Vie'];
      return MaterialPageRoute(
        builder: (_) => WeekdayDoseTimeScreen(selectedWeekdays: args, draft: RegimenDraft()),
      );
    }

    return null;
  }
}
