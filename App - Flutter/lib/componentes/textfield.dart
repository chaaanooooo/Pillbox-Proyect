import 'package:flutter/material.dart';
import 'package:pillbox/core/colores.dart';

class RegistroInputs extends StatelessWidget {
  final TextEditingController nombreController;
  final TextEditingController emailController;
  final TextEditingController passController;

  const RegistroInputs({
    super.key,
    required this.nombreController,
    required this.emailController,
    required this.passController,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    InputDecoration _decoracionCampo(String label, IconData icono) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color.fromARGB(255, 152, 152, 152)),
        prefixIcon: Icon(icono, color: Colors.white),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.white), // blanco sin foco
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.secundario), // color cuando enfocado
        ),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 50, start: 30, end: 24),
      child: Column(
        children: [
          SizedBox(
            height: screenHeight * 0.09,
            width: screenWidth * 0.85,
            child: TextField(
              controller: nombreController,
              style: const TextStyle(color: Colors.white), // texto blanco
              decoration: _decoracionCampo("Nombre de usuario", Icons.person),
            ),
          ),
          SizedBox(
            height: screenHeight * 0.09,
            width: screenWidth * 0.85,
            child: TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white), // texto blanco
              decoration: _decoracionCampo("Email", Icons.email),
            ),
          ),
          SizedBox(
            height: screenHeight * 0.09,
            width: screenWidth * 0.85,
            child: TextField(
              controller: passController,
              obscureText: true,
              style: const TextStyle(color: Colors.white), // texto blanco
              decoration: _decoracionCampo("Contraseña", Icons.lock),
            ),
          ),
        ],
      ),
    );
  }
}

class InicioSesionInputs extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passController;
  final String? errorText;
  final bool disabled;

  const InicioSesionInputs({
    super.key,
    required this.emailController,
    required this.passController,
    this.errorText,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    InputDecoration _decoracionCampo(String label, IconData icono) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color.fromARGB(255, 152, 152, 152)),
        prefixIcon: Icon(icono, color: Colors.white),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.white),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.secundario),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 50, start: 30, end: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: screenHeight * 0.09,
            width: screenWidth * 0.85,
            child: TextField(
              controller: emailController,
              enabled: !disabled,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white), // texto blanco
              decoration: _decoracionCampo("Email", Icons.email),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: screenHeight * 0.09,
            width: screenWidth * 0.85,
            child: TextField(
              controller: passController,
              enabled: !disabled,
              obscureText: true,
              style: const TextStyle(color: Colors.white), // texto blanco
              decoration: _decoracionCampo("Contraseña", Icons.lock),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: screenWidth * 0.85),
              child: Text(
                errorText!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
