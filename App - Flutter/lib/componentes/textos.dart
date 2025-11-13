import 'package:flutter/material.dart';
import 'package:pillbox/core/colores.dart';

class Bienvenida extends StatelessWidget {
  const Bienvenida({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsGeometry.directional(top: 100),
      child: Column(
        children: [
          Text(
            "Bienvenido al pastillero",
            style: TextStyle(
              color: AppColors.primario,
              fontSize: 38,
              fontWeight: FontWeight.bold
              ),
            )
        ],
      ),
    );
  }
}

class TextoInferior extends StatelessWidget {
  const TextoInferior({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsGeometry.directional(top: 10),
          child: Text("Seleccione una de las dos opciones de abajo para continuar",
          style: TextStyle(
            color: AppColors.terciario,
            fontSize: 20,
            
          ),
          ),
        )
      ],
    );
  }
}

class TextoDeInicioSesion extends StatelessWidget {
  const TextoDeInicioSesion({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsGeometry.directional(top: 100, end: 130),
      child: SizedBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Iniciar Sesion",
              style: TextStyle(
                fontSize: 30,
                color: AppColors.primario,
              ),
            ),
              SizedBox(
                child: Text(
                  "Ingresa a tu cuenta",
                  style: TextStyle(
                    fontSize: 25,
                    color: AppColors.terciario
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}


class TextoDeRegistro extends StatelessWidget {
  const TextoDeRegistro({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsGeometry.directional(top: 100, end: 142),
      child: SizedBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Registrate",
              style: TextStyle(
                fontSize: 30,
                color: AppColors.primario,
              ),
            ),
              SizedBox(
                child: Text(
                  "Create una cuenta",
                  style: TextStyle(
                    fontSize: 25,
                    color: AppColors.terciario
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
