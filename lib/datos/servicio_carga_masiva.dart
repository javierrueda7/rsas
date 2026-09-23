import 'package:flutter/foundation.dart';

import 'repositorio_catalogos.dart';
import 'repositorio_ia.dart';
import 'repositorio_polizas_pendientes.dart';

enum EstadoArchivoCarga { pendiente, procesando, ok, error }

class ItemCargaMasiva {
  final String nombre;
  final Uint8List bytes;
  final String mimeType;
  EstadoArchivoCarga estado = EstadoArchivoCarga.pendiente;
  String? error;
  ItemCargaMasiva({required this.nombre, required this.bytes, required this.mimeType});
}

/// Procesa la carga masiva de pólizas en segundo plano — vive fuera del
/// ciclo de vida de cualquier pantalla, así que el usuario puede navegar
/// a otras partes de la app (o cerrar la pantalla de carga) sin que el
/// lote se interrumpa. Un solo lote a la vez.
class ServicioCargaMasiva extends ChangeNotifier {
  ServicioCargaMasiva._();
  static final ServicioCargaMasiva instance = ServicioCargaMasiva._();

  final _repoIA = RepositorioIA();
  final _repoPend = RepositorioPolizasPendientes();
  final _repoCat = RepositorioCatalogos();

  List<ItemCargaMasiva> items = [];
  bool procesando = false;
  int procesados = 0;

  void agregarArchivos(List<ItemCargaMasiva> nuevos) {
    if (procesando) return;
    items = nuevos;
    procesados = 0;
    notifyListeners();
  }

  void limpiar() {
    if (procesando) return;
    items = [];
    procesados = 0;
    notifyListeners();
  }

  Future<void> procesarTodos() async {
    if (procesando || items.isEmpty) return;
    procesando = true;
    procesados = 0;
    notifyListeners();

    final catalogo = await _repoCat.catalogoProductosParaIA();

    for (final item in items) {
      item.estado = EstadoArchivoCarga.procesando;
      notifyListeners();
      try {
        final datos = await _repoIA.extraerPoliza(item.bytes, item.mimeType,
            catalogoProductos: catalogo);
        await _repoPend.crear(
          estado: 'pendiente_revision',
          datos: datos,
          nombreArchivo: item.nombre,
          origen: 'ia_carga_masiva',
        );
        item.estado = EstadoArchivoCarga.ok;
      } catch (e) {
        // Se deja registrada igual, con el error a la vista, en vez de
        // perderse en silencio — se puede reintentar a mano después.
        try {
          await _repoPend.crear(
            estado: 'pendiente_revision',
            datos: const {},
            nombreArchivo: item.nombre,
            origen: 'ia_carga_masiva',
            errorMsg: '$e',
          );
        } catch (_) {}
        item.estado = EstadoArchivoCarga.error;
        item.error = '$e';
      }
      procesados++;
      notifyListeners();
    }

    procesando = false;
    notifyListeners();
  }
}
