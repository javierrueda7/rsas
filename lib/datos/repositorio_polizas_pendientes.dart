import 'package:supabase_flutter/supabase_flutter.dart';
import 'poliza_pendiente.dart';
import 'sesion.dart';

/// Bandeja de trabajo de pólizas que todavía no tienen id definitivo — ver
/// lib/fix_polizas_pendientes.sql para el porqué de "borrador" vs
/// "pendiente_revision".
class RepositorioPolizasPendientes {
  final SupabaseClient _db = Supabase.instance.client;
  static const String _tabla = 'polizas_pendientes';

  Future<List<PolizaPendiente>> listar({String? estado}) async {
    dynamic q = _db.from(_tabla).select();
    if (estado != null) q = q.eq('estado', estado);
    final res = await q.order('fcreado', ascending: false);
    final rows = (res as List).cast<Map<String, dynamic>>();
    return rows.map(PolizaPendiente.fromMap).toList();
  }

  Future<int> contar({String? estado}) async {
    dynamic q = _db.from(_tabla).select('id');
    if (estado != null) q = q.eq('estado', estado);
    final res = await q;
    return (res as List).length;
  }

  Future<int> crear({
    required String estado,
    required Map<String, dynamic> datos,
    String? nombreArchivo,
    String origen = 'manual',
    String? errorMsg,
  }) async {
    final res = await _db.from(_tabla).insert({
      'estado': estado,
      'datos': datos,
      'nombre_archivo': nombreArchivo,
      'origen': origen,
      'error_msg': errorMsg,
      'usuario_id': Sesion.usuarioId,
    }).select('id').single();
    return (res['id'] as num).toInt();
  }

  Future<void> actualizar(
    int id, {
    String? estado,
    Map<String, dynamic>? datos,
  }) async {
    final cambios = <String, dynamic>{
      'fultmod': DateTime.now().toIso8601String(),
    };
    if (estado != null) cambios['estado'] = estado;
    if (datos != null) cambios['datos'] = datos;
    await _db.from(_tabla).update(cambios).eq('id', id);
  }

  Future<void> eliminar(int id) async {
    await _db.from(_tabla).delete().eq('id', id);
  }
}
