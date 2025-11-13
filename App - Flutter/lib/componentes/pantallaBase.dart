// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:pillbox/core/colores.dart';
import 'package:pillbox/componentes/botones_principales.dart';

class PantallaBase extends StatelessWidget {
  final String titulo;
  final Widget child;
  final IconData icono;

  const PantallaBase({
    super.key,
    required this.titulo,
    required this.child,
    this.icono = Icons.calendar_month_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.prueba1,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          VolverButton(),
          Padding(
            padding: const EdgeInsets.only(top: 20, right: 320),
            child: Icon(
              icono,
              size: 40,
              color: Colors.white,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20.0, bottom: 20, left: 28),
            child: Text(
              titulo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            height: screenHeight * 0.75,
            width: screenWidth,
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}