import 'package:flutter/material.dart';
import 'package:pillbox/core/colores.dart';
import 'pantalla_base.dart';
import 'package:pillbox/componentes/dose_selector.dart';
import 'package:pillbox/data/models/regimen_draft.dart';

class DoseCountScreen extends StatefulWidget {
  final void Function(int count) next;
  final RegimenDraft draft;
  const DoseCountScreen({super.key, required this.next, required this.draft});

  @override
  State<DoseCountScreen> createState() => _DoseCountScreenState();
}

class _DoseCountScreenState extends State<DoseCountScreen> {
  int _count = 1;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PantallaBase(
      titulo: '¿Cuántas dosis por día?',
      icono: Icons.medication_liquid_rounded,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            const SizedBox(height: 8),
            DoseSelector(
              initial: _count,
              min: 1,
              max: 4,
              onChanged: (v) => _count = v,
            ),
            const Spacer(),
            SizedBox(
              width: size.width * 0.85,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.botones),
                onPressed: () => widget.next(_count),
                child: const Text(
                  'Continuar',
                  style: TextStyle(color: AppColors.secundario, fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
