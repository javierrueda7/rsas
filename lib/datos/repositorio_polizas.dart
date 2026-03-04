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

    // Si no hay búsqueda: listado normal
    if (b.isEmpty) {
      final res = await _db
          .from('polizas')
          .select()
          .order('fcreado', ascending: false);

      final rows = (res as List).cast<Map<String, dynamic>>();
      return rows.map(Poliza.fromMap).toList();
    }

    // Si hay búsqueda: hacemos 2 consultas (nro_poliza e id_poliza)
    final res1 = await _db
        .from('polizas')
        .select()
        .ilike('nro_poliza', '%$b%')
        .order('fcreado', ascending: false);

    final res2 = await _db
        .from('polizas')
        .select()
        .ilike('id_poliza', '%$b%')
        .order('fcreado', ascending: false);

    final rows1 = (res1 as List).cast<Map<String, dynamic>>();
    final rows2 = (res2 as List).cast<Map<String, dynamic>>();

    // Unimos sin duplicados por id
    final map = <String, Map<String, dynamic>>{};
    for (final r in rows1) {
      map[r['id'] as String] = r;
    }
    for (final r in rows2) {
      map[r['id'] as String] = r;
    }

    final merged = map.values.toList();

    // Ordenar por fcreado desc (por si el merge alteró el orden)
    merged.sort((a, b) {
      final fa = DateTime.parse(a['fcreado'] as String);
      final fb = DateTime.parse(b['fcreado'] as String);
      return fb.compareTo(fa);
    });

    return merged.map(Poliza.fromMap).toList();
  }


  Future<void> crearPoliza(Map<String, dynamic> data) async {
    await _db.from('polizas').insert(data);
  }

  Future<void> actualizarPoliza(int id, Map<String, dynamic> data) async {
    await _db.from('polizas').update(data).eq('id', id);
  }

  Future<void> eliminarPoliza(int id) async {
    await _db.from('polizas').delete().eq('id', id);
  }
}
