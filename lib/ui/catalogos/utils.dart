import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FechasPolizaSection extends StatefulWidget {
  const FechasPolizaSection({super.key});

  @override
  State<FechasPolizaSection> createState() => _FechasPolizaSectionState();
}

class _FechasPolizaSectionState extends State<FechasPolizaSection> {
  final DateFormat _format = DateFormat('dd-MM-yyyy');

  DateTime fechaInicio = DateTime.now();
  DateTime fechaFin = DateTime.now().add(const Duration(days: 365));

  late TextEditingController inicioController;
  late TextEditingController finController;

  @override
  void initState() {
    super.initState();

    inicioController =
        TextEditingController(text: _format.format(fechaInicio));

    finController =
        TextEditingController(text: _format.format(fechaFin));
  }

  Future<void> _pickInicio() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: fechaInicio,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        fechaInicio = picked;

        // 🔥 Fin automático +1 año
        fechaFin = DateTime(
          picked.year + 1,
          picked.month,
          picked.day,
        );

        inicioController.text = _format.format(fechaInicio);
        finController.text = _format.format(fechaFin);
      });
    }
  }

  Future<void> _pickFin() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: fechaFin,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        fechaFin = picked;
        finController.text = _format.format(fechaFin);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Fechas",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: inicioController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Inicio *",
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: _pickInicio,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: TextFormField(
                controller: finController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Fin *",
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: _pickFin,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
