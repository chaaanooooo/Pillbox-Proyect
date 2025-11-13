import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pillbox/core/colores.dart';

class BienvenidaUsuario extends StatelessWidget {
  const BienvenidaUsuario({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Text(
        "Bienvenido Usuario",
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.secundario),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid) // Buscar por UID del usuario
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Text(
            "Bienvenido ${user.email?.split('@').first ?? 'Usuario'}",
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.secundario),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final nombre = data['nombreUsuario'] ?? user.email?.split('@').first;

        return Text(
          "Bienvenido $nombre",
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.secundario),
        );
      },
    );
  }
}

class FraseAleatoria extends StatefulWidget {
  const FraseAleatoria({super.key});

  @override
  State<FraseAleatoria> createState() => _FraseAleatoriaState();
}

class _FraseAleatoriaState extends State<FraseAleatoria> {
  final List<String> frases = [
    "¿Como te encuentras hoy?",
    "No olvides tomar tus medicamentos",
    "¿Como te sentis hoy?",
    "Nos encanta verte por aca",
    "Un dia mas contigo",
    "Nos alegra verte de nuevo",
    "Listo para tomar tus pastillas?",
    "Administra tus tomas cuando quieras",
    "Todo lo que necesitas, en un solo lugar",
    "Gestiona tus pastillas desde aqui",
  ];

  late String fraseActual;

  @override
  void initState() {
    super.initState();
    _generarFrase(); // genera una distinta al construir la página
  }

  void _generarFrase() {
    final random = Random();
    final index = random.nextInt(frases.length);
    fraseActual = frases[index];
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      fraseActual,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.normal, color: AppColors.secundario),
    );
  }
}