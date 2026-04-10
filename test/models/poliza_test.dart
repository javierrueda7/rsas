import 'package:flutter_test/flutter_test.dart';
import 'package:seguimiento_polizas/datos/poliza.dart';

void main() {
  group('Poliza.fromMap', () {
    final mapCompleto = {
      'id': 100,
      'nro_poliza': 'POL-2024-001',
      'cliente_id': 10,
      'asesor_id': 2,
      'ramo_id': 7,
      'producto_id': 15,
      'fexp_poliza': '2024-01-15',
      'fini_poliza': '2024-02-01',
      'ffin_poliza': '2025-02-01',
      'prima_poliza': 1200000,
      'valor_poliza': 50000000,
      'bien_asegurado': 'Vehículo Toyota',
      'obs_poliza': 'Sin novedad',
      'vlraseg_poliza': 45000000,
      'porccom_poliza': 12.5,
      'vlrbasecom_poliza': 1000000,
      'intermediario_id': null,
      'porcom_agencia': null,
      'vlrcom_poliza': 125000,
      'vlrcomfija_poliza': null,
      'porcomadic_poliza': null,
      'vlrcomadic_poliza': null,
      'porcom_asesor1': 12.5,
      'agencia_id': null,
      'forma_pago_id': 1,
      'estado_poliza_id': 'VIG',
      'vlrprimapagada_poliza': 1200000,
      'asesor2_id': null,
      'asesor3_id': null,
      'asesorad_id': null,
      'agenciaad_id': null,
      'formaexp_id': null,
      'aseg_id': 3,
      'usuario_id': 1,
      'fcreado': '2024-01-15T10:00:00',
      'fultmod': '2024-01-20T15:30:00',
      'nombre_cliente': 'Juan García',
      'doc_cliente': '1234567',
      'nombre_asesor': 'Pedro López',
      'nombre_ramo': 'Automóviles',
      'nombre_prod': 'Todo Riesgo',
      'nombre_aseg': 'Sura',
      'nombre_interm': null,
      'nombre_forma_pago': 'Anual',
      'nombre_formaexp': null,
      'nombre_usuario': 'Admin',
      'apodo_usuario': 'adm',
    };

    test('parsea campos requeridos correctamente', () {
      final p = Poliza.fromMap(mapCompleto);

      expect(p.id, 100);
      expect(p.nroPoliza, 'POL-2024-001');
      expect(p.primaPoliza, 1200000);
      expect(p.valorPoliza, 50000000);
    });

    test('parsea IDs foráneos', () {
      final p = Poliza.fromMap(mapCompleto);

      expect(p.clienteId, 10);
      expect(p.asesorId, 2);
      expect(p.ramoId, 7);
      expect(p.productoId, 15);
      expect(p.formaPagoId, 1);
    });

    test('parsea fechas correctamente', () {
      final p = Poliza.fromMap(mapCompleto);

      expect(p.finiPoliza, DateTime(2024, 2, 1));
      expect(p.ffinPoliza, DateTime(2025, 2, 1));
      expect(p.fcreado?.year, 2024);
    });

    test('parsea campos de join (vista)', () {
      final p = Poliza.fromMap(mapCompleto);

      expect(p.nombreCliente, 'Juan García');
      expect(p.docCliente, '1234567');
      expect(p.nombreAsesor, 'Pedro López');
      expect(p.nombreRamo, 'Automóviles');
      expect(p.nombreProd, 'Todo Riesgo');
      expect(p.nombreAseg, 'Sura');
    });

    test('IDs foráneos nulos cuando vienen null', () {
      final p = Poliza.fromMap(mapCompleto);

      expect(p.intermediarioId, isNull);
      expect(p.agenciaId, isNull);
      expect(p.asesor2Id, isNull);
    });

    test('campos de texto vacío devuelven null', () {
      final p = Poliza.fromMap({
        ...mapCompleto,
        'nro_poliza': '   ',
        'bien_asegurado': '',
        'obs_poliza': '  ',
      });

      expect(p.nroPoliza, isNull);
      expect(p.bienAsegurado, isNull);
      expect(p.obsPoliza, isNull);
    });

    test('prima y valor default a 0 cuando son null', () {
      final p = Poliza.fromMap({
        'id': 1,
        'prima_poliza': null,
        'valor_poliza': null,
      });

      expect(p.primaPoliza, 0);
      expect(p.valorPoliza, 0);
    });

    test('id desde string numérico', () {
      final p = Poliza.fromMap({
        'id': '99',
        'prima_poliza': 0,
        'valor_poliza': 0,
      });

      expect(p.id, 99);
    });

    test('prima acepta string con coma decimal', () {
      final p = Poliza.fromMap({
        'id': 1,
        'prima_poliza': '1200,50',
        'valor_poliza': 0,
      });

      expect(p.primaPoliza, 1200.50);
    });

    test('toInsertMap incluye todos los campos operacionales', () {
      final p = Poliza.fromMap(mapCompleto);
      final m = p.toInsertMap();

      expect(m['nro_poliza'], 'POL-2024-001');
      expect(m['prima_poliza'], 1200000);
      expect(m['valor_poliza'], 50000000);
      expect(m['estado_poliza_id'], 'VIG');
      // fechas como ISO string
      expect(m['fini_poliza'], '2024-02-01T00:00:00.000');
    });

    test('fechas null en toInsertMap permanecen null', () {
      final p = Poliza.fromMap({
        'id': 1,
        'prima_poliza': 0,
        'valor_poliza': 0,
      });
      final m = p.toInsertMap();

      expect(m['fexp_poliza'], isNull);
      expect(m['fini_poliza'], isNull);
      expect(m['ffin_poliza'], isNull);
    });
  });

  group('Poliza — ordenación', () {
    final lista = [
      Poliza(id: 3, primaPoliza: 500, valorPoliza: 0, ffinPoliza: DateTime(2025, 6, 1)),
      Poliza(id: 1, primaPoliza: 1500, valorPoliza: 0, ffinPoliza: DateTime(2024, 1, 1)),
      Poliza(id: 2, primaPoliza: 1000, valorPoliza: 0, ffinPoliza: DateTime(2026, 3, 1)),
    ];

    test('ordenar por id ascendente', () {
      final sorted = [...lista]..sort((a, b) => a.id.compareTo(b.id));
      expect(sorted.map((p) => p.id).toList(), [1, 2, 3]);
    });

    test('ordenar por prima descendente', () {
      final sorted = [...lista]
        ..sort((a, b) => b.primaPoliza.compareTo(a.primaPoliza));
      expect(sorted.map((p) => p.primaPoliza).toList(), [1500, 1000, 500]);
    });

    test('ordenar por fecha de vencimiento ascendente', () {
      final sorted = [...lista]
        ..sort((a, b) {
          final da = a.ffinPoliza ?? DateTime(9999);
          final db = b.ffinPoliza ?? DateTime(9999);
          return da.compareTo(db);
        });
      expect(sorted.map((p) => p.ffinPoliza?.year).toList(), [2024, 2025, 2026]);
    });
  });
}
