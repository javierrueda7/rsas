import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tema visual de SegurApp, derivado de la paleta del logo
/// (Rueda Serrano Asesores de Seguros): navy + verde sobre blanco.
class AppTheme {
  AppTheme._();

  // ── Paleta de marca ──────────────────────────────────────────────────
  static const Color navy = Color(0xFF1C4870);
  static const Color navyDark = Color(0xFF123553);
  static const Color green = Color(0xFF1E9B4E);
  static const Color greenLight = Color(0xFF2FB05F);
  static const Color warning = Color(0xFFB7791B);
  static const Color warningContainer = Color(0xFFF3E4C4);
  static const Color onWarningContainer = Color(0xFF6B4E14);
  static const Color danger = Color(0xFFA6402C);

  static const Color background = Color(0xFFF5F7F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceContainerHighest = Color(0xFFE7ECF1);
  static const Color outlineVariant = Color(0xFFD7DEE5);
  static const Color ink = Color(0xFF1B2430);
  static const Color inkSoft = Color(0xFF5B6675);

  /// Nombre de familia de la mono, para usar en `TextStyle(fontFamily: ...)`
  /// donde ya existe un estilo armado y solo se quiere cambiar la tipografía.
  static String get monoFamily => GoogleFonts.jetBrainsMono().fontFamily!;

  /// Tipografía monoespaciada para cifras alineadas en tablas
  /// (primas, valores, fechas, número de póliza).
  static TextStyle mono({double fontSize = 13, FontWeight? fontWeight, Color? color}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static ThemeData light() {
    const cs = ColorScheme.light(
      primary: navy,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDCE6EE),
      onPrimaryContainer: navyDark,
      secondary: green,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFDCF0E2),
      onSecondaryContainer: Color(0xFF11512A),
      tertiary: greenLight,
      onTertiary: Colors.white,
      error: danger,
      onError: Colors.white,
      errorContainer: Color(0xFFF3DED8),
      onErrorContainer: danger,
      surface: surface,
      onSurface: ink,
      surfaceContainerHighest: surfaceContainerHighest,
      onSurfaceVariant: inkSoft,
      outline: Color(0xFFA9B4BF),
      outlineVariant: outlineVariant,
      inverseSurface: ink,
      onInverseSurface: Colors.white,
    );

    final baseText = GoogleFonts.plusJakartaSansTextTheme();
    final textTheme = baseText.copyWith(
      titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface),
      titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface),
      bodyLarge: baseText.bodyLarge?.copyWith(color: cs.onSurface),
      bodyMedium: baseText.bodyMedium?.copyWith(color: cs.onSurface),
      bodySmall: baseText.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );

    final radius10 = BorderRadius.circular(10);
    final radius12 = BorderRadius.circular(12);
    final outlineSide = const BorderSide(color: outlineVariant);

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      fontFamily: textTheme.bodyMedium?.fontFamily,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium,
      ),

      cardTheme: CardTheme(
        elevation: 0,
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: radius12, side: outlineSide),
      ),

      dividerTheme: const DividerThemeData(color: outlineVariant, thickness: 1, space: 1),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: radius10, borderSide: outlineSide),
        enabledBorder: OutlineInputBorder(borderRadius: radius10, borderSide: outlineSide),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius10,
          borderSide: BorderSide(color: cs.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(borderRadius: radius10, borderSide: BorderSide(color: cs.error)),
        labelStyle: TextStyle(color: cs.onSurfaceVariant),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: radius10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: radius10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.outline),
          shape: RoundedRectangleBorder(borderRadius: radius10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          shape: RoundedRectangleBorder(borderRadius: radius10),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHighest,
        labelStyle: TextStyle(color: cs.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),

      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(cs.surfaceContainerHighest),
        headingTextStyle: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 12),
        dataTextStyle: TextStyle(color: cs.onSurface, fontSize: 13),
        dividerThickness: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(color: cs.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: cs.primary),
      iconTheme: IconThemeData(color: cs.onSurfaceVariant),
    );
  }
}
