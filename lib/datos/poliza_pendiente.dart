class PolizaPendiente {
  final int id;
  final String estado; // 'borrador' | 'pendiente_revision'
  final Map<String, dynamic> datos;
  final String? nombreArchivo;
  final String origen;
  final String? errorMsg;
  final DateTime fcreado;
  final DateTime fultmod;

  PolizaPendiente({
    required this.id,
    required this.estado,
    required this.datos,
    this.nombreArchivo,
    required this.origen,
    this.errorMsg,
    required this.fcreado,
    required this.fultmod,
  });

  factory PolizaPendiente.fromMap(Map<String, dynamic> m) => PolizaPendiente(
        id: (m['id'] as num).toInt(),
        estado: m['estado'] as String? ?? 'borrador',
        datos: (m['datos'] as Map?)?.cast<String, dynamic>() ?? {},
        nombreArchivo: m['nombre_archivo'] as String?,
        origen: m['origen'] as String? ?? 'manual',
        errorMsg: m['error_msg'] as String?,
        fcreado: DateTime.parse(m['fcreado'] as String),
        fultmod: DateTime.parse(m['fultmod'] as String),
      );

  /// Texto corto para mostrar en la lista de pendientes: nombre del cliente
  /// o número de póliza extraído, lo que haya.
  String get resumen {
    final nombre = (datos['nombre_cliente'] ?? datos['nro_poliza'])?.toString();
    return (nombre == null || nombre.trim().isEmpty) ? 'Sin datos' : nombre.trim();
  }
}
