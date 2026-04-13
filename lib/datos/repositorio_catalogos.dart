import 'package:supabase_flutter/supabase_flutter.dart';
import 'catalogos.dart';
import 'sesion.dart';

class RepositorioCatalogos {
  final SupabaseClient _db = Supabase.instance.client;

  // Extrae el siguiente ID a partir de la fila más reciente de una tabla.
  int _siguienteIdDesde(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return 1;
    final ultimo = rows.first['id'];
    if (ultimo is int) return ultimo + 1;
    if (ultimo is num) return ultimo.toInt() + 1;
    return (int.tryParse(ultimo.toString()) ?? 0) + 1;
  }

// ================== CLIENTES ==================

static const String _selectClienteSinJoin =
    'id, nombre_cliente, tipopers_cliente, tipodoc_cliente, doc_cliente, '
    'tel_cliente, correo_cliente, dir_cliente, munic_id, notas_cliente, '
    'contacto_cliente, cargocont_cliente, asesor_id, estado_cliente, recordar_cliente';

/// Todos los clientes sin JOIN — rápido para la lista de catálogo.
/// El nombre de municipio se resuelve en memoria con [listarMunicipios].
Future<List<Cliente>> listarClientes() async {
  final resCli = await _db
      .from('clientes')
      .select(_selectClienteSinJoin)
      .order('nombre_cliente', ascending: true)
      .limit(50000);

  final rows = (resCli as List).cast<Map<String, dynamic>>();
  return rows.map(Cliente.fromMap).toList();
}

/// Búsqueda server-side sin JOIN — para la lista de catálogo.
Future<List<Cliente>> buscarClientesCompleto(String query) async {
  final q = query.trim();
  dynamic req = _db.from('clientes').select(_selectClienteSinJoin);

  if (q.isNotEmpty) {
    req = req.or(
      'nombre_cliente.ilike.%$q%,'
      'doc_cliente.ilike.%$q%,'
      'tel_cliente.ilike.%$q%,'
      'correo_cliente.ilike.%$q%',
    );
  }

  final res = await req.order('nombre_cliente', ascending: true).limit(50000);
  final rows = (res as List).cast<Map<String, dynamic>>();
  return rows.map(Cliente.fromMap).toList();
}

/// Búsqueda server-side por nombre o documento — para dropdowns en formularios.
/// Devuelve máximo [limit] resultados. Si [query] está vacío devuelve los primeros [limit].
Future<List<Cliente>> buscarClientes(String query, {int limit = 60}) async {
  final q = query.trim();
  dynamic req = _db
      .from('clientes')
      .select('id, nombre_cliente, tipodoc_cliente, doc_cliente, estado_cliente');

  if (q.isNotEmpty) {
    req = req.or('nombre_cliente.ilike.%$q%,doc_cliente.ilike.%$q%');
  }

  final res = await req
      .order('nombre_cliente', ascending: true)
      .limit(limit);

  final rows = (res as List).cast<Map<String, dynamic>>();
  return rows.map((r) => Cliente(
    id: r['id'] as int,
    nombreCliente: r['nombre_cliente'] as String,
    tipopersCliente: 'N',
    tipodocCliente: r['tipodoc_cliente'] as String?,
    docCliente: r['doc_cliente'] as String?,
    estadoCliente: r['estado_cliente'] as bool? ?? true,
  )).toList();
}

Future<Cliente?> obtenerCliente(int id) async {
  final res = await _db
      .from('clientes')
      .select('''
        id,
        nombre_cliente,
        tipopers_cliente,
        tipodoc_cliente,
        doc_cliente,
        tel_cliente,
        correo_cliente,
        dir_cliente,
        munic_id,
        notas_cliente,
        contacto_cliente,
        cargocont_cliente,
        asesor_id,
        estado_cliente,
        recordar_cliente,
        municipio:munic_id (
          id,
          nombre_munic
        )
      ''')
      .eq('id', id)
      .maybeSingle();

  if (res == null) return null;
  return Cliente.fromMap(res as Map<String, dynamic>);
}

Future<int> obtenerSiguienteIdCliente() async {
  final res = await _db.from('clientes').select('id').order('id', ascending: false).limit(1);
  return _siguienteIdDesde((res as List).cast<Map<String, dynamic>>());
}

Future<bool> existeClienteId(int id) async {
  final res = await _db.from('clientes').select('id').eq('id', id).maybeSingle();
  return res != null;
}

Future<void> crearCliente(Cliente c) async {
  try {
    await _db.from('clientes').insert({
      'id': c.id,
      ...c.toInsertMap(),
      'usuario_id': Sesion.usuarioId,
    });
  } on PostgrestException catch (e) {
    throw Exception(_mensajePG(
      e,
      unico: 'Ya existe un cliente con esa información.',
    ));
  }
}

Future<void> actualizarCliente(int id, Cliente c) async {
  try {
    await _db.from('clientes').update({
      ...c.toInsertMap(),
      'fultmod': DateTime.now().toIso8601String(),
      'usuario_id': Sesion.usuarioId,
    }).match({'id': id});
  } on PostgrestException catch (e) {
    throw Exception(_mensajePG(e));
  }
}

Future<void> eliminarCliente(int id) async {
  await _deleteConProteccionFK(
    table: 'clientes',
    match: {'id': id},
    mensajeFK: 'No puedes eliminar este cliente porque está relacionado con pólizas.',
  );
}

    // ================== MUNICIPIOS ==================
  Future<List<Municipio>> listarMunicipios() async {
    final res = await _db
        .from('municipio')
        .select()
        .order('nombre_munic', ascending: true)
        .limit(50000);

    final rows = (res as List).cast<Map<String, dynamic>>();
    return rows.map(Municipio.fromMap).toList();
  }

  Future<Municipio?> obtenerMunicipio(int id) async {
    final res = await _db
        .from('municipio')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (res == null) return null;
    return Municipio.fromMap(res as Map<String, dynamic>);
  }

  // ================== ASESORES ==================
Future<List<Asesor>> listarAsesores({bool soloActivos = false}) async {
  dynamic q = _db.from('asesores').select();
  if (soloActivos) q = q.eq('estado_asesor', true);

  final res = await q.order('nombre_asesor', ascending: true).limit(50000);
  final rows = (res as List).cast<Map<String, dynamic>>();
  return rows.map(Asesor.fromMap).toList();
}

Future<Asesor?> obtenerAsesor(int id) async {
  final res = await _db
      .from('asesores')
      .select()
      .eq('id', id)
      .maybeSingle();

  if (res == null) return null;
  return Asesor.fromMap(res as Map<String, dynamic>);
}

Future<int> obtenerSiguienteIdAsesor() async {
  final res = await _db.from('asesores').select('id').order('id', ascending: false).limit(1);
  return _siguienteIdDesde((res as List).cast<Map<String, dynamic>>());
}

Future<bool> existeAsesorId(int id) async {
  final res = await _db
      .from('asesores')
      .select('id')
      .eq('id', id)
      .maybeSingle();

  return res != null;
}

Future<void> crearAsesor(Asesor a) async {
  try {
    await _db.from('asesores').insert({
      'id': a.id,
      ...a.toInsertMap(),
      'usuario_id': Sesion.usuarioId,
    });
  } on PostgrestException catch (e) {
    throw Exception(
      _mensajePG(e, unico: 'Ya existe un asesor con esa información o ID.'),
    );
  }
}

Future<void> actualizarAsesor(int id, Asesor a) async {
  try {
    await _db.from('asesores').update({
      ...a.toInsertMap(),
      'fultmod': DateTime.now().toIso8601String(),
      'usuario_id': Sesion.usuarioId,
    }).match({'id': id});
  } on PostgrestException catch (e) {
    throw Exception(_mensajePG(e));
  }
}

Future<void> eliminarAsesor(int id) async {
  await _deleteConProteccionFK(
    table: 'asesores',
    match: {'id': id},
    mensajeFK: 'No puedes eliminar este asesor porque está relacionado con pólizas.',
  );
}

 // ================== ASEGURADORAS ==================
Future<List<Aseguradora>> listarAseguradoras({bool soloActivas = false}) async {
  dynamic q = _db.from('aseguradoras').select();
  if (soloActivas) q = q.eq('estado_aseg', true);

  final res = await q.order('nombre_aseg', ascending: true).limit(50000);
  final rows = (res as List).cast<Map<String, dynamic>>();
  return rows.map(Aseguradora.fromMap).toList();
}

Future<Aseguradora?> obtenerAseguradora(int id) async {
  final res = await _db
      .from('aseguradoras')
      .select()
      .eq('id', id)
      .maybeSingle();

  if (res == null) return null;
  return Aseguradora.fromMap(res as Map<String, dynamic>);
}

Future<int> obtenerSiguienteIdAseguradora() async {
  final res = await _db.from('aseguradoras').select('id').order('id', ascending: false).limit(1);
  return _siguienteIdDesde((res as List).cast<Map<String, dynamic>>());
}

Future<bool> existeAseguradoraId(int id) async {
  final res = await _db
      .from('aseguradoras')
      .select('id')
      .eq('id', id)
      .maybeSingle();

  return res != null;
}

Future<void> crearAseguradora(Aseguradora a) async {
  try {
    await _db.from('aseguradoras').insert({
      'id': a.id,
      ...a.toInsertMap(),
      'usuario_id': Sesion.usuarioId,
    });
  } on PostgrestException catch (e) {
    throw Exception(
      _mensajePG(e, unico: 'Ya existe una aseguradora con ese nombre o ID.'),
    );
  }
}

Future<void> actualizarAseguradora(int id, Aseguradora a) async {
  try {
    await _db.from('aseguradoras').update({
      ...a.toInsertMap(),
      'fultmod': DateTime.now().toIso8601String(),
      'usuario_id': Sesion.usuarioId,
    }).match({'id': id});
  } on PostgrestException catch (e) {
    throw Exception(
      _mensajePG(e, unico: 'Ya existe una aseguradora con ese nombre.'),
    );
  }
}

Future<void> eliminarAseguradora(int id) async {
  await _deleteConProteccionFK(
    table: 'aseguradoras',
    match: {'id': id},
    mensajeFK: 'No puedes eliminar esta aseguradora porque está relacionada con productos o pólizas.',
  );
}

// ================== RAMOS ==================
Future<List<Ramo>> listarRamos({bool soloActivos = false}) async {
  dynamic q = _db.from('ramos').select();
  if (soloActivos) q = q.eq('estado_ramo', true);

  final res = await q.order('nombre_ramo', ascending: true).limit(50000);
  final rows = (res as List).cast<Map<String, dynamic>>();
  return rows.map(Ramo.fromMap).toList();
}

Future<Ramo?> obtenerRamo(int id) async {
  final res = await _db
      .from('ramos')
      .select()
      .eq('id', id)
      .maybeSingle();

  if (res == null) return null;
  return Ramo.fromMap(res as Map<String, dynamic>);
}

Future<int> obtenerSiguienteIdRamo() async {
  final res = await _db.from('ramos').select('id').order('id', ascending: false).limit(1);
  return _siguienteIdDesde((res as List).cast<Map<String, dynamic>>());
}

Future<bool> existeRamoId(int id) async {
  final res = await _db
      .from('ramos')
      .select('id')
      .eq('id', id)
      .maybeSingle();

  return res != null;
}

Future<void> crearRamo(Ramo r) async {
  try {
    await _db.from('ramos').insert({
      'id': r.id,
      ...r.toInsertMap(),
      'usuario_id': Sesion.usuarioId,
    });
  } on PostgrestException catch (e) {
    throw Exception(
      _mensajePG(e, unico: 'Ya existe un ramo con ese nombre o ID.'),
    );
  }
}

Future<void> actualizarRamo(int id, Ramo r) async {
  try {
    await _db.from('ramos').update({
      ...r.toInsertMap(),
      'fultmod': DateTime.now().toIso8601String(),
      'usuario_id': Sesion.usuarioId,
    }).match({'id': id});
  } on PostgrestException catch (e) {
    throw Exception(_mensajePG(e));
  }
}

Future<void> eliminarRamo(int id) async {
  await _deleteConProteccionFK(
    table: 'ramos',
    match: {'id': id},
    mensajeFK: 'No puedes eliminar este ramo porque está relacionado con productos o pólizas.',
  );
}

// ================== PRODUCTOS ==================
  Future<List<Producto>> listarProductos({
    int? ramoId,
    int? aseguradoraId,
    bool soloActivos = false,
  }) async {
    dynamic q = _db.from('productos').select();

    if (ramoId != null) q = q.eq('ramo_id', ramoId);
    if (aseguradoraId != null) q = q.eq('aseguradora_id', aseguradoraId);
    if (soloActivos) q = q.eq('estado_prod', true);

    final res = await q.order('nombre_prod', ascending: true).limit(50000);
    final rows = (res as List).cast<Map<String, dynamic>>();
    return rows.map(Producto.fromMap).toList();
  }

  Future<Producto?> obtenerProducto(int id) async {
    final res = await _db
        .from('productos')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (res == null) return null;
    return Producto.fromMap(res as Map<String, dynamic>);
  }

  Future<int> obtenerSiguienteIdProducto() async {
    final res = await _db.from('productos').select('id').order('id', ascending: false).limit(1);
    return _siguienteIdDesde((res as List).cast<Map<String, dynamic>>());
  }

  Future<bool> existeProductoId(int id) async {
    final res = await _db
        .from('productos')
        .select('id')
        .eq('id', id)
        .maybeSingle();

    return res != null;
  }

  Future<void> crearProducto(Producto p) async {
    try {
      await _db.from('productos').insert({
        'id': p.id,
        ...p.toInsertMap(),
        'usuario_id': Sesion.usuarioId,
      });
    } on PostgrestException catch (e) {
      throw Exception(_mensajePG(e));
    }
  }

  Future<void> actualizarProducto(int id, Producto p) async {
    try {
      await _db.from('productos').update({
        ...p.toInsertMap(),
        'fultmod': DateTime.now().toIso8601String(),
        'usuario_id': Sesion.usuarioId,
      }).match({'id': id});
    } on PostgrestException catch (e) {
      throw Exception(_mensajePG(e));
    }
  }

  Future<void> eliminarProducto(int id) async {
    await _deleteConProteccionFK(
      table: 'productos',
      match: {'id': id},
      mensajeFK: 'No puedes eliminar este producto porque está relacionado con pólizas.',
    );
  }

  // ================== USUARIOS ==================
  Future<List<Usuario>> listarUsuarios({bool soloActivos = false}) async {
    dynamic query = _db.from('usuarios').select();
    if (soloActivos) query = query.eq('estado_usuario', true);
    final res = await query.order('apodo_usuario', ascending: true).limit(50000);
    return (res as List).cast<Map<String, dynamic>>().map(Usuario.fromMap).toList();
  }

  Future<Usuario?> obtenerUsuario(int id) async {
    final res = await _db.from('usuarios').select().eq('id', id).maybeSingle();
    if (res == null) return null;
    return Usuario.fromMap(res as Map<String, dynamic>);
  }

  Future<int> obtenerSiguienteIdUsuario() async {
    final res = await _db.from('usuarios').select('id').order('id', ascending: false).limit(1);
    return _siguienteIdDesde((res as List).cast<Map<String, dynamic>>());
  }

  Future<bool> existeUsuarioId(int id) async {
    final res = await _db.from('usuarios').select('id').eq('id', id).maybeSingle();
    return res != null;
  }

  Future<bool> existeApodoUsuario(String apodo, {int? excludeId}) async {
    dynamic q = _db.from('usuarios').select('id').eq('apodo_usuario', apodo.trim());
    final res = await q.limit(50000);
    final rows = (res as List).cast<Map<String, dynamic>>();
    if (excludeId != null) return rows.any((r) => r['id'] != excludeId);
    return rows.isNotEmpty;
  }

  Future<void> crearUsuario(Usuario u) async {
    try {
      await _db.from('usuarios').insert({
        'id': u.id,
        ...u.toInsertMap(),
      });
    } on PostgrestException catch (e) {
      throw Exception(_mensajePG(e, unico: 'Ya existe un usuario con ese apodo o ID.'));
    }
  }

  Future<void> actualizarUsuario(int id, Usuario u) async {
    try {
      await _db.from('usuarios').update({
        ...u.toInsertMap(),
      }).match({'id': id});
    } on PostgrestException catch (e) {
      throw Exception(_mensajePG(e, unico: 'Ya existe un usuario con ese apodo.'));
    }
  }

  Future<void> eliminarUsuario(int id) async {
    try {
      await _db.from('usuarios').delete().match({'id': id});
    } on PostgrestException catch (e) {
      throw Exception(_mensajePG(e));
    }
  }

  /// Verifica que el apodo y el correo coincidan con un usuario activo.
  /// Devuelve el apodo si la verificación es exitosa, null si no.
  Future<String?> verificarRecuperacion(String apodo, String correo) async {
    final res = await _db
        .from('usuarios')
        .select('apodo_usuario')
        .eq('apodo_usuario', apodo.trim())
        .eq('correo_usuario', correo.trim().toLowerCase())
        .eq('estado_usuario', true)
        .maybeSingle();
    if (res == null) return null;
    return res['apodo_usuario'] as String;
  }

  /// Cambia la clave del usuario identificado por [apodo].
  Future<void> cambiarClave(String apodo, String nuevaClave) async {
    await _db
        .from('usuarios')
        .update({'clave_usuario': nuevaClave})
        .eq('apodo_usuario', apodo.trim());
  }

  /// Devuelve el usuario si el apodo y la clave coinciden, null si no.
  Future<Usuario?> autenticar(String apodo, String clave) async {
    final res = await _db
        .from('usuarios')
        .select()
        .eq('apodo_usuario', apodo.trim())
        .eq('clave_usuario', clave)
        .eq('estado_usuario', true)
        .maybeSingle();

    if (res == null) return null;
    return Usuario.fromMap(res as Map<String, dynamic>);
  }

  // ================== FORMAS DE EXPEDICIÓN ==================
  Future<List<FormaExpedicion>> listarFormasExpedicion() async {
    final res = await _db
        .from('formaexp')
        .select()
        .order('nombre_formaexp', ascending: true)
        .limit(50000);
    return (res as List).cast<Map<String, dynamic>>().map(FormaExpedicion.fromMap).toList();
  }

  Future<int> obtenerSiguienteIdFormaExp() async {
    final res = await _db.from('formaexp').select('id').order('id', ascending: false).limit(1);
    return _siguienteIdDesde((res as List).cast<Map<String, dynamic>>());
  }

  Future<bool> existeFormaExpId(int id) async {
    final res = await _db.from('formaexp').select('id').eq('id', id).maybeSingle();
    return res != null;
  }

  Future<void> crearFormaExpedicion(FormaExpedicion f) async {
    try {
      await _db.from('formaexp').insert({
        'id': f.id,
        ...f.toInsertMap(),
        'usuario_id': Sesion.usuarioId,
      });
    } on PostgrestException catch (e) {
      throw Exception(_mensajePG(e, unico: 'Ya existe una forma de expedición con ese nombre o ID.'));
    }
  }

  Future<void> actualizarFormaExpedicion(int id, FormaExpedicion f) async {
    try {
      await _db.from('formaexp').update({
        ...f.toInsertMap(),
        'usuario_id': Sesion.usuarioId,
      }).match({'id': id});
    } on PostgrestException catch (e) {
      throw Exception(_mensajePG(e));
    }
  }

  Future<void> eliminarFormaExpedicion(int id) async {
    await _deleteConProteccionFK(
      table: 'formaexp',
      match: {'id': id},
      mensajeFK: 'No puedes eliminar esta forma de expedición porque está en uso en pólizas.',
    );
  }

  // ================== FORMAS DE PAGO ==================

  Future<List<FormaPago>> listarFormasPago({bool soloActivas = false}) async {
    dynamic q = _db.from('formas_pago').select();
    if (soloActivas) q = q.eq('estado_forma_pago', true);
    final res = await q.order('nombre_forma_pago', ascending: true).limit(50000);
    return (res as List).cast<Map<String, dynamic>>().map(FormaPago.fromMap).toList();
  }

  Future<int> obtenerSiguienteIdFormaPago() async {
    final res = await _db.from('formas_pago').select('id').order('id', ascending: false).limit(1);
    return _siguienteIdDesde((res as List).cast<Map<String, dynamic>>());
  }

  Future<bool> existeFormaPagoId(int id) async {
    final res = await _db.from('formas_pago').select('id').eq('id', id).maybeSingle();
    return res != null;
  }

  Future<void> crearFormaPago(FormaPago f) async {
    try {
      await _db.from('formas_pago').insert({
        'id': f.id,
        ...f.toInsertMap(),
        'usuario_id': Sesion.usuarioId,
      });
    } on PostgrestException catch (e) {
      throw Exception(_mensajePG(e, unico: 'Ya existe una forma de pago con ese nombre o ID.'));
    }
  }

  Future<void> actualizarFormaPago(int id, FormaPago f) async {
    try {
      await _db.from('formas_pago').update({
        ...f.toInsertMap(),
        'usuario_id': Sesion.usuarioId,
      }).match({'id': id});
    } on PostgrestException catch (e) {
      throw Exception(_mensajePG(e, unico: 'Ya existe una forma de pago con ese nombre.'));
    }
  }

  Future<void> eliminarFormaPago(int id) async {
    await _deleteConProteccionFK(
      table: 'formas_pago',
      match: {'id': id},
      mensajeFK: 'No puedes eliminar esta forma de pago porque está en uso en pólizas.',
    );
  }

  // ================== Helpers ==================
  Future<void> _deleteConProteccionFK({
    required String table,
    required Map<String, Object> match,
    required String mensajeFK,
  }) async {
    try {
      await _db.from(table).delete().match(match);
    } on PostgrestException catch (e) {
      if (e.code == '23503') throw Exception(mensajeFK);
      throw Exception(_mensajePG(e));
    }
  }

  String _mensajePG(PostgrestException e, {String? unico}) {
    if (e.code == '23505') return unico ?? 'Ya existe un registro con ese valor (duplicado).';
    return e.message;
  }
}
