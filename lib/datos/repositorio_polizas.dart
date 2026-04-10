import 'package:supabase_flutter/supabase_flutter.dart';
import 'poliza.dart';

class RepositorioPolizas {
  final SupabaseClient _db = Supabase.instance.client;

  static const String _tabla = 'polizas';
  static const String _vista = 'vw_polizas_busqueda';

  /// Carga rápida: devuelve los [limite] registros más recientes.
  Future<List<Poliza>> listar({
    String busqueda = '',
    int limite = 500,
  }) async {
    final b = busqueda.trim();
    dynamic query = _db.from(_vista).select();

    if (b.isNotEmpty) {
      query = query.or(
        'nro_poliza.ilike.%$b%,'
        'nombre_cliente.ilike.%$b%,'
        'doc_cliente.ilike.%$b%,'
        'nombre_asesor.ilike.%$b%,'
        'nombre_ramo.ilike.%$b%,'
        'nombre_prod.ilike.%$b%,'
        'nombre_aseg.ilike.%$b%,'
        'nombre_interm.ilike.%$b%,'
        'nombre_forma_pago.ilike.%$b%,'
        'nombre_formaexp.ilike.%$b%,'
        'nombre_usuario.ilike.%$b%,'
        'apodo_usuario.ilike.%$b%,'
        'bien_asegurado.ilike.%$b%,'
        'obs_poliza.ilike.%$b%',
      );
    }

    final res = await query.order('fcreado', ascending: false).limit(limite);
    final rows = (res as List).cast<Map<String, dynamic>>();
    return rows.map(Poliza.fromMap).toList();
  }

  /// Carga completa: trae todas las pólizas en páginas de [_pageSize] filas.
  /// Llama [onProgreso] después de cada página con el total acumulado.
  static const int _pageSize = 1000;

  Future<List<Poliza>> listarTodos({
    String busqueda = '',
    void Function(int cargados)? onProgreso,
  }) async {
    final b = busqueda.trim();
    final List<Poliza> todos = [];
    int desde = 0;

    while (true) {
      dynamic query = _db.from(_vista).select();

      if (b.isNotEmpty) {
        query = query.or(
          'nro_poliza.ilike.%$b%,'
          'nombre_cliente.ilike.%$b%,'
          'doc_cliente.ilike.%$b%,'
          'nombre_asesor.ilike.%$b%,'
          'nombre_ramo.ilike.%$b%,'
          'nombre_prod.ilike.%$b%,'
          'nombre_aseg.ilike.%$b%,'
          'nombre_interm.ilike.%$b%,'
          'nombre_forma_pago.ilike.%$b%,'
          'nombre_formaexp.ilike.%$b%,'
          'nombre_usuario.ilike.%$b%,'
          'apodo_usuario.ilike.%$b%,'
          'bien_asegurado.ilike.%$b%,'
          'obs_poliza.ilike.%$b%',
        );
      }

      final res = await query
          .order('fcreado', ascending: false)
          .range(desde, desde + _pageSize - 1);

      final rows = (res as List).cast<Map<String, dynamic>>();
      todos.addAll(rows.map(Poliza.fromMap));

      onProgreso?.call(todos.length);

      if (rows.length < _pageSize) break; // última página
      desde += _pageSize;
    }

    return todos;
  }

  Future<Poliza?> obtenerPoliza(int id) async {
    final res = await _db
        .from(_tabla)
        .select()
        .eq('id', id)
        .maybeSingle();

    if (res == null) return null;
    return Poliza.fromMap(res as Map<String, dynamic>);
  }

  Future<int> obtenerSiguienteId() async {
    final res = await _db
        .from(_tabla)
        .select('id')
        .order('id', ascending: false)
        .limit(1)
        .maybeSingle();

    if (res == null) return 1;
    final ultimoId = (res['id'] as num?)?.toInt() ?? 0;
    return ultimoId + 1;
  }

  Future<bool> existeId(int id) async {
    final res = await _db.from(_tabla).select('id').eq('id', id).maybeSingle();
    return res != null;
  }

  Future<bool> existeNroPoliza(String nroPoliza, {int? excluirId}) async {
    final nro = nroPoliza.trim();
    if (nro.isEmpty) return false;

    dynamic query = _db.from(_tabla).select('id').eq('nro_poliza', nro);

    if (excluirId != null) {
      query = query.neq('id', excluirId);
    }

    final res = await query.maybeSingle();
    return res != null;
  }

  Future<void> crearPoliza(Map<String, dynamic> data) async {
    await _db.from(_tabla).insert(_limpiarMapa(data));
  }

  Future<void> actualizarPoliza(int id, Map<String, dynamic> data) async {
    await _db.from(_tabla).update({
      ..._limpiarMapa(data),
      'fultmod': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> eliminarPoliza(int id) async {
    await _db.from(_tabla).delete().eq('id', id);
  }

  Map<String, dynamic> _limpiarMapa(Map<String, dynamic> data) {
    final limpio = <String, dynamic>{};

    for (final entry in data.entries) {
      final key = entry.key;
      dynamic value = entry.value;

      if (value is String) {
        value = value.trim();
        if (value.isEmpty) value = null;
      }

      if (_camposEnterosNullable.contains(key)) {
        if (value == 0 || value == '0') {
          value = null;
        } else if (value is String) {
          value = int.tryParse(value);
        }
      }

      if (_camposNumericos.contains(key)) {
        if (value is String) {
          final txt = value.replaceAll(',', '.').trim();
          value = txt.isEmpty ? null : num.tryParse(txt);
        }
      }

      limpio[key] = value;
    }

    return limpio;
  }

  static const Set<String> _camposEnterosNullable = {
    'cliente_id',
    'asesor_id',
    'ramo_id',
    'producto_id',
    'intermediario_id',
    'agencia_id',
    'forma_pago_id',
    'asesor2_id',
    'asesor3_id',
    'asesorad_id',
    'agenciaad_id',
    'formaexp_id',
    'aseg_id',
    'usuario_id',
  };

  static const Set<String> _camposNumericos = {
    'prima_poliza',
    'valor_poliza',
    'vlraseg_poliza',
    'porccom_poliza',
    'vlrbasecom_poliza',
    'porcom_agencia',
    'vlrcom_poliza',
    'vlrcomfija_poliza',
    'porcomadic_poliza',
    'vlrcomadic_poliza',
    'porcom_asesor1',
    'vlrprimapagada_poliza',
    'porcom_asesor2',
    'porcom_asesor3',
    'porcom_asesorad',
    'porcom_agenciaad',
  };
}