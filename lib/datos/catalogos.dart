class Cliente {
  final int id;
  final String nombreCliente;
  final String? tipodocCliente;
  final String? docCliente;
  final String? telCliente;
  final String? correoCliente;
  final String? dirCliente;
  final String? ciudadCliente;
  final String? notasCliente;

  Cliente({
    required this.id,
    required this.nombreCliente,
    this.tipodocCliente,
    this.docCliente,
    this.telCliente,
    this.correoCliente,
    this.dirCliente,
    this.ciudadCliente,
    this.notasCliente,
  });

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory Cliente.fromMap(Map<String, dynamic> m) => Cliente(
        id: _toInt(m['id']),
        nombreCliente: (m['nombre_cliente'] ?? '') as String,
        tipodocCliente: m['tipodoc_cliente'] as String?,
        docCliente: m['doc_cliente'] as String?,
        telCliente: m['tel_cliente'] as String?,
        correoCliente: m['correo_cliente'] as String?,
        dirCliente: m['dir_cliente'] as String?,
        ciudadCliente: m['ciudad_cliente'] as String?,
        notasCliente: m['notas_cliente'] as String?,
      );

  Map<String, dynamic> toInsertMap() => {
        'nombre_cliente': nombreCliente,
        'tipodoc_cliente': tipodocCliente,
        'doc_cliente': docCliente,
        'tel_cliente': telCliente,
        'correo_cliente': correoCliente,
        'dir_cliente': dirCliente,
        'ciudad_cliente': ciudadCliente,
        'notas_cliente': notasCliente,
      };
}

class Asesor {
  final int id;
  final String nombreAsesor;
  final String? tipodocAsesor;
  final String? docAsesor;
  final String? telAsesor;
  final String? correoAsesor;
  final bool estadoAsesor;

  Asesor({
    required this.id,
    required this.nombreAsesor,
    this.tipodocAsesor,
    this.docAsesor,
    this.telAsesor,
    this.correoAsesor,
    this.estadoAsesor = true,
  });

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory Asesor.fromMap(Map<String, dynamic> m) => Asesor(
        id: _toInt(m['id']),
        nombreAsesor: (m['nombre_asesor'] ?? '') as String,
        tipodocAsesor: m['tipodoc_asesor'] as String?,
        docAsesor: m['doc_asesor'] as String?,
        telAsesor: m['tel_asesor'] as String?,
        correoAsesor: m['correo_asesor'] as String?,
        estadoAsesor: (m['estado_asesor'] ?? true) as bool,
      );

  Map<String, dynamic> toInsertMap() => {
        'nombre_asesor': nombreAsesor,
        'tipodoc_asesor': tipodocAsesor,
        'doc_asesor': docAsesor,
        'tel_asesor': telAsesor,
        'correo_asesor': correoAsesor,
        'estado_asesor': estadoAsesor,
      };
}

class Aseguradora {
  final int id;
  final String nombreAseg;
  final String? nitAseg;
  final String? clave; // ✅ opcional
  final bool estadoAseg;

  Aseguradora({
    required this.id,
    required this.nombreAseg,
    this.nitAseg,
    this.clave,
    this.estadoAseg = true,
  });

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory Aseguradora.fromMap(Map<String, dynamic> m) => Aseguradora(
        id: _toInt(m['id']),
        nombreAseg: (m['nombre_aseg'] ?? '') as String,
        nitAseg: m['nit_aseg'] as String?,
        clave: m['clave'] as String?, // ✅ nuevo
        estadoAseg: (m['estado_aseg'] ?? true) as bool,
      );

  Map<String, dynamic> toInsertMap() => {
        'nombre_aseg': nombreAseg,
        'nit_aseg': nitAseg,
        'clave': clave, // ✅ nuevo
        'estado_aseg': estadoAseg,
      };
}

class Ramo {
  final int id;
  final String nombreRamo;
  final bool estadoRamo;

  // ✅ NUEVO
  final String? obsRamo;
  final num porcomBaseRamo; // no null, default 100

  Ramo({
    required this.id,
    required this.nombreRamo,
    this.estadoRamo = true,
    this.obsRamo,
    this.porcomBaseRamo = 100,
  });

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static num _toNum(dynamic v, {num def = 100}) {
    if (v == null) return def;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? def;
  }

  factory Ramo.fromMap(Map<String, dynamic> m) => Ramo(
        id: _toInt(m['id']),
        nombreRamo: (m['nombre_ramo'] ?? '') as String,
        estadoRamo: (m['estado_ramo'] ?? true) as bool,
        // ✅ NUEVO
        obsRamo: m['obs_ramo'] as String?,
        porcomBaseRamo: _toNum(m['porcom_base_ramo'], def: 100),
      );

  Map<String, dynamic> toInsertMap() => {
        'nombre_ramo': nombreRamo,
        'estado_ramo': estadoRamo,
        // ✅ NUEVO
        'obs_ramo': (obsRamo == null || obsRamo!.trim().isEmpty) ? null : obsRamo!.trim(),
        'porcom_base_ramo': porcomBaseRamo,
      };
}

class Producto {
  final int id;
  final String nombreProd;
  final int ramoId;
  final int aseguradoraId;
  final bool estadoProd;

  // existentes
  final num? comisionProd;   // vlrfijocom_prod
  final num? porcomProd;     // porccom_prod

  // ✅ nuevos
  final String? descProd;    // desc_prod
  final num? porcadProd;     // porcad_prod
  final String? obsProd;     // obs_prod

  Producto({
    required this.id,
    required this.nombreProd,
    required this.ramoId,
    required this.aseguradoraId,
    this.estadoProd = true,
    this.comisionProd,
    this.porcomProd,
    this.descProd,
    this.porcadProd,
    this.obsProd,
  });

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
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

  factory Producto.fromMap(Map<String, dynamic> m) => Producto(
        id: _toInt(m['id']),
        nombreProd: (m['nombre_prod'] ?? '') as String,
        ramoId: _toInt(m['ramo_id']),
        aseguradoraId: _toInt(m['aseguradora_id']),
        estadoProd: (m['estado_prod'] ?? true) as bool,

        comisionProd: _toNumOrNull(m['vlrfijocom_prod']),
        porcomProd: _toNumOrNull(m['porccom_prod']),

        // ✅ nuevos
        descProd: _toTextOrNull(m['desc_prod']),
        porcadProd: _toNumOrNull(m['porcad_prod']),
        obsProd: _toTextOrNull(m['obs_prod']),
      );

  Map<String, dynamic> toInsertMap() => {
        'nombre_prod': nombreProd,
        'ramo_id': ramoId,
        'aseguradora_id': aseguradoraId,
        'estado_prod': estadoProd,

        // existentes
        'vlrfijocom_prod': comisionProd,
        'porccom_prod': porcomProd,

        // ✅ nuevos
        'desc_prod': descProd,
        'porcad_prod': porcadProd,
        'obs_prod': obsProd,
      };
}