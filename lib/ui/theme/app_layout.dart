import 'package:flutter/material.dart';

/// Constantes de espaciado y geometría compartidas por toda la app,
/// para que cada pantalla deje de improvisar su propio margen/padding.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class AppLayout {
  AppLayout._();

  /// Padding único para el cuerpo de cualquier pantalla.
  static const EdgeInsets pagePadding =
      EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl);

  /// Geometría común para chips hechos a mano (presets, toggles de estado).
  static const EdgeInsets chipPadding =
      EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6);
  static const OutlinedBorder chipShape = StadiumBorder();

  /// Ancho máximo para pantallas tipo dashboard/lista (no tablas anchas de
  /// muchas columnas) — se centran en vez de estirarse en monitores anchos.
  static const double maxContentWidth = 1200;

  /// Envuelve [child] centrado con [maxContentWidth] como ancho máximo.
  static Widget centered(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}
