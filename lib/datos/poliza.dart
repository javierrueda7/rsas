// ignore_for_file: no_leading_underscores_for_local_identifiers

class Poliza {
  final int id;

  // código = mismo id, no se guarda aparte
  final String nroPoliza;

  final int clienteId;
  final int asesorId;
  final int ramoId;
  final int productoId;

  final DateTime fexpPoliza;
  final DateTime finiPoliza;
  final DateTime ffinPoliza;

  final num primaPoliza;
  final num valorPoliza;

  final String? bienAsegurado;
  final String? obsPoliza;

  // ===== NUEVOS =====
  final num? vlrasegPoliza;
  final num? vlrtotalPoliza;

  final num? porcombasePoliza;
  final num? vlrbasecomPoliza;

  final int? intermediarioId;

  final num? porcomPoliza;
  final num? vlrcomPoliza;
  final num? comfijaPoliza;

  final num? porcomadicPoliza;
  final num? vlrcomadicPoliza;

  final int? asesor1Id;
  final num? porcomAsesor1;

  final int? asesor2Id;
  final num? porcomAsesor2;

  final int? asesor3Id;
  final num? porcomAsesor3;

  final int? agenciaId;
  final int? formaPagoId;
  final String? estadoPolizaId;

  final num? vlrprimapagadaPoliza;

  final DateTime fcreado;
  final DateTime fultmod;

  Poliza({
    required this.id,
    required this.nroPoliza,
    required this.clienteId,
    required this.asesorId,
    required this.ramoId,
    required this.productoId,
    required this.fexpPoliza,
    required this.finiPoliza,
    required this.ffinPoliza,
    required this.primaPoliza,
    required this.valorPoliza,
    required this.bienAsegurado,
    required this.obsPoliza,
    required this.vlrasegPoliza,
    required this.vlrtotalPoliza,
    required this.porcombasePoliza,
    required this.vlrbasecomPoliza,
    required this.intermediarioId,
    required this.porcomPoliza,
    required this.vlrcomPoliza,
    required this.comfijaPoliza,
    required this.porcomadicPoliza,
    required this.vlrcomadicPoliza,
    required this.asesor1Id,
    required this.porcomAsesor1,
    required this.asesor2Id,
    required this.porcomAsesor2,
    required this.asesor3Id,
    required this.porcomAsesor3,
    required this.agenciaId,
    required this.formaPagoId,
    required this.estadoPolizaId,
    required this.vlrprimapagadaPoliza,
    required this.fcreado,
    required this.fultmod,
  });

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static int? _toIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  static num? _toNumOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    return num.tryParse(v.toString());
  }

  static String? _toTextOrNull(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  static DateTime _dt(dynamic v) => DateTime.parse(v as String);

  factory Poliza.fromMap(Map<String, dynamic> m) {
    return Poliza(
      id: _toInt(m['id']),
      nroPoliza: (m['nro_poliza'] ?? '') as String,
      clienteId: _toInt(m['cliente_id']),
      asesorId: _toInt(m['asesor_id']),
      ramoId: _toInt(m['ramo_id']),
      productoId: _toInt(m['producto_id']),
      fexpPoliza: _dt(m['fexp_poliza']),
      finiPoliza: _dt(m['fini_poliza']),
      ffinPoliza: _dt(m['ffin_poliza']),
      primaPoliza: _toNum(m['prima_poliza']),
      valorPoliza: _toNum(m['valor_poliza']),
      bienAsegurado: _toTextOrNull(m['bien_asegurado']),
      obsPoliza: _toTextOrNull(m['obs_poliza']),

      // ===== NUEVOS =====
      vlrasegPoliza: _toNumOrNull(m['vlraseg_poliza']),
      vlrtotalPoliza: _toNumOrNull(m['vlrtotal_poliza']),
      porcombasePoliza: _toNumOrNull(m['porcombase_poliza']),
      vlrbasecomPoliza: _toNumOrNull(m['vlrbasecom_poliza']),
      intermediarioId: _toIntOrNull(m['intermediario_id']),
      porcomPoliza: _toNumOrNull(m['porcom_poliza']),
      vlrcomPoliza: _toNumOrNull(m['vlrcom_poliza']),
      comfijaPoliza: _toNumOrNull(m['comfija_poliza']),
      porcomadicPoliza: _toNumOrNull(m['porcomadic_poliza']),
      vlrcomadicPoliza: _toNumOrNull(m['vlrcomadic_poliza']),
      asesor1Id: _toIntOrNull(m['asesor1_id']),
      porcomAsesor1: _toNumOrNull(m['porcom_asesor1']),
      asesor2Id: _toIntOrNull(m['asesor2_id']),
      porcomAsesor2: _toNumOrNull(m['porcom_asesor2']),
      asesor3Id: _toIntOrNull(m['asesor3_id']),
      porcomAsesor3: _toNumOrNull(m['porcom_asesor3']),
      agenciaId: _toIntOrNull(m['agencia_id']),
      formaPagoId: _toIntOrNull(m['forma_pago_id']),
      estadoPolizaId: _toTextOrNull(m['estado_poliza_id']),
      vlrprimapagadaPoliza: _toNumOrNull(m['vlrprimapagada_poliza']),

      fcreado: _dt(m['fcreado']),
      fultmod: _dt(m['fultmod']),
    );
  }
}