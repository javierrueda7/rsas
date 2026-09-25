import 'package:flutter_test/flutter_test.dart';
import 'package:seguimiento_polizas/datos/matching_reporte_pago.dart';
import 'package:seguimiento_polizas/datos/poliza.dart';

Poliza _p(int id, String nro, {String doc = '900159756', int aseg = 1, num prima = 100}) =>
    Poliza(id: id, nroPoliza: nro, docCliente: doc, asegId: aseg, primaPoliza: prima, valorPoliza: prima);

void main() {
  group('anexoSiCorresponde', () {
    test('segmento exacto devuelve el anexo registrado', () {
      expect(anexoSiCorresponde('400-97-994000000046-6', '994000000046'), '6');
      expect(anexoSiCorresponde('994000000046-0', '994000000046'), '0');
    });
    test('no matchea por "contiene"', () {
      expect(anexoSiCorresponde('994000000047-0', '994000000046'), isNull);
      expect(anexoSiCorresponde('1994000000046-0', '994000000046'), isNull);
      expect(anexoSiCorresponde('101010543-5', '10543'), isNull);
    });
    test('ignora ceros a la izquierda', () {
      expect(anexoSiCorresponde('0994000000046-00', '994000000046'), '0');
    });
    test('póliza registrada sin anexo', () {
      expect(anexoSiCorresponde('B-100071475', '100071475'), '');
      expect(anexoSiCorresponde('100071475', '100071475'), '');
    });
    test('núcleo y anexo pegados en pólizas viejas', () {
      expect(anexoSiCorresponde('9940000001936', '994000000193', anexoReporte: '6'), '6');
      expect(anexoSiCorresponde('9940000001936', '994000000193', anexoReporte: '5'), isNull);
    });
  });

  group('resolverMatch — casos del reporte de Solidaria (FUNDACION COLOMBIA COLLEGE)', () {
    // En la base solo existe la …046 anexo 0.
    final base = [_p(1, '994000000046-0')];

    test('046 anexo 0 → exacta', () {
      final r = resolverMatch(nucleo: '994000000046', anexo: '0', docCliente: '900159756', candidatos: base);
      expect(r.estado, EstadoMatch.exacta);
      expect(r.poliza!.id, 1);
      expect(r.seIncluyeSolo, isTrue);
    });
    test('046 anexo 6 → anexo no registrado, sin asignar', () {
      final r = resolverMatch(nucleo: '994000000046', anexo: '6', docCliente: '900159756', candidatos: base);
      expect(r.estado, EstadoMatch.anexoNoRegistrado);
      expect(r.poliza, isNull);
      expect(r.candidatos.map((p) => p.id), [1]);
    });
    test('047 (otra póliza del mismo cliente) → no encontrada, NO se asigna la única del cliente', () {
      final r = resolverMatch(
          nucleo: '994000000047', anexo: '0', docCliente: '900159756', candidatos: base, polizasDelCliente: base);
      expect(r.estado, EstadoMatch.noEncontrada);
      expect(r.poliza, isNull);
      expect(r.candidatos.map((p) => p.id), [1]);
    });
  });

  group('resolverMatch — varios anexos registrados', () {
    final base = [_p(1, '101003571-0'), _p(2, '101003571-1'), _p(3, '101003572-0')];

    test('elige el anexo exacto', () {
      final r = resolverMatch(nucleo: '101003571', anexo: '1', docCliente: '900159756', candidatos: base);
      expect(r.estado, EstadoMatch.exacta);
      expect(r.poliza!.id, 2);
    });
    test('sin anexo en el reporte y varias → ambigua, ordenada por prima más cercana', () {
      final ps = [_p(1, '100078459-0', prima: 500), _p(2, '100078459-1', prima: 1582395)];
      final r = resolverMatch(nucleo: '100078459', candidatos: ps, primaLinea: 1582395);
      expect(r.estado, EstadoMatch.ambigua);
      expect(r.poliza, isNull);
      expect(r.candidatos.first.id, 2);
    });
    test('sin anexo en el reporte y una sola → única', () {
      final r = resolverMatch(nucleo: '100022101', candidatos: [_p(9, '100022101-0', doc: '91078726')], docCliente: '91078726');
      expect(r.estado, EstadoMatch.unicaSinAnexo);
      expect(r.poliza!.id, 9);
    });
    test('mismo número+anexo registrado dos veces → ambigua', () {
      final r = resolverMatch(nucleo: '105005925', anexo: '0', candidatos: [_p(1, '105005925-0'), _p(2, '105005925-0')]);
      expect(r.estado, EstadoMatch.ambigua);
    });
  });

  group('resolverMatch — verificaciones de seguridad', () {
    test('documento distinto → revisar (asignada pero no se incluye sola)', () {
      final r = resolverMatch(
          nucleo: '101011263', anexo: '1', docCliente: '1098633206', candidatos: [_p(1, '101011263-1', doc: '999')]);
      expect(r.estado, EstadoMatch.revisar);
      expect(r.poliza!.id, 1);
      expect(r.seIncluyeSolo, isFalse);
    });
    test('documento con puntos se compara normalizado', () {
      final r = resolverMatch(
          nucleo: '101011263', anexo: '1', docCliente: '1.098.633.206', candidatos: [_p(1, '101011263-1', doc: '1098633206')]);
      expect(r.estado, EstadoMatch.exacta);
    });
    test('otra aseguradora con el mismo número se descarta', () {
      final r = resolverMatch(
          nucleo: '101011263', anexo: '1', aseguradoraId: 1, candidatos: [_p(1, '101011263-1', aseg: 2)]);
      expect(r.estado, EstadoMatch.noEncontrada);
    });
    test('póliza registrada sin anexo y reporte con anexo → revisar', () {
      final r = resolverMatch(nucleo: '100071475', anexo: '3', candidatos: [_p(1, 'B-100071475')]);
      expect(r.estado, EstadoMatch.revisar);
      expect(r.seIncluyeSolo, isFalse);
    });
    test('candidatos repetidos no generan falsa ambigüedad', () {
      final p = _p(1, '994000000193-6');
      final r = resolverMatch(nucleo: '994000000193', anexo: '6', candidatos: [p, p]);
      expect(r.estado, EstadoMatch.exacta);
    });
  });

  group('ajustes de la revisión', () {
    test('número y anexo pegados nunca es exacta', () {
      final r = resolverMatch(nucleo: '100071475', anexo: '1', candidatos: [_p(1, '1000714751')]);
      expect(r.estado, EstadoMatch.revisar);
      expect(r.seIncluyeSolo, isFalse);
    });
    test('número muy corto solo coincide con el número completo', () {
      expect(anexoSiCorresponde('400-97-994000000046-6', '97'), isNull);
      expect(anexoSiCorresponde('400-97-994000000046-6', '400'), isNull);
      expect(anexoSiCorresponde('97', '97'), '');
    });
    test('segmento con letras pegadas', () {
      expect(anexoSiCorresponde('AUT12345-1', '12345'), '1');
    });
    test('documento con o sin dígito de verificación', () {
      expect(mismoDocumento('900159756', '900159756-1'), isTrue);
      expect(mismoDocumento('900159756', '900159757'), isFalse);
      final r = resolverMatch(
          nucleo: '994000000046', anexo: '0', docCliente: '900159756', candidatos: [_p(1, '994000000046-0', doc: '900159756-1')]);
      expect(r.estado, EstadoMatch.exacta);
    });
  });
}
