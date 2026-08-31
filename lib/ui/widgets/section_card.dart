import 'package:flutter/material.dart';

/// Tarjeta de sección de formulario: título + divisor + contenido.
/// Sin `elevation` propio — hereda el `cardTheme` centralizado de la app.
class SectionCard extends StatelessWidget {
  final String titulo;
  final List<Widget> children;

  const SectionCard({super.key, required this.titulo, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}
