// ─── Helpers de conversión de tipos (compartidos por todos los modelos) ──────

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

bool _toBool(dynamic v, {bool fallback = true}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase().trim();
  return s == 'true' || s == '1' || s == 't';
}

num? _toNumOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  return num.tryParse(v.toString());
}

num _toNumWithDefault(dynamic v, {num def = 100}) {
  if (v == null) return def;
  if (v is num) return v;
  return num.tryParse(v.toString()) ?? def;
}

String? _toTextOrNull(dynamic v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? null : s;
}

// ─────────────────────────────────────────────────────────────────────────────

class Cliente {
  final int id;
  final String nombreCliente;
  final String tipopersCliente; // 'N' o 'J'
  final String? tipodocCliente;
  final String? docCliente;
  final String? telCliente;
  final String? correoCliente;
  final String? dirCliente;
  final int? municId;
  final String? nombreMunicipio; // solo para mostrar si haces join
  final String? notasCliente;
  final String? contactoCliente;
  final String? cargocontCliente;
  final int? asesorId;
  final bool estadoCliente;
  final bool recordarCliente;

  Cliente({
    required this.id,
    required this.nombreCliente,
    required this.tipopersCliente,
    this.tipodocCliente,
    this.docCliente,
    this.telCliente,
    this.correoCliente,
    this.dirCliente,
    this.municId,
    this.nombreMunicipio,
    this.notasCliente,
    this.contactoCliente,
    this.cargocontCliente,
    this.asesorId,
    this.estadoCliente = true,
    this.recordarCliente = false,
  });

  factory Cliente.fromMap(Map<String, dynamic> m) {
    final munic = m['municipio'];

    String? nombreMunicipio;
    if (munic is Map<String, dynamic>) {
      nombreMunicipio = munic['nombre_munic'] as String?;
    }

    return Cliente(
      id: _toInt(m['id']),
      nombreCliente: (m['nombre_cliente'] ?? '') as String,
      tipopersCliente: (m['tipopers_cliente'] ?? 'N').toString(),
      tipodocCliente: m['tipodoc_cliente'] as String?,
      docCliente: m['doc_cliente'] as String?,
      telCliente: m['tel_cliente'] as String?,
      correoCliente: m['correo_cliente'] as String?,
      dirCliente: m['dir_cliente'] as String?,
      municId: _toIntOrNull(m['munic_id']),
      nombreMunicipio: nombreMunicipio ?? m['nombre_munic'] as String?,
      notasCliente: m['notas_cliente'] as String?,
      contactoCliente: m['contacto_cliente'] as String?,
      cargocontCliente: m['cargocont_cliente'] as String?,
      asesorId: _toIntOrNull(m['asesor_id']),
      estadoCliente: _toBool(m['estado_cliente'], fallback: true),
      recordarCliente: _toBool(m['recordar_cliente'], fallback: false),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre_cliente': nombreCliente,
        'tipopers_cliente': tipopersCliente,
        'tipodoc_cliente': tipodocCliente,
        'doc_cliente': docCliente,
        'tel_cliente': telCliente,
        'correo_cliente': correoCliente,
        'dir_cliente': dirCliente,
        'munic_id': municId,
        'notas_cliente': notasCliente,
        'contacto_cliente': contactoCliente,
        'cargocont_cliente': cargocontCliente,
        'asesor_id': asesorId,
        'estado_cliente': estadoCliente,
        'recordar_cliente': recordarCliente,
      };

  Map<String, dynamic> toInsertMap() => {
        'nombre_cliente': nombreCliente,
        'tipopers_cliente': tipopersCliente,
        'tipodoc_cliente': tipodocCliente,
        'doc_cliente': docCliente,
        'tel_cliente': telCliente,
        'correo_cliente': correoCliente,
        'dir_cliente': dirCliente,
        'munic_id': municId,
        'notas_cliente': notasCliente,
        'contacto_cliente': contactoCliente,
        'cargocont_cliente': cargocontCliente,
        'asesor_id': asesorId,
        'estado_cliente': estadoCliente,
        'recordar_cliente': recordarCliente,
      };
}

class Municipio {
  final int id;
  final String nombreMunic;

  Municipio({
    required this.id,
    required this.nombreMunic,
  });

  factory Municipio.fromMap(Map<String, dynamic> m) => Municipio(
        id: _toInt(m['id']),
        nombreMunic: (m['nombre_munic'] ?? '') as String,
      );
}

class Asesor {
  final int id;
  final String nombreAsesor;
  final String? tipodocAsesor;
  final String? docAsesor;
  final String? telAsesor;
  final String? correoAsesor;
  final num? porccomAsesor;
  final bool estadoAsesor;

  Asesor({
    required this.id,
    required this.nombreAsesor,
    this.tipodocAsesor,
    this.docAsesor,
    this.telAsesor,
    this.correoAsesor,
    this.porccomAsesor,
    this.estadoAsesor = true,
  });

  factory Asesor.fromMap(Map<String, dynamic> m) => Asesor(
        id: _toInt(m['id']),
        nombreAsesor: (m['nombre_asesor'] ?? '') as String,
        tipodocAsesor: m['tipodoc_asesor'] as String?,
        docAsesor: m['doc_asesor'] as String?,
        telAsesor: m['tel_asesor'] as String?,
        correoAsesor: m['correo_asesor'] as String?,
        porccomAsesor: _toNumOrNull(m['porccom_asesor']),
        estadoAsesor: _toBool(m['estado_asesor']),
      );

  Map<String, dynamic> toInsertMap() => {
        'nombre_asesor': nombreAsesor,
        'tipodoc_asesor': tipodocAsesor,
        'doc_asesor': docAsesor,
        'tel_asesor': telAsesor,
        'correo_asesor': correoAsesor,
        'porccom_asesor': porccomAsesor,
        'estado_asesor': estadoAsesor,
      };
}

class Aseguradora {
  final int id;
  final String nombreAseg;
  final String? nitAseg;
  final String? clave;
  final bool estadoAseg;

  Aseguradora({
    required this.id,
    required this.nombreAseg,
    this.nitAseg,
    this.clave,
    this.estadoAseg = true,
  });

  factory Aseguradora.fromMap(Map<String, dynamic> m) => Aseguradora(
        id: _toInt(m['id']),
        nombreAseg: (m['nombre_aseg'] ?? '') as String,
        nitAseg: m['nit_aseg'] as String?,
        clave: m['clave'] as String?,
        estadoAseg: _toBool(m['estado_aseg']),
      );

  Map<String, dynamic> toInsertMap() => {
        'nombre_aseg': nombreAseg,
        'nit_aseg': nitAseg,
        'clave': clave,
        'estado_aseg': estadoAseg,
      };
}

class Ramo {
  final int id;
  final String nombreRamo;
  final bool estadoRamo;
  final String? obsRamo;
  final num porcomBaseRamo;

  Ramo({
    required this.id,
    required this.nombreRamo,
    this.estadoRamo = true,
    this.obsRamo,
    this.porcomBaseRamo = 100,
  });

  factory Ramo.fromMap(Map<String, dynamic> m) => Ramo(
        id: _toInt(m['id']),
        nombreRamo: (m['nombre_ramo'] ?? '') as String,
        estadoRamo: _toBool(m['estado_ramo']),
        obsRamo: m['obs_ramo'] as String?,
        porcomBaseRamo: _toNumWithDefault(m['porcom_base_ramo'], def: 100),
      );

  Map<String, dynamic> toInsertMap() => {
        'nombre_ramo': nombreRamo,
        'estado_ramo': estadoRamo,
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

  final num? comisionProd;
  final num? porcomProd;

  final String? descProd;
  final num? porcadProd;
  final String? obsProd;

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

  factory Producto.fromMap(Map<String, dynamic> m) => Producto(
        id: _toInt(m['id']),
        nombreProd: (m['nombre_prod'] ?? '') as String,
        ramoId: _toInt(m['ramo_id']),
        aseguradoraId: _toInt(m['aseguradora_id']),
        estadoProd: _toBool(m['estado_prod']),
        comisionProd: _toNumOrNull(m['vlrfijocom_prod']),
        porcomProd: _toNumOrNull(m['porccom_prod']),
        descProd: _toTextOrNull(m['desc_prod']),
        porcadProd: _toNumOrNull(m['porcad_prod']),
        obsProd: _toTextOrNull(m['obs_prod']),
      );

  Map<String, dynamic> toInsertMap() => {
        'nombre_prod': nombreProd,
        'ramo_id': ramoId,
        'aseguradora_id': aseguradoraId,
        'estado_prod': estadoProd,
        'vlrfijocom_prod': comisionProd,
        'porccom_prod': porcomProd,
        'desc_prod': descProd,
        'porcad_prod': porcadProd,
        'obs_prod': obsProd,
      };
}

class Usuario {
  final int id;
  final String apodoUsuario;
  final String nombreUsuario;
  final String rol;
  final int? asesorId;
  final String? claveUsuario;
  final bool estadoUsuario;

  Usuario({
    required this.id,
    required this.apodoUsuario,
    required this.nombreUsuario,
    required this.rol,
    this.asesorId,
    this.claveUsuario,
    this.estadoUsuario = true,
  });

  factory Usuario.fromMap(Map<String, dynamic> m) => Usuario(
        id: _toInt(m['id']),
        apodoUsuario: (m['apodo_usuario'] ?? '') as String,
        nombreUsuario: (m['nombre_usuario'] ?? '') as String,
        rol: (m['rol'] ?? '') as String,
        asesorId: _toIntOrNull(m['asesor_id']),
        claveUsuario: m['clave_usuario'] as String?,
        estadoUsuario: _toBool(m['estado_usuario']),
      );

  Map<String, dynamic> toInsertMap() => {
        'apodo_usuario': apodoUsuario,
        'nombre_usuario': nombreUsuario,
        'rol': rol,
        'asesor_id': asesorId,
        'clave_usuario': claveUsuario,
        'estado_usuario': estadoUsuario,
      };
}

class Intermediario {
  final int id;
  final String nombreInterm;
  final bool estadoInterm;

  Intermediario({
    required this.id,
    required this.nombreInterm,
    this.estadoInterm = true,
  });

  factory Intermediario.fromMap(Map<String, dynamic> m) => Intermediario(
        id: _toInt(m['id']),
        nombreInterm: (m['nombre_interm'] ?? '') as String,
        estadoInterm: _toBool(m['estado_interm']),
      );

  Map<String, dynamic> toInsertMap() => {
        'nombre_interm': nombreInterm,
        'estado_interm': estadoInterm,
      };
}

class FormaExpedicion {
  final int id;
  final String nombreFormaexp;
  final String? descFormaexp;

  FormaExpedicion({required this.id, required this.nombreFormaexp, this.descFormaexp});

  factory FormaExpedicion.fromMap(Map<String, dynamic> m) => FormaExpedicion(
        id: _toInt(m['id']),
        nombreFormaexp: (m['nombre_formaexp'] ?? '') as String,
        descFormaexp: _toTextOrNull(m['desc_formaexp']),
      );

  Map<String, dynamic> toInsertMap() => {
        'nombre_formaexp': nombreFormaexp,
        'desc_formaexp': descFormaexp,
      };
}

class FormaPago {
  final int id;
  final String nombreFormaPago;
  final bool estadoFormaPago;

  FormaPago({
    required this.id,
    required this.nombreFormaPago,
    this.estadoFormaPago = true,
  });

  factory FormaPago.fromMap(Map<String, dynamic> m) => FormaPago(
        id: _toInt(m['id']),
        nombreFormaPago: (m['nombre_forma_pago'] ?? '') as String,
        estadoFormaPago: _toBool(m['estado_forma_pago']),
      );

  Map<String, dynamic> toInsertMap() => {
        'nombre_forma_pago': nombreFormaPago,
        'estado_forma_pago': estadoFormaPago,
      };
}
