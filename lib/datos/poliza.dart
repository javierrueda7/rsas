// ignore_for_file: no_leading_underscores_for_local_identifiers

class Poliza {
  final int id;
  final String? nroPoliza;

  final int? clienteId;
  final int? asesorId;
  final int? ramoId;
  final int? productoId;

  final DateTime? fexpPoliza;
  final DateTime? finiPoliza;
  final DateTime? ffinPoliza;

  final num primaPoliza;
  final num valorPoliza;

  final String? bienAsegurado;
  final String? obsPoliza;

  final num? vlrasegPoliza;
  final num? porccomPoliza;
  final num? vlrbasecomPoliza;

  final int? intermediarioId;
  final num? porcomAgencia;
  final num? vlrcomPoliza;
  final num? vlrcomfijaPoliza;
  final num? porcomadicPoliza;
  final num? vlrcomadicPoliza;
  final num? porcomAsesor1;
  final num? porcomAsesor2;
  final num? porcomAsesor3;
  final num? porcomAsesorad;
  final num? porcomAgenciaad;

  final int? agenciaId;
  final int? formaPagoId;
  final String? estadoPolizaId;

  final num? vlrprimapagadaPoliza;

  final int? asesor2Id;
  final int? asesor3Id;
  final int? asesoradId;

  final int? agenciaadId;

  final int? formaexpId;
  final int? asegId;
  final int? usuarioId;

  final DateTime? fcreado;
  final DateTime? fultmod;

  // Campos extra de la vista de búsqueda
  final String? nombreCliente;
  final String? docCliente;
  final String? nombreAsesor;
  final String? nombreRamo;
  final String? nombreProd;
  final String? nombreAseg;
  final String? nombreInterm;
  final String? nombreFormaPago;
  final String? nombreFormaexp;
  final String? nombreUsuario;
  final String? apodoUsuario;

  Poliza({
    required this.id,
    this.nroPoliza,
    this.clienteId,
    this.asesorId,
    this.ramoId,
    this.productoId,
    this.fexpPoliza,
    this.finiPoliza,
    this.ffinPoliza,
    required this.primaPoliza,
    required this.valorPoliza,
    this.bienAsegurado,
    this.obsPoliza,
    this.vlrasegPoliza,
    this.porccomPoliza,
    this.vlrbasecomPoliza,
    this.intermediarioId,
    this.porcomAgencia,
    this.vlrcomPoliza,
    this.vlrcomfijaPoliza,
    this.porcomadicPoliza,
    this.vlrcomadicPoliza,
    this.porcomAsesor1,
    this.porcomAsesor2,
    this.porcomAsesor3,
    this.porcomAsesorad,
    this.porcomAgenciaad,
    this.agenciaId,
    this.formaPagoId,
    this.estadoPolizaId,
    this.vlrprimapagadaPoliza,
    this.asesor2Id,
    this.asesor3Id,
    this.asesoradId,
    this.agenciaadId,
    this.formaexpId,
    this.asegId,
    this.usuarioId,
    this.fcreado,
    this.fultmod,
    this.nombreCliente,
    this.docCliente,
    this.nombreAsesor,
    this.nombreRamo,
    this.nombreProd,
    this.nombreAseg,
    this.nombreInterm,
    this.nombreFormaPago,
    this.nombreFormaexp,
    this.nombreUsuario,
    this.apodoUsuario,
  });

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  static num? _toNum(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return num.tryParse(s.replaceAll(',', '.'));
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static String? _toText(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  factory Poliza.fromMap(Map<String, dynamic> m) => Poliza(
        id: int.parse(m['id'].toString()),
        nroPoliza: _toText(m['nro_poliza']),
        clienteId: _toInt(m['cliente_id']),
        asesorId: _toInt(m['asesor_id']),
        ramoId: _toInt(m['ramo_id']),
        productoId: _toInt(m['producto_id']),
        fexpPoliza: _toDate(m['fexp_poliza']),
        finiPoliza: _toDate(m['fini_poliza']),
        ffinPoliza: _toDate(m['ffin_poliza']),
        primaPoliza: _toNum(m['prima_poliza']) ?? 0,
        valorPoliza: _toNum(m['valor_poliza']) ?? 0,
        bienAsegurado: _toText(m['bien_asegurado']),
        obsPoliza: _toText(m['obs_poliza']),
        vlrasegPoliza: _toNum(m['vlraseg_poliza']),
        porccomPoliza: _toNum(m['porccom_poliza']),
        vlrbasecomPoliza: _toNum(m['vlrbasecom_poliza']),
        intermediarioId: _toInt(m['intermediario_id']),
        porcomAgencia: _toNum(m['porcom_agencia']),
        vlrcomPoliza: _toNum(m['vlrcom_poliza']),
        vlrcomfijaPoliza: _toNum(m['vlrcomfija_poliza']),
        porcomadicPoliza: _toNum(m['porcomadic_poliza']),
        vlrcomadicPoliza: _toNum(m['vlrcomadic_poliza']),
        porcomAsesor1: _toNum(m['porcom_asesor1']),
        porcomAsesor2: _toNum(m['porcom_asesor2']),
        porcomAsesor3: _toNum(m['porcom_asesor3']),
        porcomAsesorad: _toNum(m['porcom_asesorad']),
        porcomAgenciaad: _toNum(m['porcom_agenciaad']),
        agenciaId: _toInt(m['agencia_id']),
        formaPagoId: _toInt(m['forma_pago_id']),
        estadoPolizaId: _toText(m['estado_poliza_id']),
        vlrprimapagadaPoliza: _toNum(m['vlrprimapagada_poliza']),
        asesor2Id: _toInt(m['asesor2_id']),
        asesor3Id: _toInt(m['asesor3_id']),
        asesoradId: _toInt(m['asesorad_id']),
        agenciaadId: _toInt(m['agenciaad_id']),
        formaexpId: _toInt(m['formaexp_id']),
        asegId: _toInt(m['aseg_id']),
        usuarioId: _toInt(m['usuario_id']),
        fcreado: _toDate(m['fcreado']),
        fultmod: _toDate(m['fultmod']),
        nombreCliente: _toText(m['nombre_cliente']),
        docCliente: _toText(m['doc_cliente']),
        nombreAsesor: _toText(m['nombre_asesor']),
        nombreRamo: _toText(m['nombre_ramo']),
        nombreProd: _toText(m['nombre_prod']),
        nombreAseg: _toText(m['nombre_aseg']),
        nombreInterm: _toText(m['nombre_interm']),
        nombreFormaPago: _toText(m['nombre_forma_pago']),
        nombreFormaexp: _toText(m['nombre_formaexp']),
        nombreUsuario: _toText(m['nombre_usuario']),
        apodoUsuario: _toText(m['apodo_usuario']),
      );

  Map<String, dynamic> toInsertMap() => {
        'id': id,
        'nro_poliza': nroPoliza,
        'cliente_id': clienteId,
        'asesor_id': asesorId,
        'ramo_id': ramoId,
        'producto_id': productoId,
        'fexp_poliza': fexpPoliza?.toIso8601String(),
        'fini_poliza': finiPoliza?.toIso8601String(),
        'ffin_poliza': ffinPoliza?.toIso8601String(),
        'prima_poliza': primaPoliza,
        'valor_poliza': valorPoliza,
        'bien_asegurado': bienAsegurado,
        'obs_poliza': obsPoliza,
        'vlraseg_poliza': vlrasegPoliza,
        'porccom_poliza': porccomPoliza,
        'vlrbasecom_poliza': vlrbasecomPoliza,
        'intermediario_id': intermediarioId,
        'porcom_agencia': porcomAgencia,
        'vlrcom_poliza': vlrcomPoliza,
        'vlrcomfija_poliza': vlrcomfijaPoliza,
        'porcomadic_poliza': porcomadicPoliza,
        'vlrcomadic_poliza': vlrcomadicPoliza,
        'porcom_asesor1': porcomAsesor1,
        'porcom_asesor2': porcomAsesor2,
        'porcom_asesor3': porcomAsesor3,
        'porcom_asesorad': porcomAsesorad,
        'porcom_agenciaad': porcomAgenciaad,
        'agencia_id': agenciaId,
        'forma_pago_id': formaPagoId,
        'estado_poliza_id': estadoPolizaId,
        'vlrprimapagada_poliza': vlrprimapagadaPoliza,
        'asesor2_id': asesor2Id,
        'asesor3_id': asesor3Id,
        'asesorad_id': asesoradId,
        'agenciaad_id': agenciaadId,
        'formaexp_id': formaexpId,
        'aseg_id': asegId,
        'usuario_id': usuarioId,
      };
}