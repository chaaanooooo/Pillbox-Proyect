// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:pillbox/componentes/menu_lateral.dart';
import 'package:pillbox/componentes/textos_imports.dart';

// 👇 IMPORTS ACTUALIZADOS
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pillbox/core/colores.dart';
import 'package:pillbox/notificaciones/alarm_notifier.dart';
import 'package:pillbox/notificaciones/alarm_planificador.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1) Pedimos SOLO el permiso de notificaciones (Android 13+ / iOS)
      await AlarmNotifier.requestPermission(context);

      // 2) Comprobamos si el sistema las tiene habilitadas
      final enabled = await AlarmNotifier.areEnabledOnAndroid();
      debugPrint('🔔 Notificaciones habilitadas a nivel sistema: $enabled');

      // 3) Si hay usuario, reprogramamos todas las alarmas desde Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await AlarmScheduler.rescheduleAllForUser(user.uid);
          debugPrint('[HomeScreen] Reprogramadas las alarmas de ${user.uid}');
        } catch (e) {
          debugPrint('[HomeScreen] Error reprogramando: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No se pudieron reprogramar las alarmas: $e')),
            );
          }
        }
      }
    });
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    key: _scaffoldKey,
    backgroundColor: AppColors.prueba2,
    appBar: AppBar(
      backgroundColor: AppColors.prueba2,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: AppColors.secundario),
        onPressed: () {
          _scaffoldKey.currentState?.openDrawer();
        },
      ),
    ),

    drawer: const AppDrawer(),

    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bienvenida
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: BienvenidaUsuario(),
            ),

            // Frase aleatoria
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: FraseAleatoria(),
            ),

            // Opciones principales
            Expanded(
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 10, bottom: 10),
                    child: _buildOpcion(
                      context,
                      'Registrar Medicamento',
                      Icons.add_circle_outline,
                      () {
                        Navigator.pushNamed(context, '/meds/name');
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 10),
                    child: _buildOpcion(
                      context,
                      'Medicamentos',
                      Icons.medication,
                      () {
                        Navigator.pushNamed(context, '/historial');
                      },
                    ),
                  ),
                  _buildOpcion(
                    context,
                    'Opciones de desarrollador',
                    Icons.code,
                    () {
                      Navigator.pushNamed(context, '/devoptions');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
  );
  }
}


  // Widget para construir cada opción
  Widget _buildOpcion(
    BuildContext context,
    String titulo,
    IconData icono,
    VoidCallback onTap, {
    Color? color,
  }) {
    final buttonColor = color ?? Colors.blue;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Icon(icono, color: buttonColor),
        title: Text(
          titulo,
          style: TextStyle(
            fontSize: 18,
            color: color != null ? buttonColor : AppColors.secundario,
            fontWeight: FontWeight.w500,
          ),
        ),
        tileColor: buttonColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        onTap: onTap,
      ),
    );
  }