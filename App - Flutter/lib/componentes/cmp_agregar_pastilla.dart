// ignore_for_file: camel_case_types

import 'package:flutter/material.dart';


class nombrePastilla extends StatefulWidget {
  const nombrePastilla({super.key});

  @override
  State<nombrePastilla> createState() => _nombrePastillaState();
}

class _nombrePastillaState extends State<nombrePastilla> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;


    return Center(
      child: Padding(
        padding: const EdgeInsetsGeometry.directional(top: 80),
        child: SizedBox(
          width: screenWidth * 0.80,
          height: screenHeight * 0.09,
          child: TextField(
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              labelText: 'Nombre de la pastilla',
            ),
          ),
        ),
      ),
    );
  }
}

class spinners extends StatefulWidget {
  const spinners({super.key});

  @override
  State<spinners> createState() => _spinnersState();
}

class _spinnersState extends State<spinners> {
  String? selectedValue; // <-- Agrega esta variable

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Container(
          width: screenWidth * 0.80,
          height: screenHeight * 0.07,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blueAccent,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedValue, // <-- Usa la variable aquí
              hint: const Text("Selecciona la dosis"),
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              items: const [
                DropdownMenuItem(value: '1/4', child: Text('1/4')),
                DropdownMenuItem(value: '1/2', child: Text('1/2')),
                DropdownMenuItem(value: '1', child: Text('1')),
                DropdownMenuItem(value: '2', child: Text('2')),
              ],
              onChanged: (value) {
                setState(() {
                  selectedValue = value; // <-- Actualiza la variable
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}