import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Convierte texto numérico escrito en Colombia a número. Reemplaza las
/// copias que había en cada formulario, que borraban todos los puntos: así
/// "12.5" terminaba guardado como 125.
///
///   "1.234.567,89" → 1234567.89     "12,5" → 12.5      "1.500" → 1500
///   "12.5" → 12.5 (un solo punto seguido de 1 o 2 dígitos = decimal)
///   "(168.093,5)" → -168093.5       "-1.234" → -1234   "1,234,567.89" → 1234567.89
///   "$ 1.500" → 1500                "" / "-" → null
num? parseNumCO(String? texto) {
  if (texto == null) return null;
  var s = texto.trim();
  if (s.isEmpty) return null;

  var negativo = false;
  if (s.startsWith('(') && s.endsWith(')')) {
    negativo = true;
    s = s.substring(1, s.length - 1);
  }
  s = s.replaceAll(RegExp(r'[\s$%]'), '');
  if (s.startsWith('-')) {
    negativo = !negativo;
    s = s.substring(1);
  }
  s = s.replaceAll(RegExp(r'[^0-9.,]'), '');
  if (s.isEmpty) return null;

  final ultimaComa = s.lastIndexOf(',');
  final ultimoPunto = s.lastIndexOf('.');

  String normal;
  if (ultimaComa >= 0 && ultimoPunto > ultimaComa) {
    // Formato con coma de miles y punto decimal: 1,234,567.89
    normal = s.replaceAll(',', '');
  } else if (ultimaComa >= 0) {
    // Formato colombiano: punto de miles, coma decimal.
    normal = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (ultimoPunto >= 0 &&
      '.'.allMatches(s).length == 1 &&
      s.length - ultimoPunto - 1 <= 2 &&
      s.length - ultimoPunto - 1 >= 1) {
    // Un solo punto seguido de 1 o 2 dígitos: es el decimal (12.5, 100.25).
    normal = s;
  } else {
    // Puntos de miles (1.500, 1.234.567).
    normal = s.replaceAll('.', '');
  }

  final n = num.tryParse(normal);
  if (n == null) return null;
  return negativo ? -n : n;
}

String _miles(String digitos) {
  final buf = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) buf.write('.');
    buf.write(digitos[i]);
  }
  return buf.toString();
}

/// Formato de escritura para campos numéricos: puntos de miles y coma
/// decimal mientras se escribe.
///
/// - Un "." escrito al final (el punto del teclado numérico) se toma como
///   coma decimal, en vez de desaparecer.
/// - Al pegar un valor completo ("168093.5", "(168.093,5)",
///   "1,234,567.89") se interpreta con [parseNumCO].
class NumeroCOInputFormatter extends TextInputFormatter {
  final int maxDecimales;
  final bool permitirNegativos;

  const NumeroCOInputFormatter({this.maxDecimales = 2, this.permitirNegativos = true});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final anterior = oldValue;
    final nuevo = newValue;
    var t = nuevo.text;
    if (t.trim().isEmpty) return nuevo.copyWith(text: '');

    final esPegado = t.length - anterior.text.length > 1;
    if (esPegado) {
      final v = parseNumCO(t);
      if (v == null) return anterior;
      return _resultado(formatearNumCO(permitirNegativos ? v : v.abs(), maxDecimales: maxDecimales));
    }

    if (maxDecimales > 0 &&
        t.endsWith('.') &&
        !t.substring(0, t.length - 1).contains(',') &&
        t.length > anterior.text.length) {
      t = '${t.substring(0, t.length - 1)},';
    }

    final negativo = permitirNegativos && (t.trimLeft().startsWith('-') || t.trimLeft().startsWith('('));
    final partes = t.replaceAll(RegExp(r'[^0-9,]'), '').split(',');
    final entero = partes[0].replaceFirst(RegExp(r'^0+(?=\d)'), '');
    var fmt = '${negativo ? '-' : ''}${_miles(entero)}';
    if (partes.length > 1 && maxDecimales > 0) {
      final dec = partes.sublist(1).join();
      fmt += ',${dec.substring(0, math.min(dec.length, maxDecimales))}';
    }
    return _resultado(fmt);
  }

  TextEditingValue _resultado(String texto) => TextEditingValue(
        text: texto,
        selection: TextSelection.collapsed(offset: texto.length),
      );
}

/// Número a texto colombiano para un campo editable: puntos de miles, coma
/// decimal y solo los decimales que hacen falta (1500 → "1.500",
/// 12.5 → "12,5", 33.333 → "33,333" con maxDecimales 5).
String formatearNumCO(num? n, {int maxDecimales = 2}) {
  if (n == null) return '';
  final negativo = n < 0;
  final abs = n.abs();
  var texto = abs.toStringAsFixed(maxDecimales);
  var entero = texto;
  var dec = '';
  final punto = texto.indexOf('.');
  if (punto >= 0) {
    entero = texto.substring(0, punto);
    dec = texto.substring(punto + 1).replaceFirst(RegExp(r'0+$'), '');
  }
  texto = _miles(entero);
  if (dec.isNotEmpty) texto += ',$dec';
  return negativo && (entero != '0' || dec.isNotEmpty) ? '-$texto' : texto;
}

/// Suma exacta de valores monetarios: los acumula en centavos enteros. Con
/// doubles, 10 cuotas de 100.000,10 suman 1.000.000,9999999 y la póliza de
/// prima 1.000.001 "nunca" se completaba.
num sumarDinero(Iterable<num> valores) {
  var centavos = 0;
  for (final v in valores) {
    centavos += (v * 100).round();
  }
  return centavos / 100;
}
