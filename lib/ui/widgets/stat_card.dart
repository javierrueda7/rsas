import 'package:flutter/material.dart';

/// Tarjeta KPI/estadística compartida: ícono + valor + etiqueta.
/// Muestra la flecha "›" solo cuando es interactiva (`onTap != null`).
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  /// Ancho fijo de la tarjeta. `null` deja que el padre decida
  /// (por ejemplo, dentro de un `Expanded` en un `Row`).
  final double? width;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    this.width = 200,
  });

  @override
  Widget build(BuildContext context) {
    final isClickable = onTap != null;
    final card = Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, color: color, size: 22),
                if (isClickable) ...[
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 16, color: color.withOpacity(0.5)),
                ],
              ]),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
            ]),
          ),
        ),
    );
    return width == null ? card : SizedBox(width: width, child: card);
  }
}
