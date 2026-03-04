import 'package:supabase_flutter/supabase_flutter.dart';
import 'catalogos.dart';

class RepositorioCatalogos {
  final SupabaseClient _db = Supabase.instance.client;

  // ================== CLIENTES ==================
  Future<List<Cliente>> listarClientes() async {
    final res = await _db.from('clientes').select().order('nombre_cliente', ascending: true);
    final rows = (res as List).cast<Map<String, dynamic>>();
    return rows.map(Cliente.fromMap).toList();
  }

  Future<Cliente?> obtenerCliente(int id) async {
    final res = await _db.from('clientes').select().eq('id', id).maybeSingle();
    if (res == null) return null;
    return Cliente.fromMap(res as Map<String, dynamic>);
  }

  Future<void> crearCliente(Cliente c) async {
    try {
      await _db.from('clientes').insert(c.toInsertMap());
    } on PostgrestException catch (e) {
      throw Exception(_mensajePG(e, unico: 'Ya existe un cliente con esa información.'));
    }
  }

  Future<void> actualizarCliente(int id, Cliente c) async {
    try {
      await _db.from('clientes').update({
        ...c.toInsertMap(),
        'fultmod': DateTime.now().toIso8601String(),
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

  // ================== ASESORES ==================
  Future<List<Asesor>> listarAsesores({bool soloActivos = false}) async {
    dynamic q = _db.from('asesores').select();
    if (soloActivos) q = q.eq('estado_asesor', true);

    final res = await q.order('nombre_asesor', ascending: true);
    final rows = (res as List).cast<Map<String, dynamic>>();
    return rows.map(Asesor.fromMap).toList();
  }

  Future<Asesor?> obtenerAsesor(int id) async {
    final res = await _db.from('asesores').select().eq('id', id).maybeSingle();
    if (res == null) return null;
    return Asesor.fromMap(res as Map<String, dynamic>);
  }

  Future<void> crearAsesor(Asesor a) async {
    try {
      await _db.from('asesores').insert(a.toInsertMap());
    } on PostgrestException catch (e) {
      throw Exception(_mensajePG(e, unico: 'Ya existe un asesor con esa información.'));
    }
  }

  Future<void> actualizarAsesor(int id, Asesor a) async {
    try {
      await _db.from('asesores').update({
        ...a.toInsertMap(),
        'fultmod': DateTime.now().toIso8601String(),
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

    final res = await q.order('nombre_aseg', ascending: true);
    final rows = (res as List).cast<Map<String, dynamic>>();
    return rows.map(Aseguradora.fromMap).toList();
  }

  Future<Aseguradora?> obtenerAseguradora(int id) async {
    final res = await _db.from('aseguradoras').select().eq('id', id).maybeSingle();
    if (res == null) return null;
    return Aseguradora.fromMap(res as Map<String, dynamic>);
  }

  Future<void> crearAseguradora(Aseguradora a) async {
    try {
      await _db.from('aseguradoras').insert(a.toInsertMap());
    } on PostgrestException catch (e) {
      throw Exception(_mensajePG(e, unico: 'Ya existe una aseguradora con ese nombre.'));
    }
  }

  Future<void> actualizarAseguradora(int id, Aseguradora a) async {
    try {
      await _db.from('aseguradoras').update({
        ...a.toInsertMap(),
        'fultmod': DateTime.now().toIso8601String(),
      }).match({'id': id});
    } on PostgrestException catch (e) {
      throw Exception(_mensajePG(e, unico: 'Ya existe una aseguradora con ese nombre.'));
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

    final res = await q.order('nombre_ramo', ascending: true);
    final rows = (res as List).cast<Map<String, dynamic>>();
    return rows.map(Ramo.fromMap).toList();
  }

  Future<Ramo?> obtenerRamo(int id) async {
    final res = await _db.from('ramos').select().eq('id', id).maybeSingle();
    if (res == null) return null;
    return Ramo.fromMap(res as Map<String, dynamic>);
  }

  Future<void> crearRamo(Ramo r) async {
    try {
      await _db.from('ramos').insert(r.toInsertMap());
    } on PostgrestException catch (e) {
      throw Exception(_mensajePG(e, unico: 'Ya existe un ramo con ese nombre.'));
    }
  }

  Future<void> actualizarRamo(int id, Ramo r) async {
    try {
      await _db.from('ramos').update({
        ...r.toInsertMap(),
        'fultmod': DateTime.now().toIso8601String(),
      }).match(<String, Object>{'id': id});
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

    final res = await q.order('nombre_prod', ascending: true);
    final rows = (res as List).cast<Map<String, dynamic>>();
    return rows.map(Producto.fromMap).toList();
  }

  Future<Producto?> obtenerProducto(int id) async {
    final res = await _db.from('productos').select().eq('id', id).maybeSingle();
    if (res == null) return null;
    return Producto.fromMap(res as Map<String, dynamic>);
  }

  Future<void> crearProducto(Producto p) async {
    try {
      await _db.from('productos').insert(p.toInsertMap());
    } on PostgrestException catch (e) {
      throw Exception(_mensajePG(e));
    }
  }

  Future<void> actualizarProducto(int id, Producto p) async {
    try {
      await _db.from('productos').update({
        ...p.toInsertMap(),
        'fultmod': DateTime.now().toIso8601String(),
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
