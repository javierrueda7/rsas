import 'package:flutter/material.dart';

/// Contenedor estándar para las tablas (DataTable) de la app: la tabla ocupa
/// siempre, como mínimo, todo el ancho disponible, así el cuadro no se
/// encoge ni se agranda según cuántas filas o qué textos traiga. Si la tabla
/// es más ancha que la pantalla, se desplaza de lado como antes.
class TablaAnchoCompleto extends StatelessWidget {
  final ScrollController controller;
  final EdgeInsets padding;
  final Widget child;

  const TablaAnchoCompleto({
    super.key,
    required this.controller,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: c.maxWidth - padding.horizontal),
          child: child,
        ),
      ),
    );
  }
}

/// Texto de ancho fijo para una celda de tabla: los nombres largos se cortan
/// con "…" (el texto completo sale al pasar el mouse) en vez de ensanchar la
/// columna.
class CeldaAnchoFijo extends StatelessWidget {
  final String texto;
  final double ancho;
  final TextStyle? style;

  const CeldaAnchoFijo(this.texto, {super.key, required this.ancho, this.style});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      child: Tooltip(
        message: texto,
        waitDuration: const Duration(milliseconds: 500),
        child: Text(texto, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
