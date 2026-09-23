import 'package:supabase_flutter/supabase_flutter.dart';
import 'catalogos.dart';
import 'sesion.dart';

class RepositorioCatalogos {
  final SupabaseClient _db = Supabase.instance.client;

  // Caché simple en memoria para catálogos chicos que se cargan seguido
  // (dropdowns del formulario de póliza, etc.) — una sola traída completa
  // por tabla sirve para todas las variantes de filtro (se filtra en Dart),
  // y se invalida sola al crear/editar/eliminar en esa tabla.
  static final Map<String, List<Map<String, dynamic>>> _cache = {};

  Future<List<Map<String, dynamic>>> _filas(String tabla, String orderBy) async {
    final cacheadas = _cache[tabla];
    if (cacheadas != null) return cacheadas;
    final res =
        await _db.from(tabla).select().order(orderBy, ascending: true).limit(50000);
    final rows = (res as List).cast<Map<String, dynamic>>();
    _cache[tabla] = rows;
    return rows;
  }

  void _invalidar(String tabla) => _cache.remove(tabla);

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

/// Carga rápida: devuelve los primeros [limite] clientes.
Future<List<Cliente>> listarClientes({int limite = 500}) async {
  final resCli = await _db
      .from('clientes')
      .select(_selectClienteSinJoin)
      .order('nombre_cliente', ascending: true)
      .limit(limite);

  final rows = (resCli as List).cast<Map<String, dynamic>>();
  return rows.map(Cliente.fromMap).toList();
}

/// Carga completa en páginas de [_pageSize] filas.
static const int _pageClientes = 1000;

Future<List<Cliente>> listarTodosClientes({
  void Function(int cargados)? onProgreso,
}) async {
  final List<Cliente> todos = [];
  int desde = 0;
  while (true) {
    final res = await _db
        .from('clientes')
        .select(_selectClienteSinJoin)
        .order('nombre_cliente', ascending: true)
        .range(desde, desde + _pageClientes - 1);
    final rows = (res as List).cast<Map<String, dynamic>>();
    todos.addAll(rows.map(Cliente.fromMap));
    onProgreso?.call(todos.length);
    await Future.delayed(Duration.zero);
    if (rows.length < _pageClientes) break;
    desde += _pageClientes;
  }
  return todos;
}

/// Búsqueda server-side sin JOIN — para la lista de catálogo.
Future<List<Cliente>> buscarClientesCompleto(String query) async {
  final q = query.trim();
  // Contra doc_cliente_norm (solo dígitos/letras, sin puntos ni guión) —
  // si buscan pegando el número tal como aparece en el documento (con
  // puntos o con el guión del NIT), igual tiene que encontrarlo.
  final qDoc = q.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();
  dynamic req = _db.from('clientes').select(_selectClienteSinJoin);

  if (q.isNotEmpty) {
    req = req.or(
      'nombre_cliente.ilike.%$q%,'
      'doc_cliente_norm.ilike.%$qDoc%,'
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
  // doc_cliente_norm es solo dígitos/letras en mayúsculas (sin puntos ni
  // guión) — evita que un guión de NIT en medio de la búsqueda haga fallar
  // el ilike (ver fix_doc_cliente_normalizado.sql).
  final qDoc = q.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();
  dynamic req = _db
      .from('clientes')
      .select('id, nombre_cliente, tipodoc_cliente, doc_cliente, estado_cliente');

  if (q.isNotEmpty) {
    req = req.or('nombre_cliente.ilike.%$q%,doc_cliente_norm.ilike.%$qDoc%');
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

/// Match exacto y confiable contra doc_cliente_norm — usado al importar
/// pólizas con IA, donde antes se buscaba por los últimos 3 caracteres del
/// documento (frágil: fallaba siempre que esos 3 caracteres caían sobre el
/// guión de un NIT, que es casi siempre).
Future<Cliente?> buscarClientePorDocExacto(String docNormalizado) async {
  if (docNormalizado.isEmpty) return null;
  final res = await _db
      .from('clientes')
      .select('id, nombre_cliente, tipodoc_cliente, doc_cliente, estado_cliente')
      .eq('doc_cliente_norm', docNormalizado)
      .limit(1);
  final rows = (res as List).cast<Map<String, dynamic>>();
  if (rows.isEmpty) return null;
  final r = rows.first;
  return Cliente(
    id: r['id'] as int,
    nombreCliente: r['nombre_cliente'] as String,
    tipopersCliente: 'N',
    tipodocCliente: r['tipodoc_cliente'] as String?,
    docCliente: r['doc_cliente'] as String?,
    estadoCliente: r['estado_cliente'] as bool? ?? true,
  );
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

/// Un mismo número de documento puede repetirse entre tipos distintos
/// (una CC y un NIT con el mismo número, por ejemplo), pero no dentro del
/// mismo tipo. doc_cliente ya se guarda sin puntos (ver
/// fix_doc_cliente_sin_puntos.sql), así que compara tal cual.
Future<bool> existeDocCliente(String? tipoDoc, String doc, {int? excluirId}) async {
  final docLimpio = doc.trim();
  if (docLimpio.isEmpty) return false;

  dynamic query = _db.from('clientes').select('id').eq('doc_cliente', docLimpio);
  final tipo = (tipoDoc ?? '').trim();
  query = tipo.isEmpty
      ? query.filter('tipodoc_cliente', 'is', null)
      : query.eq('tipodoc_cliente', tipo);
  if (excluirId != null) {
    query = query.neq('id', excluirId);
  }

  final res = await query.limit(1);
  return (res as List).isNotEmpty;
}

/// Solo los clientes con el mismo tipo+número de documento que otro — ver
/// vw_clientes_duplicados, lib/fix_clientes_duplicados.sql.
Future<List<Cliente>> listarClientesDuplicados() async {
  final res = await _db.from('vw_clientes_duplicados').select();
  final rows = (res as List).cast<Map<String, dynamic>>();
  return rows.map(Cliente.fromMap).toList();
}

/// Mueve todas las pólizas de [idsMalos] hacia [idBueno] y borra los
/// clientes sobrantes — todo en una transacción del lado del servidor
/// (fusionar_clientes en fix_clientes_duplicados.sql), no se puede quedar
/// a medias.
Future<void> fusionarClientes(int idBueno, List<int> idsMalos) async {
  await _db.rpc('fusionar_clientes', params: {
    'p_id_bueno': idBueno,
    'p_ids_malos': idsMalos,
  });
}

/// Crea el cliente y devuelve el ID real asignado por la base.
Future<int> crearCliente(Cliente c) async {
  try {
    final res = await _db.from('clientes').insert({
      ...c.toInsertMap(),
      'usuario_id': Sesion.usuarioId,
    }).select('id').single();
    return (res['id'] as num).toInt();
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
    final rows = await _filas('municipio', 'nombre_munic');
    return rows.map(Municipio.fromMap).toList();
  }

  // ================== ASESORES ==================
Future<List<Asesor>> listarAsesores({bool soloActivos = false}) async {
  final rows = await _filas('asesores', 'nombre_asesor');
  final lista = rows.map(Asesor.fromMap).toList();
  return soloActivos ? lista.where((a) => a.estadoAsesor).toList() : lista;
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

Future<void> crearAsesor(Asesor a) async {
  try {
    await _db.from('asesores').insert({
      ...a.toInsertMap(),
      'usuario_id': Sesion.usuarioId,
    });
    _invalidar('asesores');
  } on PostgrestException catch (e) {
    throw Exception(
      _mensajePG(e, unico: 'Ya existe un asesor con esa información.'),
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
    _invalidar('asesores');
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
  final rows = await _filas('aseguradoras', 'nombre_aseg');
  final lista = rows.map(Aseguradora.fromMap).toList();
  return soloActivas ? lista.where((a) => a.estadoAseg).toList() : lista;
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

Future<void> crearAseguradora(Aseguradora a) async {
  try {
    await _db.from('aseguradoras').insert({
      ...a.toInsertMap(),
      'usuario_id': Sesion.usuarioId,
    });
    _invalidar('aseguradoras');
  } on PostgrestException catch (e) {
    throw Exception(
      _mensajePG(e, unico: 'Ya existe una aseguradora con ese nombre.'),
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
    _invalidar('aseguradoras');
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
  final rows = await _filas('ramos', 'nombre_ramo');
  final lista = rows.map(Ramo.fromMap).toList();
  return soloActivos ? lista.where((r) => r.estadoRamo).toList() : lista;
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


Future<void> crearRamo(Ramo r) async {
  try {
    await _db.from('ramos').insert({
      ...r.toInsertMap(),
      'usuario_id': Sesion.usuarioId,
    });
    _invalidar('ramos');
  } on PostgrestException catch (e) {
    throw Exception(
      _mensajePG(e, unico: 'Ya existe un ramo con ese nombre.'),
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
    _invalidar('ramos');
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
    final rows = await _filas('productos', 'nombre_prod');
    var lista = rows.map(Producto.fromMap).toList();
    if (ramoId != null) lista = lista.where((p) => p.ramoId == ramoId).toList();
    if (aseguradoraId != null) {
      lista = lista.where((p) => p.aseguradoraId == aseguradoraId).toList();
    }
    if (soloActivos) lista = lista.where((p) => p.estadoProd).toList();
    return lista;
  }

  /// Catálogo compacto (aseguradora + ramo + producto) para pasarle a la IA
  /// al importar pólizas — así puede mapear el texto/título del documento
  /// contra las combinaciones reales que existen en el sistema (aprovecha
  /// su comprensión semántica: sabe que "RESP. CIVIL EXTRACONTRACTUAL" es
  /// lo mismo que "Responsabilidad Civil Extracontractual", por ejemplo),
  /// en vez de depender solo de una comparación de texto literal después.
  Future<List<Map<String, String>>> catalogoProductosParaIA() async {
    final productos = await listarProductos(soloActivos: true);
    final aseguradoras = await listarAseguradoras(soloActivas: true);
    final ramos = await listarRamos(soloActivos: true);
    final asegPorId = {for (final a in aseguradoras) a.id: a.nombreAseg};
    final ramoPorId = {for (final r in ramos) r.id: r.nombreRamo};
    return productos
        .map((p) => {
              'aseguradora': asegPorId[p.aseguradoraId] ?? '',
              'ramo': ramoPorId[p.ramoId] ?? '',
              'producto': p.nombreProd,
            })
        .where((m) => m['aseguradora']!.isNotEmpty && m['ramo']!.isNotEmpty)
        .toList();
  }

  /// Si antes alguien corrigió el producto que la IA sugirió para este
  /// mismo texto (de esta misma aseguradora) DOS VECES O MÁS, devuelve
  /// directamente el producto correcto — sin pasar por el matcheo difuso
  /// de nuevo. Exige que se haya repetido (no solo la primera corrección)
  /// para no dejarse guiar por un error puntual del digitador — recién se
  /// aplica automático cuando ya es un patrón consistente.
  Future<int?> buscarProductoAprendido(
      int aseguradoraId, String textoExtraidoNorm) async {
    if (textoExtraidoNorm.trim().isEmpty) return null;
    final res = await _db
        .from('ia_aprendizaje_producto')
        .select('producto_id')
        .eq('aseguradora_id', aseguradoraId)
        .eq('texto_extraido', textoExtraidoNorm)
        .gte('veces', 2)
        .maybeSingle();
    if (res == null) return null;
    return (res['producto_id'] as num).toInt();
  }

  /// El digitador cambió el producto que la IA había sugerido para este
  /// texto — se guarda como corrección para la próxima vez. Si ya había
  /// una corrección para el mismo texto+aseguradora, la más reciente gana
  /// (por si el error anterior era otro).
  Future<void> registrarAprendizajeProducto(
    int aseguradoraId,
    String textoExtraidoNorm,
    int productoIdCorrecto,
  ) async {
    if (textoExtraidoNorm.trim().isEmpty) return;
    try {
      final existente = await _db
          .from('ia_aprendizaje_producto')
          .select('id, veces')
          .eq('aseguradora_id', aseguradoraId)
          .eq('texto_extraido', textoExtraidoNorm)
          .maybeSingle();
      if (existente != null) {
        await _db.from('ia_aprendizaje_producto').update({
          'producto_id': productoIdCorrecto,
          'veces': ((existente['veces'] as num?)?.toInt() ?? 1) + 1,
          'fultmod': DateTime.now().toIso8601String(),
        }).eq('id', existente['id']);
      } else {
        await _db.from('ia_aprendizaje_producto').insert({
          'aseguradora_id': aseguradoraId,
          'texto_extraido': textoExtraidoNorm,
          'producto_id': productoIdCorrecto,
        });
      }
    } catch (_) {
      // No es crítico — si falla, simplemente no se aprendió esta vez.
    }
  }

  /// Rol (tomador/asegurado/beneficiario) que históricamente resultó ser
  /// el cliente real para esta aseguradora — solo si ya se confirmó 2+
  /// veces, para no guiarse por un solo caso. Sirve de prioridad cuando un
  /// cliente nuevo no matchea por documento contra ningún candidato (no
  /// hay con qué comparar, porque todavía no existe en la base).
  Future<String?> rolClientePreferido(int aseguradoraId) async {
    final res = await _db
        .from('ia_aprendizaje_rol_cliente')
        .select('rol')
        .eq('aseguradora_id', aseguradoraId)
        .gte('veces', 2)
        .order('veces', ascending: false)
        .limit(1)
        .maybeSingle();
    return res?['rol'] as String?;
  }

  /// Se confirmó (al guardar) que el rol usado automáticamente era el
  /// cliente correcto — refuerza el aprendizaje para esa aseguradora.
  Future<void> reforzarAprendizajeRolCliente(
      int aseguradoraId, String rol) async {
    try {
      final existente = await _db
          .from('ia_aprendizaje_rol_cliente')
          .select('id, veces')
          .eq('aseguradora_id', aseguradoraId)
          .eq('rol', rol)
          .maybeSingle();
      if (existente != null) {
        await _db.from('ia_aprendizaje_rol_cliente').update({
          'veces': ((existente['veces'] as num?)?.toInt() ?? 1) + 1,
          'fultmod': DateTime.now().toIso8601String(),
        }).eq('id', existente['id']);
      } else {
        await _db.from('ia_aprendizaje_rol_cliente').insert({
          'aseguradora_id': aseguradoraId,
          'rol': rol,
        });
      }
    } catch (_) {}
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


  Future<void> crearProducto(Producto p) async {
    try {
      await _db.from('productos').insert({
        ...p.toInsertMap(),
        'usuario_id': Sesion.usuarioId,
      });
      _invalidar('productos');
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
      _invalidar('productos');
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
        ...u.toInsertMap(),
      });
    } on PostgrestException catch (e) {
      throw Exception(_mensajePG(e, unico: 'Ya existe un usuario con ese apodo.'));
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

  /// Paso 1 de "Olvidé mi clave": ¿existe ese apodo? Corre ANTES del login,
  /// así que usa una función SECURITY DEFINER propia (ver
  /// lib/fix_rls_seguridad.sql) en vez de leer la tabla usuarios directo —
  /// una vez con RLS, el rol anon no tiene acceso a esa tabla.
  Future<bool> verificarApodoRecuperacion(String apodo) async {
    final res = await _db.rpc('verificar_apodo_recuperacion', params: {
      'p_apodo': apodo.trim(),
    });
    return res == true;
  }

  /// Paso 2: verifica que el apodo y el correo coincidan con un usuario
  /// activo. Devuelve el apodo si la verificación es exitosa, null si no.
  Future<String?> verificarRecuperacion(String apodo, String correo) async {
    final res = await _db.rpc('verificar_recuperacion_usuario', params: {
      'p_apodo': apodo.trim(),
      'p_correo': correo.trim().toLowerCase(),
    });
    return res == true ? apodo.trim() : null;
  }

  /// Paso 3: cambia la clave del usuario identificado por [apodo], previa
  /// revalidación server-side de que [correo] sigue coincidiendo (no confía
  /// solo en que el paso 2 ya se haya cumplido del lado del cliente).
  Future<bool> cambiarClave(String apodo, String correo, String nuevaClave) async {
    final res = await _db.rpc('cambiar_clave_usuario', params: {
      'p_apodo': apodo.trim(),
      'p_correo': correo.trim().toLowerCase(),
      'p_nueva_clave': nuevaClave,
    });
    return res == true;
  }

  /// Verifica apodo+clave y, si son válidos, deja al cliente autenticado
  /// como rol `authenticated` de Supabase (necesario para la RLS, ver
  /// lib/fix_rls_seguridad.sql). La verificación real sigue ocurriendo en
  /// la base (función `autenticar_usuario`) — la Edge Function `login` solo
  /// la invoca y firma el token, nunca ve ni compara el hash.
  Future<Usuario?> autenticar(String apodo, String clave) async {
    final FunctionResponse res;
    try {
      res = await _db.functions.invoke('login', body: {
        'apodo': apodo.trim(),
        'clave': clave,
      });
    } on FunctionException catch (e) {
      final detalle = e.details;
      if (e.status == 401) return null;
      final mensaje = detalle is Map ? detalle['error'] : null;
      throw Exception(mensaje ?? 'Error al iniciar sesión (${e.status}).');
    }

    final data = (res.data as Map).cast<String, dynamic>();
    final accessToken = data['accessToken'] as String;
    _db.rest.setAuth(accessToken);

    return Usuario.fromMap((data['usuario'] as Map).cast<String, dynamic>());
  }

  // ================== FORMAS DE EXPEDICIÓN ==================
  Future<List<FormaExpedicion>> listarFormasExpedicion() async {
    final rows = await _filas('formaexp', 'nombre_formaexp');
    return rows.map(FormaExpedicion.fromMap).toList();
  }

  Future<int> obtenerSiguienteIdFormaExp() async {
    final res = await _db.from('formaexp').select('id').order('id', ascending: false).limit(1);
    return _siguienteIdDesde((res as List).cast<Map<String, dynamic>>());
  }

  Future<void> crearFormaExpedicion(FormaExpedicion f) async {
    try {
      await _db.from('formaexp').insert({
        ...f.toInsertMap(),
        'usuario_id': Sesion.usuarioId,
      });
      _invalidar('formaexp');
    } on PostgrestException catch (e) {
      throw Exception(_mensajePG(e, unico: 'Ya existe una forma de expedición con ese nombre.'));
    }
  }

  Future<void> actualizarFormaExpedicion(int id, FormaExpedicion f) async {
    try {
      await _db.from('formaexp').update({
        ...f.toInsertMap(),
        'usuario_id': Sesion.usuarioId,
      }).match({'id': id});
      _invalidar('formaexp');
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
    final rows = await _filas('formas_pago', 'nombre_forma_pago');
    final lista = rows.map(FormaPago.fromMap).toList();
    return soloActivas ? lista.where((f) => f.estadoFormaPago).toList() : lista;
  }

  Future<int> obtenerSiguienteIdFormaPago() async {
    final res = await _db.from('formas_pago').select('id').order('id', ascending: false).limit(1);
    return _siguienteIdDesde((res as List).cast<Map<String, dynamic>>());
  }

  Future<void> crearFormaPago(FormaPago f) async {
    try {
      await _db.from('formas_pago').insert({
        ...f.toInsertMap(),
        'usuario_id': Sesion.usuarioId,
      });
      _invalidar('formas_pago');
    } on PostgrestException catch (e) {
      throw Exception(_mensajePG(e, unico: 'Ya existe una forma de pago con ese nombre.'));
    }
  }

  Future<void> actualizarFormaPago(int id, FormaPago f) async {
    try {
      await _db.from('formas_pago').update({
        ...f.toInsertMap(),
        'usuario_id': Sesion.usuarioId,
      }).match({'id': id});
      _invalidar('formas_pago');
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

  // ================== INTERMEDIARIOS ==================

  Future<List<Intermediario>> listarIntermediarios({bool soloActivos = false}) async {
    final rows = await _filas('intermediarios', 'nombre_interm');
    final lista = rows.map(Intermediario.fromMap).toList();
    return soloActivos ? lista.where((i) => i.estadoInterm).toList() : lista;
  }

  // ================== Helpers ==================
  Future<void> _deleteConProteccionFK({
    required String table,
    required Map<String, Object> match,
    required String mensajeFK,
  }) async {
    try {
      await _db.from(table).delete().match(match);
      _invalidar(table);
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
