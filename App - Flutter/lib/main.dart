// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app.dart';
import 'package:pillbox/notificaciones/alarm_notifier.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase con las opciones generadas por FlutterFire CLI
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  tz.initializeTimeZones();

  await AlarmNotifier.init();

  runApp(const PillBoxApp());
}

class PillBoxApp extends StatelessWidget {
  const PillBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
          title: 'PillBox',
          initialRoute: '/auth', // o tu HomeScreen si aplica
          routes: AppRoutes.routes,
          onGenerateRoute: AppRoutes.onGenerateRoute,
        );
  }
}
