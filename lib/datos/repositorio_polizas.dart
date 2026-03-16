import 'package:supabase_flutter/supabase_flutter.dart';
import 'poliza.dart';

class RepositorioPolizas {
  final SupabaseClient _db = Supabase.instance.client;

  Stream<List<Map<String, dynamic>>> escucharCambios() {
    return _db
        .from('polizas')
        .stream(primaryKey: ['id'])
        .order('fcreado', ascending: false)
        .map((rows) => rows.cast<Map<String, dynamic>>());
  }

  Future<List<Poliza>> listar({String busqueda = ''}) async {
    final b = busqueda.trim();

    if (b.isEmpty) {
      final res = await _db
          .from('polizas')
          .select()
          .order('fcreado', ascending: false);

      final rows = (res as List).cast<Map<String, dynamic>>();
      return rows.map(Poliza.fromMap).toList();
    }

    final res = await _db
        .from('polizas')
        .select()
        .ilike('nro_poliza', '%$b%')
        .order('fcreado', ascending: false);

    final rows = (res as List).cast<Map<String, dynamic>>();
    return rows.map(Poliza.fromMap).toList();
  }

  Future<Poliza?> obtenerPoliza(int id) async {
    final res = await _db
        .from('polizas')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (res == null) return null;
    return Poliza.fromMap(res as Map<String, dynamic>);
  }

  Future<void> crearPoliza(Map<String, dynamic> data) async {
    await _db.from('polizas').insert(data);
  }

  Future<void> actualizarPoliza(int id, Map<String, dynamic> data) async {
    await _db.from('polizas').update({
      ...data,
      'fultmod': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> eliminarPoliza(int id) async {
    await _db.from('polizas').delete().eq('id', id);
  }
}