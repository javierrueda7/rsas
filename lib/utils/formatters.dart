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
}