import 'package:flutter_test/flutter_test.dart';
import 'package:seguimiento_polizas/datos/catalogos.dart';

void main() {
  // ─── Cliente ──────────────────────────────────────────────────────────────

  group('Cliente.fromMap', () {
    test('parsea todos los campos correctamente', () {
      final c = Cliente.fromMap({
        'id': 1,
        'nombre_cliente': 'Juan Pérez',
        'tipopers_cliente': 'N',
        'tipodoc_cliente': 'CC',
        'doc_cliente': '12345678',
        'tel_cliente': '3001234567',
        'correo_cliente': 'juan@example.com',
        'dir_cliente': 'Calle 1 # 2-3',
        'munic_id': 5001,
        'notas_cliente': 'Nota de prueba',
        'contacto_cliente': 'María',
        'cargocont_cliente': 'Gerente',
        'asesor_id': 2,
        'estado_cliente': true,
        'recordar_cliente': false,
      });

      expect(c.id, 1);
      expect(c.nombreCliente, 'Juan Pérez');
      expect(c.tipopersCliente, 'N');
      expect(c.tipodocCliente, 'CC');
      expect(c.docCliente, '12345678');
      expect(c.telCliente, '3001234567');
      expect(c.correoCliente, 'juan@example.com');
      expect(c.dirCliente, 'Calle 1 # 2-3');
      expect(c.municId, 5001);
      expect(c.notasCliente, 'Nota de prueba');
      expect(c.contactoCliente, 'María');
      expect(c.cargocontCliente, 'Gerente');
      expect(c.asesorId, 2);
      expect(c.estadoCliente, isTrue);
      expect(c.recordarCliente, isFalse);
    });

    test('campos opcionales nulos cuando no están presentes', () {
      final c = Cliente.fromMap({
        'id': 5,
        'nombre_cliente': 'Sin datos',
        'tipopers_cliente': 'J',
      });

      expect(c.tipodocCliente, isNull);
      expect(c.docCliente, isNull);
      expect(c.telCliente, isNull);
      expect(c.correoCliente, isNull);
      expect(c.municId, isNull);
      expect(c.asesorId, isNull);
      expect(c.estadoCliente, isTrue); // fallback = true
    });

    test('id desde string numérico', () {
      final c = Cliente.fromMap({
        'id': '42',
        'nombre_cliente': 'Test',
        'tipopers_cliente': 'N',
      });
      expect(c.id, 42);
    });

    test('estado desde int 0 = false', () {
      final c = Cliente.fromMap({
        'id': 1,
        'nombre_cliente': 'Test',
        'tipopers_cliente': 'N',
        'estado_cliente': 0,
      });
      expect(c.estadoCliente, isFalse);
    });

    test('estado desde int 1 = true', () {
      final c = Cliente.fromMap({
        'id': 1,
        'nombre_cliente': 'Test',
        'tipopers_cliente': 'N',
        'estado_cliente': 1,
      });
      expect(c.estadoCliente, isTrue);
    });

    test('nombreMunicipio desde join anidado', () {
      final c = Cliente.fromMap({
        'id': 1,
        'nombre_cliente': 'Test',
        'tipopers_cliente': 'N',
        'municipio': {'nombre_munic': 'Medellín'},
      });
      expect(c.nombreMunicipio, 'Medellín');
    });

    test('toInsertMap incluye todos los campos esperados', () {
      final c = Cliente(
        id: 1,
        nombreCliente: 'Juan',
        tipopersCliente: 'N',
        docCliente: '111',
        estadoCliente: true,
        recordarCliente: false,
      );
      final m = c.toInsertMap();
      expect(m['nombre_cliente'], 'Juan');
      expect(m['tipopers_cliente'], 'N');
      expect(m['estado_cliente'], isTrue);
      expect(m.containsKey('id'), isFalse); // insert no lleva id
    });
  });

  // ─── Asesor ───────────────────────────────────────────────────────────────

  group('Asesor.fromMap', () {
    test('parsea todos los campos', () {
      final a = Asesor.fromMap({
        'id': 10,
        'nombre_asesor': 'Pedro López',
        'tipodoc_asesor': 'CC',
        'doc_asesor': '9876543',
        'tel_asesor': '310',
        'correo_asesor': 'pedro@test.com',
        'porccom_asesor': 15.5,
        'estado_asesor': true,
      });

      expect(a.id, 10);
      expect(a.nombreAsesor, 'Pedro López');
      expect(a.tipodocAsesor, 'CC');
      expect(a.porccomAsesor, 15.5);
      expect(a.estadoAsesor, isTrue);
    });

    test('porccom desde string numérico', () {
      final a = Asesor.fromMap({
        'id': 1,
        'nombre_asesor': 'Test',
        'porccom_asesor': '20',
      });
      expect(a.porccomAsesor, 20);
    });

    test('porccom null cuando no viene', () {
      final a = Asesor.fromMap({'id': 1, 'nombre_asesor': 'Test'});
      expect(a.porccomAsesor, isNull);
    });

    test('estadoAsesor fallback = true cuando es null', () {
      final a = Asesor.fromMap({'id': 1, 'nombre_asesor': 'Test'});
      expect(a.estadoAsesor, isTrue);
    });

    test('toInsertMap no incluye id', () {
      final a = Asesor(id: 1, nombreAsesor: 'Test', estadoAsesor: true);
      final m = a.toInsertMap();
      expect(m['nombre_asesor'], 'Test');
      expect(m.containsKey('id'), isFalse);
    });
  });

  // ─── Aseguradora ──────────────────────────────────────────────────────────

  group('Aseguradora.fromMap', () {
    test('parsea todos los campos', () {
      final a = Aseguradora.fromMap({
        'id': 3,
        'nombre_aseg': 'Sura',
        'nit_aseg': '890123456-7',
        'clave': 'sura2024',
        'estado_aseg': true,
      });

      expect(a.id, 3);
      expect(a.nombreAseg, 'Sura');
      expect(a.nitAseg, '890123456-7');
      expect(a.clave, 'sura2024');
      expect(a.estadoAseg, isTrue);
    });

    test('campos opcionales nulos', () {
      final a = Aseguradora.fromMap({'id': 1, 'nombre_aseg': 'Test'});
      expect(a.nitAseg, isNull);
      expect(a.clave, isNull);
      expect(a.estadoAseg, isTrue);
    });

    test('estado = false cuando viene false', () {
      final a = Aseguradora.fromMap({
        'id': 1,
        'nombre_aseg': 'Test',
        'estado_aseg': false,
      });
      expect(a.estadoAseg, isFalse);
    });

    test('toInsertMap estructura correcta', () {
      final a = Aseguradora(id: 1, nombreAseg: 'Test', nitAseg: '123');
      final m = a.toInsertMap();
      expect(m['nombre_aseg'], 'Test');
      expect(m['nit_aseg'], '123');
      expect(m.containsKey('id'), isFalse);
    });
  });

  // ─── Ramo ─────────────────────────────────────────────────────────────────

  group('Ramo.fromMap', () {
    test('parsea todos los campos', () {
      final r = Ramo.fromMap({
        'id': 7,
        'nombre_ramo': 'Vida',
        'estado_ramo': true,
        'obs_ramo': 'Observación',
        'porcom_base_ramo': 80,
      });

      expect(r.id, 7);
      expect(r.nombreRamo, 'Vida');
      expect(r.estadoRamo, isTrue);
      expect(r.obsRamo, 'Observación');
      expect(r.porcomBaseRamo, 80);
    });

    test('porcomBaseRamo default = 100 cuando es null', () {
      final r = Ramo.fromMap({'id': 1, 'nombre_ramo': 'Test'});
      expect(r.porcomBaseRamo, 100);
    });

    test('obsRamo null cuando no viene', () {
      final r = Ramo.fromMap({'id': 1, 'nombre_ramo': 'Test'});
      expect(r.obsRamo, isNull);
    });

    test('porcomBaseRamo desde string', () {
      final r = Ramo.fromMap({
        'id': 1,
        'nombre_ramo': 'Test',
        'porcom_base_ramo': '75',
      });
      expect(r.porcomBaseRamo, 75);
    });

    test('toInsertMap — obs vacía se guarda como null', () {
      final r = Ramo(id: 1, nombreRamo: 'Test', obsRamo: '   ');
      final m = r.toInsertMap();
      expect(m['obs_ramo'], isNull);
    });

    test('toInsertMap — obs con contenido se guarda trimmed', () {
      final r = Ramo(id: 1, nombreRamo: 'Test', obsRamo: '  Algo  ');
      final m = r.toInsertMap();
      expect(m['obs_ramo'], 'Algo');
    });
  });

  // ─── Producto ─────────────────────────────────────────────────────────────

  group('Producto.fromMap', () {
    test('parsea todos los campos', () {
      final p = Producto.fromMap({
        'id': 15,
        'nombre_prod': 'Vida Individual',
        'ramo_id': 7,
        'aseguradora_id': 3,
        'estado_prod': true,
        'vlrfijocom_prod': 50000,
        'porccom_prod': 12.5,
        'desc_prod': 'Descripción',
        'porcad_prod': 2.0,
        'obs_prod': 'Obs',
      });

      expect(p.id, 15);
      expect(p.nombreProd, 'Vida Individual');
      expect(p.ramoId, 7);
      expect(p.aseguradoraId, 3);
      expect(p.estadoProd, isTrue);
      expect(p.comisionProd, 50000);
      expect(p.porcomProd, 12.5);
      expect(p.descProd, 'Descripción');
      expect(p.porcadProd, 2.0);
      expect(p.obsProd, 'Obs');
    });

    test('campos de comisión son null cuando no vienen', () {
      final p = Producto.fromMap({
        'id': 1,
        'nombre_prod': 'Test',
        'ramo_id': 1,
        'aseguradora_id': 1,
      });

      expect(p.comisionProd, isNull);
      expect(p.porcomProd, isNull);
      expect(p.porcadProd, isNull);
    });

    test('desc_prod vacío se convierte a null', () {
      final p = Producto.fromMap({
        'id': 1,
        'nombre_prod': 'Test',
        'ramo_id': 1,
        'aseguradora_id': 1,
        'desc_prod': '   ',
      });
      expect(p.descProd, isNull);
    });

    test('toInsertMap usa claves correctas de BD', () {
      final p = Producto(
        id: 1,
        nombreProd: 'Test',
        ramoId: 2,
        aseguradoraId: 3,
        comisionProd: 100,
        porcomProd: 10,
      );
      final m = p.toInsertMap();
      expect(m['nombre_prod'], 'Test');
      expect(m['ramo_id'], 2);
      expect(m['aseguradora_id'], 3);
      expect(m['vlrfijocom_prod'], 100); // nombre diferente en BD
      expect(m['porccom_prod'], 10);
    });
  });

  // ─── Municipio ────────────────────────────────────────────────────────────

  group('Municipio.fromMap', () {
    test('parsea id y nombre', () {
      final m = Municipio.fromMap({'id': 5001, 'nombre_munic': 'Medellín'});
      expect(m.id, 5001);
      expect(m.nombreMunic, 'Medellín');
    });

    test('nombre vacío si no viene', () {
      final m = Municipio.fromMap({'id': 1});
      expect(m.nombreMunic, '');
    });
  });
}
