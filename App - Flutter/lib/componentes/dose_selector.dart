// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../core/colores.dart';

class DoseSelector extends StatefulWidget {
  final int initial;
  final int min;
  final int max;
  final ValueChanged<int>? onChanged;

  const DoseSelector({
    super.key,
    this.initial = 1,
    this.min = 1,
    this.max = 4,
    this.onChanged,
  });

  @override
  State<DoseSelector> createState() => _DoseSelectorState();
}

class _DoseSelectorState extends State<DoseSelector> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial.clamp(widget.min, widget.max);
  }

  void _set(int v) {
    final nv = v.clamp(widget.min, widget.max);
    if (nv != _value) {
      setState(() => _value = nv);
      widget.onChanged?.call(nv);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Display “pastillas / día”
        Container(
          width: size.width * 0.9,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.prueba2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primario.withOpacity(.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.2),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              _RoundIconButton(
                icon: Icons.remove,
                onTap: () => _set(_value - 1),
                disabled: _value <= widget.min,
              ),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 180),
                  tween: Tween(begin: 0, end: _value.toDouble()),
                  builder: (context, _, __) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Text(
                          '$_value',
                          key: ValueKey(_value),
                          style: const TextStyle(
                            color: AppColors.secundario,
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'dosis por día',
                        style: TextStyle(
                          color: AppColors.secundario,
                          fontSize: 14,
                          letterSpacing: .2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _RoundIconButton(
                icon: Icons.add,
                onTap: () => _set(_value + 1),
                disabled: _value >= widget.max,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Accesos rápidos (chips)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(widget.max - widget.min + 1, (i) {
            final label = widget.min + i;
            final bool selected = label == _value;
            return GestureDetector(
              onTap: () => _set(label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.botones : AppColors.prueba2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppColors.botones
                        : AppColors.primario.withOpacity(.25),
                  ),
                ),
                child: Text(
                  '$label',
                  style: TextStyle(
                    color: AppColors.secundario.withOpacity(selected ? 1 : .85),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool disabled;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: disabled ? null : onTap,
      radius: 28,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: disabled
              ? AppColors.terciario.withOpacity(.35)
              : AppColors.botones,
        ),
        child: Icon(icon, color: AppColors.secundario),
      ),
    );
  }
}
