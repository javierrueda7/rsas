import 'package:supabase_flutter/supabase_flutter.dart';
import 'abono_poliza.dart';
import 'sesion.dart';

class RepositorioPagos {
  final SupabaseClient _db = Supabase.instance.client;

  static const String _vistaReportes = 'vw_reportes_resumen';
  static const String _vistaAbonos   = 'vw_abonos_detalle';
  static const String _tablaReportes = 'reportes_pago';
  static const String _tablaAbonos   = 'abonos_poliza';

  static const String _colsReporte =
      'id, fecha_rep, aseg_id, interm_id, fini_rep, ffin_rep, '
      'vlrprima_rep, vlrsumprima_rep, vlrcom_rep, vlrsumcom_rep, '
      'estado_rep, obs_rep, usuario_id, fcreado, fultmod, '
      'nombre_aseg, nombre_interm, num_abonos';

  static const String _colsAbono =
      'id, idrep_pago, id_poliza, fecha_pago, vlrprima_poliza, vlrabono_prima, '
      'porccomision, vlrcomision, porccomad, vlrcomad, '
      'idfactura, num_factura, estado_pago, obs_pago, usuario_id, fcreado, fultmod, '
      'nro_poliza, prima_poliza, bien_asegurado, fini_poliza, ffin_poliza, estado_poliza_id, '
      'nombre_cliente, doc_cliente, tipodoc_cliente, tel_cliente, correo_cliente, dir_cliente, '
      'nombre_ramo, nombre_prod, nombre_aseg, apodo_usuario, nombre_usuario';

  // ── REPORTES ───────────────────────────────────────────────────────────────

  Future<List<ReportePago>> listarReportes({
    String busqueda = '',
    int limite = 300,
  }) async {
    final q = busqueda.trim();
    dynamic req = _db.from(_vistaReportes).select(_colsReporte);
    if (q.isNotEmpty) {
      req = req.or('nombre_aseg.ilike.%$q%,nombre_interm.ilike.%$q%');
    }
    final res = await req.order('fecha_rep', ascending: false).limit(limite);
    return (res as List).cast<Map<String, dynamic>>().map(ReportePago.fromMap).toList();
  }

  Future<ReportePago?> obtenerReporte(int id) async {
    final res = await _db
        .from(_vistaReportes)
        .select(_colsReporte)
        .eq('id', id)
        .maybeSingle();
    return res == null ? null : ReportePago.fromMap(res);
  }

  Future<int> crearReporte(Map<String, dynamic> data) async {
    data['usuario_id'] = Sesion.usuarioId;
    final res = await _db.from(_tablaReportes).insert(data).select('id').single();
    return (res['id'] as num).toInt();
  }

  Future<void> actualizarReporte(int id, Map<String, dynamic> data) async {
    data['fultmod'] = DateTime.now().toIso8601String();
    await _db.from(_tablaReportes).update(data).eq('id', id);
  }

  Future<void> eliminarReporte(int id) async {
    await _db.from(_tablaReportes).delete().eq('id', id);
  }

  /// Recalcula vlrsumprima_rep y vlrsumcom_rep sumando los abonos vigentes.
  Future<void> recalcularTotales(int idReporte) async {
    final abonos = await listarAbonosPorReporte(idReporte);
    final sumPrima = abonos.fold<num>(0, (s, a) => s + a.vlrabonoprima);
    final sumCom   = abonos.fold<num>(0, (s, a) => s + a.vlrcomision + a.vlrcomad);
    await _db.from(_tablaReportes).update({
      'vlrsumprima_rep': sumPrima,
      'vlrsumcom_rep': sumCom,
      'fultmod': DateTime.now().toIso8601String(),
    }).eq('id', idReporte);
  }

  // ── ABONOS ─────────────────────────────────────────────────────────────────

  Future<List<AbonoPoliza>> listarAbonosPorReporte(int idReporte) async {
    final res = await _db
        .from(_vistaAbonos)
        .select(_colsAbono)
        .eq('idrep_pago', idReporte)
        .order('id', ascending: true);
    return (res as List).cast<Map<String, dynamic>>().map(AbonoPoliza.fromMap).toList();
  }

  Future<List<AbonoPoliza>> listarAbonosPorPoliza(int idPoliza) async {
    final res = await _db
        .from(_vistaAbonos)
        .select(_colsAbono)
        .eq('id_poliza', idPoliza)
        .order('fecha_pago', ascending: false);
    return (res as List).cast<Map<String, dynamic>>().map(AbonoPoliza.fromMap).toList();
  }

  Future<AbonoPoliza?> obtenerAbono(int id) async {
    final res = await _db
        .from(_vistaAbonos)
        .select(_colsAbono)
        .eq('id', id)
        .maybeSingle();
    return res == null ? null : AbonoPoliza.fromMap(res);
  }

  Future<int> crearAbono(Map<String, dynamic> data) async {
    data['usuario_id'] = Sesion.usuarioId;
    final res = await _db.from(_tablaAbonos).insert(data).select('id').single();
    return (res['id'] as num).toInt();
  }

  Future<void> actualizarAbono(int id, Map<String, dynamic> data) async {
    data['fultmod'] = DateTime.now().toIso8601String();
    await _db.from(_tablaAbonos).update(data).eq('id', id);
  }

  Future<void> eliminarAbono(int id) async {
    await _db.from(_tablaAbonos).delete().eq('id', id);
  }

  /// Resumen de pagos para una póliza (estado de cuenta).
  Future<Map<String, dynamic>> resumenPorPoliza(int idPoliza) async {
    final abonos = await listarAbonosPorPoliza(idPoliza);
    final totalAbonado  = abonos.fold<num>(0, (s, a) => s + a.vlrabonoprima);
    final totalComision = abonos.fold<num>(0, (s, a) => s + a.vlrcomision + a.vlrcomad);
    final prima = abonos.isNotEmpty ? (abonos.first.primaPoliza ?? 0) : 0;
    return {
      'abonos': abonos,
      'totalAbonado': totalAbonado,
      'totalComision': totalComision,
      'primaPoliza': prima,
      'saldo': prima - totalAbonado,
      'porcPagado': prima > 0 ? (totalAbonado / prima * 100) : 0.0,
    };
  }
}
