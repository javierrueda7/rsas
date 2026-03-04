// ignore_for_file: no_leading_underscores_for_local_identifiers

class Poliza {
  final int id;

  final String nroPoliza;
  final String? idPoliza;

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

  final DateTime fcreado;
  final DateTime fultmod;

  Poliza({
    required this.id,
    required this.nroPoliza,
    required this.idPoliza,
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
    required this.fcreado,
    required this.fultmod,
  });

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory Poliza.fromMap(Map<String, dynamic> m) {
    DateTime _dt(dynamic v) => DateTime.parse(v as String);

    num _num(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      return num.parse(v.toString());
    }

    return Poliza(
      id: _toInt(m['id']),
      nroPoliza: (m['nro_poliza'] ?? '') as String,
      idPoliza: m['id_poliza'] as String?,
      clienteId: _toInt(m['cliente_id']),
      asesorId: _toInt(m['asesor_id']),
      ramoId: _toInt(m['ramo_id']),
      productoId: _toInt(m['producto_id']),
      fexpPoliza: _dt(m['fexp_poliza']),
      finiPoliza: _dt(m['fini_poliza']),
      ffinPoliza: _dt(m['ffin_poliza']),
      primaPoliza: _num(m['prima_poliza']),
      valorPoliza: _num(m['valor_poliza']),
      bienAsegurado: m['bien_asegurado'] as String?,
      obsPoliza: m['obs_poliza'] as String?,
      fcreado: _dt(m['fcreado']),
      fultmod: _dt(m['fultmod']),
    );
  }
}
