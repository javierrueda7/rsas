// ignore_for_file: no_leading_underscores_for_local_identifiers

// ── Helpers de conversión (mismo patrón que catalogos.dart) ──────────────────
int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

num _toNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  return num.tryParse(v.toString()) ?? 0;
}

num? _toNumOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  return num.tryParse(v.toString());
}

String? _toTextOrNull(dynamic v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? null : s;
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

// ── Etiquetas de estado compartidas ─────────────────────────────────────────

const Map<String, String> kEstadoPagoLabels = {
  'I': 'Incompleta',
  'C': 'Completa',
  'R': 'Revisada',
  'V': 'Vencida',
  'A': 'Anulada',
};

String labelEstadoPago(String e) => kEstadoPagoLabels[e] ?? e;

// ─────────────────────────────────────────────────────────────────────────────
// ReportePago – reporte de comisiones emitido por la aseguradora
// ─────────────────────────────────────────────────────────────────────────────

class ReportePago {
  final int id;
  final DateTime fechaRep;
  final int? asegId;
  final int? intermId;
  final DateTime? finiRep;
  final DateTime? ffinRep;
  final num vlrprimaRep;
  final num vlrsumprimaRep;
  final num vlrcomRep;
  final num vlrsumcomRep;
  final String estadoRep;
  final String? obsRep;
  final int? usuarioId;
  final DateTime? fcreado;
  final DateTime? fultmod;
  // Desde vw_reportes_resumen
  final String? nombreAseg;
  final String? nombreInterm;
  final int numAbonos;

  const ReportePago({
    required this.id,
    required this.fechaRep,
    this.asegId,
    this.intermId,
    this.finiRep,
    this.ffinRep,
    this.vlrprimaRep = 0,
    this.vlrsumprimaRep = 0,
    this.vlrcomRep = 0,
    this.vlrsumcomRep = 0,
    this.estadoRep = 'I',
    this.obsRep,
    this.usuarioId,
    this.fcreado,
    this.fultmod,
    this.nombreAseg,
    this.nombreInterm,
    this.numAbonos = 0,
  });

  factory ReportePago.fromMap(Map<String, dynamic> m) => ReportePago(
        id: _toInt(m['id']),
        fechaRep: _toDate(m['fecha_rep']) ?? DateTime.now(),
        asegId: _toIntOrNull(m['aseg_id']),
        intermId: _toIntOrNull(m['interm_id']),
        finiRep: _toDate(m['fini_rep']),
        ffinRep: _toDate(m['ffin_rep']),
        vlrprimaRep: _toNum(m['vlrprima_rep']),
        vlrsumprimaRep: _toNum(m['vlrsumprima_rep']),
        vlrcomRep: _toNum(m['vlrcom_rep']),
        vlrsumcomRep: _toNum(m['vlrsumcom_rep']),
        estadoRep: (m['estado_rep'] ?? 'I').toString(),
        obsRep: _toTextOrNull(m['obs_rep']),
        usuarioId: _toIntOrNull(m['usuario_id']),
        fcreado: _toDate(m['fcreado']),
        fultmod: _toDate(m['fultmod']),
        nombreAseg: _toTextOrNull(m['nombre_aseg']),
        nombreInterm: _toTextOrNull(m['nombre_interm']),
        numAbonos: _toInt(m['num_abonos']),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// AbonoPoliza – pago individual de una póliza dentro de un reporte
// ─────────────────────────────────────────────────────────────────────────────

class AbonoPoliza {
  final int id;
  final int? idrepPago;
  final int idPoliza;
  final DateTime? fechaPago;
  final num vlrprimaPoliza;
  final num vlrabonoprima;
  final num porccomision;
  final num vlrcomision;
  final num porccomad;
  final num vlrcomad;
  final int? idfactura;
  final String? numFactura;
  final String estadoPago;
  final String? obsPago;
  final int? usuarioId;
  final DateTime? fcreado;
  final DateTime? fultmod;
  // Enriquecidos desde vw_abonos_detalle
  final String? nroPoliza;
  final num? primaPoliza;
  final String? bienAsegurado;
  final DateTime? finiPoliza;
  final DateTime? ffinPoliza;
  final String? estadoPolizaId;
  final String? nombreCliente;
  final String? docCliente;
  final String? tipodocCliente;
  final String? telCliente;
  final String? correoCliente;
  final String? dirCliente;
  final String? nombreRamo;
  final String? nombreProd;
  final String? nombreAseg;
  final String? apodoUsuario;
  final String? nombreUsuario;

  const AbonoPoliza({
    required this.id,
    this.idrepPago,
    required this.idPoliza,
    this.fechaPago,
    this.vlrprimaPoliza = 0,
    this.vlrabonoprima = 0,
    this.porccomision = 0,
    this.vlrcomision = 0,
    this.porccomad = 0,
    this.vlrcomad = 0,
    this.idfactura,
    this.numFactura,
    this.estadoPago = 'I',
    this.obsPago,
    this.usuarioId,
    this.fcreado,
    this.fultmod,
    this.nroPoliza,
    this.primaPoliza,
    this.bienAsegurado,
    this.finiPoliza,
    this.ffinPoliza,
    this.estadoPolizaId,
    this.nombreCliente,
    this.docCliente,
    this.tipodocCliente,
    this.telCliente,
    this.correoCliente,
    this.dirCliente,
    this.nombreRamo,
    this.nombreProd,
    this.nombreAseg,
    this.apodoUsuario,
    this.nombreUsuario,
  });

  factory AbonoPoliza.fromMap(Map<String, dynamic> m) => AbonoPoliza(
        id: _toInt(m['id']),
        idrepPago: _toIntOrNull(m['idrep_pago']),
        idPoliza: _toInt(m['id_poliza']),
        fechaPago: _toDate(m['fecha_pago']),
        vlrprimaPoliza: _toNum(m['vlrprima_poliza']),
        vlrabonoprima: _toNum(m['vlrabono_prima']),
        porccomision: _toNum(m['porccomision']),
        vlrcomision: _toNum(m['vlrcomision']),
        porccomad: _toNum(m['porccomad']),
        vlrcomad: _toNum(m['vlrcomad']),
        idfactura: _toIntOrNull(m['idfactura']),
        numFactura: _toTextOrNull(m['num_factura']),
        estadoPago: (m['estado_pago'] ?? 'I').toString(),
        obsPago: _toTextOrNull(m['obs_pago']),
        usuarioId: _toIntOrNull(m['usuario_id']),
        fcreado: _toDate(m['fcreado']),
        fultmod: _toDate(m['fultmod']),
        nroPoliza: _toTextOrNull(m['nro_poliza']),
        primaPoliza: _toNumOrNull(m['prima_poliza']),
        bienAsegurado: _toTextOrNull(m['bien_asegurado']),
        finiPoliza: _toDate(m['fini_poliza']),
        ffinPoliza: _toDate(m['ffin_poliza']),
        estadoPolizaId: _toTextOrNull(m['estado_poliza_id']),
        nombreCliente: _toTextOrNull(m['nombre_cliente']),
        docCliente: _toTextOrNull(m['doc_cliente']),
        tipodocCliente: _toTextOrNull(m['tipodoc_cliente']),
        telCliente: _toTextOrNull(m['tel_cliente']),
        correoCliente: _toTextOrNull(m['correo_cliente']),
        dirCliente: _toTextOrNull(m['dir_cliente']),
        nombreRamo: _toTextOrNull(m['nombre_ramo']),
        nombreProd: _toTextOrNull(m['nombre_prod']),
        nombreAseg: _toTextOrNull(m['nombre_aseg']),
        apodoUsuario: _toTextOrNull(m['apodo_usuario']),
        nombreUsuario: _toTextOrNull(m['nombre_usuario']),
      );
}
