// lib/screens/agregar_pastilla_screen.dart
import 'package:flutter/material.dart';
import '../componentes/prueba.dart';

class AgregarPastillaScreen extends StatefulWidget {
  const AgregarPastillaScreen({super.key});

  @override
  State<AgregarPastillaScreen> createState() => _AgregarPastillaScreenState();
}

class _AgregarPastillaScreenState extends State<AgregarPastillaScreen> {
  String? _resultado; // opcional, para ver qué llegó

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar pastilla')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MedicamentoInput(
                onSelected: (name) {
                  // acá guardás en tu DB/Provider/Firebase, etc.
                  setState(() => _resultado = name);
                  // si querés volver a la pantalla anterior:
                  // Navigator.pop(context, name);
                },
              ),
              if (_resultado != null) ...[
                const SizedBox(height: 12),
                Text('Última selección: $_resultado'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}