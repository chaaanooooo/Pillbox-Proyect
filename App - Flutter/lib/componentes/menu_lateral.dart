import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pillbox/core/colores.dart';
import 'package:pillbox/vinculacion/vinculacion_qr.dart';
import 'package:pillbox/data/services/pillbox_service.dart';
import 'package:pillbox/notificaciones/planificador.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _cancelAllUserAlarmsIfAny() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Buscamos todas las meds del usuario y cancelamos sus alarmas locales
    final q = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('meds')
        .get();

    for (final d in q.docs) {
      // Cada doc.id es un medId; MedScheduler.cancelMed() cancela el rango que usa esa med
      await MedScheduler.cancelMed(d.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: AppColors.secundario,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Menú',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Vincular PillBox
          ListTile(
            leading: const Icon(Icons.qr_code_scanner),
            title: const Text('Vincular PillBox'),
            onTap: () async {
              Navigator.pop(context); // cerrar el drawer

              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClaimQrPage()),
              );

              if (!context.mounted) return;

              if (result is Map && result['message'] is String) {
                final bool ok = (result['ok'] == true);
                final String msg = result['message'] as String;

                await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(ok ? 'PillBox vinculado' : 'Error al vincular'),
                    content: Text(msg),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Aceptar'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),

          // Desvincular PillBox
          ListTile(
            leading: const Icon(Icons.link_off, color: Colors.redAccent),
            title: const Text(
              'Desvincular PillBox',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () async {
              Navigator.pop(context);

              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('¿Desvincular PillBox?'),
                  content: const Text(
                    'Esto liberará el dispositivo y podrá ser vinculado por otra cuenta.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Desvincular'),
                    ),
                  ],
                ),
              );

              if (confirm != true) return;

              try {
                await PillboxService.unclaimDevice("PB-0001");
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔓 PillBox desvinculado correctamente'),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
          ),

          const Divider(),

          // Medicamentos
          ListTile(
            leading: const Icon(Icons.medication_outlined),
            title: const Text('Mis Medicamentos'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/historial');
            },
          ),

          // Ayuda
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Ayuda'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/ayuda');
            },
          ),

          const Divider(height: 30),

          // Cerrar sesión
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () async {
              Navigator.pop(context);

              // Loader mientras cancelamos alarmas
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                await _cancelAllUserAlarmsIfAny();

                await FirebaseAuth.instance.signOut();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al cerrar sesión: $e')),
                  );
                }
              } finally {
                if (context.mounted) Navigator.of(context).pop();
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sesión cerrada')),
                );
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/auth',
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
