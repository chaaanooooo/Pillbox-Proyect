// lib/componentes/medicamento_input.dart
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../core/dailymed_api.dart';

class MedicamentoInput extends StatefulWidget {
  final void Function(String medicamento)? onSelected;

  const MedicamentoInput({super.key, this.onSelected});

  @override
  State<MedicamentoInput> createState() => _MedicamentoInputState();
}

class _MedicamentoInputState extends State<MedicamentoInput> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _seleccion; // lo único válido para guardar

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _guardar() {
    if (_formKey.currentState!.validate()) {
      widget.onSelected?.call(_seleccion!);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Guardado: $_seleccion')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TypeAheadField<String>(
            debounceDuration: const Duration(milliseconds: 250),
            suggestionsCallback: (pattern) =>
                DailyMedApi.fetchDrugNames(pattern),
            itemBuilder: (context, s) => ListTile(title: Text(s)),
            onSelected: (s) {
              setState(() {
                _seleccion = s;
                _controller.text = s; // reflejar en UI
              });
            },
            emptyBuilder: (_) => const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Sin resultados'),
            ),
            builder: (context, textController, focusNode) {
              // usamos NUESTRO controller para poder validar/limpiar
              return TextFormField(
                controller: _controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: 'Medicamento',
                  hintText: 'Escribe “ibup…” y elige de la lista',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_seleccion != null && _controller.text != _seleccion) {
                    setState(() => _seleccion = null); // invalida selección
                  }
                },
                validator: (_) =>
                    _seleccion == null ? 'Elegí un medicamento de la lista' : null,
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _guardar,
              icon: const Icon(Icons.save),
              label: const Text('Guardar pastilla'),
            ),
          ),
        ],
      ),
    );
  }
}