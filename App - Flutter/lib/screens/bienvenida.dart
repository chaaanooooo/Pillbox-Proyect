import 'package:flutter/material.dart';
import 'package:pillbox/core/colores.dart';
import 'inicio_sesion_screen.dart';
import 'registro_screen.dart';

class BienvenidaScreen extends StatelessWidget {
  const BienvenidaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.prueba2,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOGO O TÍTULO
                Icon(Icons.medication_outlined,
                    size: 80, color: AppColors.botones),
                const SizedBox(height: 20),

                const Text(
                  'Bienvenido a PillBox',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.secundario,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Organizá tus medicamentos de manera fácil y segura.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.terciario,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 60),

                // BOTÓN DE INICIAR SESIÓN
                SizedBox(
                  width: size.width * 0.8,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.botones,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const InicioSesion()),
                      );
                    },
                    child: const Text(
                      'Iniciar sesión',
                      style: TextStyle(
                        color: AppColors.secundario,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // BOTÓN DE REGISTRO
                SizedBox(
                  width: size.width * 0.8,
                  height: 50,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.botones, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegistroScreen()),
                      );
                    },
                    child: const Text(
                      'Registrarse',
                      style: TextStyle(
                        color: AppColors.botones,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                const Text(
                  'Versión 1.0.0',
                  style: TextStyle(
                    color: AppColors.terciario,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
