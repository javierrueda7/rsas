import 'package:intl/intl.dart';

class Fmt {
  // Colombia: 1.234.567,89
  static final NumberFormat moneyCO = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '',
    decimalDigits: 0, // cambia a 2 si quieres decimales
  );

  // Porcentaje: 10 -> "10%" (sin decimales)
  static final NumberFormat percentCO = NumberFormat.decimalPattern('es_CO');

  static String numCO(num? n, {int dec = 0}) {
    if (n == null) return '';
    final f = NumberFormat.decimalPattern('es_CO')
      ..minimumFractionDigits = dec
      ..maximumFractionDigits = dec;
    return f.format(n);
  }

  static String money(num? n, {int dec = 0}) {
    if (n == null) return '';
    final f = NumberFormat.currency(locale: 'es_CO', symbol: '')
      ..minimumFractionDigits = dec
      ..maximumFractionDigits = dec;
    return f.format(n).trim();
  }

  static String percent(num? n, {int dec = 0}) {
    if (n == null) return '';
    final f = NumberFormat.decimalPattern('es_CO')
      ..minimumFractionDigits = dec
      ..maximumFractionDigits = dec;
    return '${f.format(n)}%';
  }

  /// Documento de identidad: se guarda sin puntos ("9002278851" o
  /// "900227885-1"), acá solo se le agregan para mostrarlo — "900.227.885-1".
  /// Si trae un guion (dígito de verificación de NIT) se agrupa la parte de
  /// antes y se deja el sufijo tal cual.
  static String doc(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return s;
    final guion = s.indexOf('-');
    final numero = guion == -1 ? s : s.substring(0, guion);
    final sufijo = guion == -1 ? '' : s.substring(guion);
    if (!RegExp(r'^\d+$').hasMatch(numero)) return s;
    final buffer = StringBuffer();
    for (var i = 0; i < numero.length; i++) {
      if (i > 0 && (numero.length - i) % 3 == 0) buffer.write('.');
      buffer.write(numero[i]);
    }
    return '$buffer$sufijo';
  }
}