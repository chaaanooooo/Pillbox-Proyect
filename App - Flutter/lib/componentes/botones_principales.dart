import 'package:flutter/material.dart';
import 'package:pillbox/core/colores.dart';
import 'package:pillbox/screens/inicio_sesion_screen.dart';
import 'package:pillbox/screens/registro_screen.dart';

class Registro extends StatelessWidget {
  const Registro({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsetsGeometry.directional(top: 10),
            child: SizedBox(
              width: screenWidth * 0.80,
              height: screenHeight * 0.09,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RegistroScreen())
                  );
              },
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(AppColors.secundario),
                foregroundColor: WidgetStatePropertyAll(AppColors.primario),
              ),
              child: Text(
                "Registrate",
                style: TextStyle(fontSize: 18),
                )
              ),
            ),
          ),
        )
      ],
    );
  }
}

class SinCuentaButton extends StatelessWidget {
  const SinCuentaButton({super.key});

  @override
  Widget build(BuildContext context) {

    return Row(
      children: [
        Text(
          "Ya tienes una cuenta?",
          style: TextStyle(
            fontSize: 18,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => InicioSesion())
              );
          }, 
          child: Text(
            "Inicia sesion",
            style: TextStyle(
              fontSize: 18,
            ),
          ) 
        )
      ],
    );
  }
}

class VolverButton extends StatelessWidget {
  const VolverButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsGeometry.directional(end: 326, top: 15),
      child: Column(
        children: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.arrow_back, color: AppColors.botones,)
          )
        ],
      ),
    );
  }
}

class CrearCuentaButton extends StatelessWidget {
  const CrearCuentaButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OutlinedButton(
          onPressed: null,
          style: ButtonStyle(
            
          ),
          child: Text(
            "Crear Cuenta"
          )
        )
      ],
    );
  }
}

class FinalizarRegistro extends StatelessWidget {
  final Future<void> Function()? onPressed;

  const FinalizarRegistro({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          SizedBox(
            height: screenHeight * 0.06,
            width: screenWidth * 0.80,
            child: OutlinedButton(
              onPressed: onPressed == null ? null : () => onPressed!(),
              style: const ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(AppColors.botones),
              ),
              child: const Text(
                "Comenzar",
                style: TextStyle(
                  color: AppColors.secundario,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class BotonesPastilla extends StatelessWidget {
  const BotonesPastilla({
    super.key,
    this.agregarKey,
    this.modificarKey,
    this.calendarioKey,
  });

  final GlobalKey? agregarKey;
  final GlobalKey? modificarKey;
  final GlobalKey? calendarioKey;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Botón 1 - Agregar
          Padding(
            padding: const EdgeInsetsGeometry.directional(top: 40),
            child: SizedBox(
              height: screenHeight * 0.07,
              width: screenWidth * 0.80,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/meds/opciones'),
                icon: 
                  Icon(
                    Icons.add,
                    color: AppColors.secundario,
                  ),
                style: 
                  ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(AppColors.prueba1)
                  ),
                label: 
                  Text(
                    "Agregar pastilla",
                    style: TextStyle(
                    color: AppColors.secundario
                    ),
                    )
              ),
            ),
          ),
        ],
      ),
    );
  }
}