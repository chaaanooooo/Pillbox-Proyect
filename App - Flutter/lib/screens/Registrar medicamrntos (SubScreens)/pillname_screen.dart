import 'package:flutter/material.dart';
import 'package:pillbox/core/colores.dart';
import 'package:pillbox/screens/Registrar medicamrntos (SubScreens)/pantalla_base.dart';
import 'package:pillbox/data/models/regimen_draft.dart';
import '../../app.dart' show AppRoutes;

class MedNameScreen extends StatefulWidget {
  const MedNameScreen({super.key});

  @override
  State<MedNameScreen> createState() => _MedNameScreenState();
}

class _MedNameScreenState extends State<MedNameScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _canContinue = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final can = _controller.text.trim().isNotEmpty;
      if (can != _canContinue) {
        setState(() => _canContinue = can);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goNext() {
    final name = _controller.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un nombre')),
      );
      return;
    }
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre debe tener al menos 2 caracteres')),
      );
      return;
    }

    try {
      final draft = RegimenDraft(name: name);

      // Intenta navegar por nombre de ruta:
      try {
        Navigator.pushNamed(
          context,
          AppRoutes.medsOpciones,
          arguments: {'draft': draft},
        );
      } catch (e) {
        // Fallback: si la ruta no existe, avisamos claro
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ruta no encontrada: ${AppRoutes.medsOpciones}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PantallaBase(
      titulo: 'Ingresá el nombre del medicamento',
      icono: Icons.medication_outlined,
      resizeToAvoidBottomInset: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    SizedBox(
                      height: 55,
                      child: TextField(
                        controller: _controller,
                        onSubmitted: (_) => _goNext(),
                        autofocus: true,
                        style: const TextStyle(color: AppColors.secundario), // Usa tu color personalizado
                        decoration: const InputDecoration(hintText: 'Ej: Ibuprofeno', hintStyle: TextStyle(color: AppColors.terciario),),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sugerencia: escribe el nombre comercial o el principio activo.',
                      style: TextStyle(fontSize: 15, color: AppColors.terciario),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: MediaQuery.sizeOf(context).width * 0.85,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _canContinue ? () => _goNext() : null,
                    child: Text(
                      'Continuar',
                      style: TextStyle(color: AppColors.secundario),
                      ),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.prueba1)
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}