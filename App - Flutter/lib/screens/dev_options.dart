// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:pillbox/core/colores.dart';
import 'package:pillbox/notificaciones/alarm_notifier.dart';

class DevOptionsScreen extends StatelessWidget {
  const DevOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.prueba2,
      appBar: AppBar(
        backgroundColor: AppColors.prueba2,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: AppColors.secundario,
        ),
        title: const Text(
          'Opciones de desarrollo',
          style: TextStyle(
            color: AppColors.secundario,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Herramientas de prueba',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secundario,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Usá estas opciones para probar rápidamente las notificaciones '
                'sin tener que crear medicamentos de prueba.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),

              // Contenido principal
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildDevButton(
                          context: context,
                          titulo: 'Alarma instantánea',
                          descripcion:
                              'Envía una notificación inmediata para verificar que todo esté funcionando.',
                          icono: Icons.notification_add_outlined,
                          color: Colors.green,
                          onTap: () async {
                            await AlarmNotifier.testNow();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Notificación enviada ahora'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildDevButton(
                          context: context,
                          titulo: 'Alarma en 1 minuto',
                          descripcion:
                              'Programa una alarma a 1 minuto desde ahora para probar la programación.',
                          icono: Icons.schedule_outlined,
                          color: Colors.orange,
                          onTap: () async {
                            await AlarmNotifier.scheduleInMinutes(
                              id: 888001,
                              minutes: 1,
                              title: '⏰ Recordatorio de prueba',
                              body: 'Esta alarma fue programada hace 1 minuto',
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    '⏰ Alarma programada para dentro de 1 minuto'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDevButton({
    required BuildContext context,
    required String titulo,
    required String descripcion,
    required IconData icono,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.7),
            width: 1.2,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icono,
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descripcion,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
