import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../datos/servicio_carga_masiva.dart';
import 'pagina_polizas_pendientes.dart';
import 'theme/app_layout.dart';
import 'theme/app_theme.dart';

/// Selecciona varios PDF/imágenes de una sola vez y los manda a
/// ServicioCargaMasiva, que los procesa uno por uno EN SEGUNDO PLANO — se
/// puede salir de esta pantalla, seguir usando el resto de la app, y el
/// lote sigue corriendo igual. Cada resultado queda como "Pendiente de
/// revisión" en la bandeja de trabajo — nadie queda guardado como póliza
/// real hasta que alguien lo revise y complete desde ahí.
class PaginaCargaMasivaPolizas extends StatefulWidget {
  const PaginaCargaMasivaPolizas({super.key});

  @override
  State<PaginaCargaMasivaPolizas> createState() => _PaginaCargaMasivaPolizasState();
}

class _PaginaCargaMasivaPolizasState extends State<PaginaCargaMasivaPolizas> {
  final _servicio = ServicioCargaMasiva.instance;

  static String? _mimeDeExtension(String ext) => switch (ext.toLowerCase()) {
        'pdf' => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => null,
      };

  @override
  void initState() {
    super.initState();
    _servicio.addListener(_onCambio);
  }

  @override
  void dispose() {
    _servicio.removeListener(_onCambio);
    super.dispose();
  }

  void _onCambio() {
    if (mounted) setState(() {});
  }

  Future<void> _seleccionarArchivos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final items = <ItemCargaMasiva>[];
    for (final f in result.files) {
      final bytes = f.bytes;
      final mime = _mimeDeExtension(f.extension ?? '');
      if (bytes == null || mime == null) continue;
      items.add(ItemCargaMasiva(nombre: f.name, bytes: bytes, mimeType: mime));
    }
    _servicio.agregarArchivos(items);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = _servicio.items;
    final ok = items.where((i) => i.estado == EstadoArchivoCarga.ok).length;
    final errores = items.where((i) => i.estado == EstadoArchivoCarga.error).length;
    final terminado = !_servicio.procesando && items.isNotEmpty &&
        _servicio.procesados == items.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Carga masiva de pólizas')),
      body: AppLayout.centered(Padding(
        padding: AppLayout.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seleccioná varios PDF o imágenes de pólizas. Cada uno se manda a la IA y '
              'queda como "Pendiente de revisión" — podés salir de esta pantalla y seguir '
              'usando la app mientras se procesan, no hace falta esperar acá.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _servicio.procesando ? null : _seleccionarArchivos,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Seleccionar archivos'),
                ),
                const SizedBox(width: 12),
                if (items.isNotEmpty)
                  FilledButton.icon(
                    onPressed: (_servicio.procesando || terminado)
                        ? null
                        : () => _servicio.procesarTodos(),
                    icon: _servicio.procesando
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome_outlined),
                    label: Text(_servicio.procesando
                        ? 'Procesando ${_servicio.procesados}/${items.length}...'
                        : 'Procesar ${items.length} archivo(s)'),
                  ),
              ],
            ),
            if (_servicio.procesando) ...[
              const SizedBox(height: 12),
              Text(
                'Esto sigue corriendo aunque salgas de esta pantalla.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
            if (terminado) ...[
              const SizedBox(height: 12),
              Card(
                color: AppTheme.warningContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: AppTheme.onWarningContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$ok predigitada(s), $errores con error. Revisalas desde "Pólizas pendientes".',
                          style: TextStyle(color: AppTheme.onWarningContainer),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const PaginaPolizasPendientes()),
                        ),
                        child: const Text('Ir a Pendientes'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text('No hay archivos seleccionados todavía.',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => _fila(items[i]),
                    ),
            ),
          ],
        ),
      )),
    );
  }

  Widget _fila(ItemCargaMasiva item) {
    final cs = Theme.of(context).colorScheme;
    final (icono, color) = switch (item.estado) {
      EstadoArchivoCarga.pendiente => (Icons.schedule, cs.onSurfaceVariant),
      EstadoArchivoCarga.procesando => (Icons.hourglass_top, cs.primary),
      EstadoArchivoCarga.ok => (Icons.check_circle, AppTheme.green),
      EstadoArchivoCarga.error => (Icons.error_outline, AppTheme.danger),
    };
    return ListTile(
      dense: true,
      leading: item.estado == EstadoArchivoCarga.procesando
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icono, color: color),
      title: Text(item.nombre, overflow: TextOverflow.ellipsis),
      subtitle: item.error != null
          ? Text(item.error!, style: TextStyle(color: AppTheme.danger, fontSize: 12))
          : null,
    );
  }
}
