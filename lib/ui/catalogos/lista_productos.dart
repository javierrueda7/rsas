import 'package:flutter/material.dart';
import '../../datos/catalogos.dart';
import '../../datos/repositorio_catalogos.dart';
import 'form_producto.dart';

class ListaProductos extends StatefulWidget {
  const ListaProductos({super.key});

  @override
  State<ListaProductos> createState() => _ListaProductosState();
}

class _ListaProductosState extends State<ListaProductos> {
  final repo = RepositorioCatalogos();

  bool cargando = true;
  List<Producto> items = [];

  // Lookups para mostrar nombres (✅ ahora int -> String)
  final Map<int, String> _ramoNombreById = {};
  final Map<int, String> _asegNombreById = {};

  // Búsqueda local
  final TextEditingController _buscarCtrl = TextEditingController();
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _cargar();
    _buscarCtrl.addListener(() {
      setState(() => _filtro = _buscarCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => cargando = true);
    try {
      final res = await Future.wait([
        repo.listarProductos(),
        repo.listarRamos(),
        repo.listarAseguradoras(),
      ]);

      final prods = res[0] as List<Producto>;
      final ramos = res[1] as List<Ramo>;
      final aseg = res[2] as List<Aseguradora>;

      _ramoNombreById
        ..clear()
        ..addEntries(ramos.map((r) => MapEntry(r.id, r.nombreRamo)));

      _asegNombreById
        ..clear()
        ..addEntries(aseg.map((a) => MapEntry(a.id, a.nombreAseg)));

      if (!mounted) return;
      setState(() => items = prods);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  bool _esErrorRelacion(dynamic e) {
    final s = e.toString();
    return s.contains('23503') || s.toLowerCase().contains('foreign key');
  }

  String _ramoNombre(int ramoId) => _ramoNombreById[ramoId] ?? 'Ramo desconocido';
  String _asegNombre(int asegId) => _asegNombreById[asegId] ?? 'Aseguradora desconocida';

  Future<void> _eliminar(Producto p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${p.nombreProd}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await repo.eliminarProducto(p.id); // ✅ p.id es int
      await _cargar();
    } catch (e) {
      final msg = _esErrorRelacion(e)
          ? 'No se puede eliminar porque este producto ya está relacionado con pólizas.'
          : 'Error eliminando: $e';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  List<Producto> get _filtrados {
    if (_filtro.isEmpty) return items;

    return items.where((p) {
      final nombre = p.nombreProd.toLowerCase();
      final ramo = _ramoNombre(p.ramoId).toLowerCase();
      final aseg = _asegNombre(p.aseguradoraId).toLowerCase();
      return nombre.contains(_filtro) || ramo.contains(_filtro) || aseg.contains(_filtro);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final data = _filtrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: cargando ? null : _cargar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo producto',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FormProducto()),
          );
          _cargar();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _buscarCtrl,
              decoration: const InputDecoration(
                labelText: 'Buscar (producto, ramo o aseguradora)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          if (cargando) const LinearProgressIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _cargar,
              child: data.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No hay productos.')),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: data.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = data[i];
                        final ramo = _ramoNombre(p.ramoId);
                        final aseg = _asegNombre(p.aseguradoraId);

                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.inventory_2)),
                          title: Row(
                            children: [
                              Expanded(child: Text(p.nombreProd)),
                              const SizedBox(width: 8),
                              _EstadoChip(activo: p.estadoProd),
                            ],
                          ),
                          subtitle: Text('$ramo • $aseg'),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                icon: const Icon(Icons.edit),
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => FormProducto(producto: p)),
                                  );
                                  _cargar();
                                },
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _eliminar(p),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  final bool activo;
  const _EstadoChip({required this.activo});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(activo ? 'Activo' : 'Inactivo'),
      visualDensity: VisualDensity.compact,
    );
  }
}
