import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Resultado de leer un reporte de comisiones: la cabecera (aseguradora,
/// fechas del período) y las líneas (una por póliza).
class ReportePagoExtraido {
  final Map<String, dynamic> cabecera;
  final List<Map<String, dynamic>> lineas;
  const ReportePagoExtraido({required this.cabecera, required this.lineas});
}

class RepositorioIA {
  final SupabaseClient _db = Supabase.instance.client;

  /// Envía el archivo de una póliza (PDF o imagen) a la Edge Function
  /// `extraer-poliza`, que le pide a Gemini que extraiga los datos.
  /// Devuelve el mapa con los campos reconocidos (puede venir con valores
  /// null cuando el documento no los trae).
  Future<Map<String, dynamic>> extraerPoliza(
    Uint8List bytes,
    String mimeType,
  ) async {
    final data = await _invoke('extraer-poliza', bytes, mimeType);
    return (data as Map).cast<String, dynamic>();
  }

  /// Envía el archivo de un reporte de comisiones (PDF o imagen) a la Edge
  /// Function `extraer-reporte-pago`, que le pide a Gemini que extraiga la
  /// cabecera (aseguradora, fechas) y todas las líneas/pólizas de la tabla.
  /// Los campos pueden venir null cuando el documento no los trae.
  Future<ReportePagoExtraido> extraerReportePago(
    Uint8List bytes,
    String mimeType,
  ) async {
    final data = ((await _invoke('extraer-reporte-pago', bytes, mimeType))
        as Map).cast<String, dynamic>();
    final cabecera = (data['cabecera'] as Map?)?.cast<String, dynamic>() ?? {};
    final lineas = (data['lineas'] as List? ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    return ReportePagoExtraido(cabecera: cabecera, lineas: lineas);
  }

  Future<dynamic> _invoke(
    String function,
    Uint8List bytes,
    String mimeType,
  ) async {
    try {
      final res = await _db.functions.invoke(
        function,
        body: {
          'fileBase64': base64Encode(bytes),
          'mimeType': mimeType,
        },
      );
      return res.data;
    } on FunctionException catch (e) {
      final detalle = e.details;
      final mensaje = detalle is Map ? detalle['error'] : null;
      throw Exception(mensaje ?? 'Error al leer el documento (${e.status}).');
    }
  }
}
