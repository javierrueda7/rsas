import 'package:flutter_test/flutter_test.dart';
import 'package:seguimiento_polizas/utils/numeros_co.dart';

void main() {
  group('parseNumCO', () {
    test('formato colombiano', () {
      expect(parseNumCO('1.234.567,89'), 1234567.89);
      expect(parseNumCO('12,5'), 12.5);
      expect(parseNumCO('1.500'), 1500);
      expect(parseNumCO('815.175'), 815175);
    });
    test('un solo punto con 1-2 decimales es decimal (antes 12.5 → 125)', () {
      expect(parseNumCO('12.5'), 12.5);
      expect(parseNumCO('168093.5'), 168093.5);
      expect(parseNumCO('100.25'), 100.25);
    });
    test('negativos con signo o entre paréntesis', () {
      expect(parseNumCO('-1.234'), -1234);
      expect(parseNumCO('(168.093,5)'), -168093.5);
      expect(parseNumCO('-12,5'), -12.5);
    });
    test('formato con coma de miles y punto decimal', () {
      expect(parseNumCO('1,234,567.89'), 1234567.89);
    });
    test('símbolos y vacíos', () {
      expect(parseNumCO(r'$ 1.500'), 1500);
      expect(parseNumCO('35%'), 35);
      expect(parseNumCO(''), isNull);
      expect(parseNumCO('-'), isNull);
      expect(parseNumCO(null), isNull);
    });
  });

  group('formatearNumCO', () {
    test('miles y decimales justos', () {
      expect(formatearNumCO(1500), '1.500');
      expect(formatearNumCO(12.5), '12,5');
      expect(formatearNumCO(1234567.891), '1.234.567,89');
      expect(formatearNumCO(33.33333, maxDecimales: 5), '33,33333');
      expect(formatearNumCO(-168093.5), '-168.093,5');
      expect(formatearNumCO(0), '0');
    });
    test('ida y vuelta sin perder valor', () {
      for (final v in [0.5, 12.5, 1500, 1234567.89, -168093.5, 33.333]) {
        expect(parseNumCO(formatearNumCO(v, maxDecimales: 5)), v);
      }
    });
  });

  group('sumarDinero', () {
    test('sin error de redondeo de doubles', () {
      final cuotas = List.filled(10, 100000.10);
      expect(cuotas.fold<double>(0, (s, v) => s + v) >= 1000001, isFalse);
      expect(sumarDinero(cuotas), 1000001);
    });
  });

  group('NumeroCOInputFormatter', () {
    const f = NumeroCOInputFormatter();
    TextEditingValue tipear(String antes, String despues) => f.formatEditUpdate(
          TextEditingValue(text: antes),
          TextEditingValue(text: despues),
        );

    test('agrega puntos de miles', () {
      expect(tipear('123', '1234').text, '1.234');
    });
    test('el punto del teclado numérico se vuelve coma decimal', () {
      expect(tipear('12', '12.').text, '12,');
      expect(tipear('12,', '12,5').text, '12,5');
    });
    test('pegar valores completos los interpreta bien', () {
      expect(tipear('', '168093.5').text, '168.093,5');
      expect(tipear('', '(168.093,5)').text, '-168.093,5');
      expect(tipear('', '1,234,567.89').text, '1.234.567,89');
    });
    test('respeta el máximo de decimales', () {
      expect(tipear('1,23', '1,234').text, '1,23');
    });
  });
}
