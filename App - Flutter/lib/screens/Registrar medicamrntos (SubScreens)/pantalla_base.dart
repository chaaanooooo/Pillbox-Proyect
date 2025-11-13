import 'package:flutter/material.dart';
import 'package:pillbox/core/colores.dart';
import 'package:pillbox/componentes/botones_principales.dart';

class PantallaBase extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Widget child;
  final bool resizeToAvoidBottomInset;

  const PantallaBase({
    Key? key,
    required this.titulo,
    required this.icono,
    required this.child,
    this.resizeToAvoidBottomInset = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: AppColors.prueba1,
      body: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsetsGeometry.directional(top: 20),
            child: const VolverButton(),
          ),

          // Ícono y título
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Icon(icono, size: 38, color: AppColors.secundario),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 20, left: 24, right: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                titulo,
                style: const TextStyle(
                  color: AppColors.secundario,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Contenedor principal SIN altura fija
          Expanded(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              // Esto empuja todo el contenido cuando el teclado aparece,
              // haciendo que el botón "suba" junto con el teclado.
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.prueba2,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
