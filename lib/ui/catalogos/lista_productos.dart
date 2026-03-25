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

  final Map<int, String> _ramoNombreById = {};
  final Map<int, String> _asegNombreById = {};

  final TextEditingController _buscarCtrl = TextEditingController();
  String _filtro = '';

  final ScrollController _verticalCtrl = ScrollController();
  final ScrollController _horizontalCtrl = ScrollController();

  int? _sortColumnIndex;
  bool _sortAscending = true;

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
    _verticalCtrl.dispose();
    _horizontalCtrl.dispose();
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

      prods.sort((a, b) => a.id.compareTo(b.id));

      if (!mounted) return;
      setState(() {
        items = prods;
        _sortColumnIndex = 0;
        _sortAscending = true;
      });
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

  void _sort<T>(
    Comparable<T> Function(Producto p) getField,
    int columnIndex,
    bool ascending,
  ) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;

      items.sort((a, b) {
        final aValue = getField(a);
        final bValue = getField(b);

        return ascending
            ? Comparable.compare(aValue, bValue)
            : Comparable.compare(bValue, aValue);
      });
    });
  }

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
      await repo.eliminarProducto(p.id);
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
      final id = p.id.toString();
      final nombre = p.nombreProd.toLowerCase();
      final ramo = _ramoNombre(p.ramoId).toLowerCase();
      final aseg = _asegNombre(p.aseguradoraId).toLowerCase();
      final desc = (p.descProd ?? '').toLowerCase();
      final obs = (p.obsProd ?? '').toLowerCase();
      final comision = (p.comisionProd?.toString() ?? '').toLowerCase();
      final porcom = (p.porcomProd?.toString() ?? '').toLowerCase();
      final porcad = (p.porcadProd?.toString() ?? '').toLowerCase();
      final estado = p.estadoProd ? 'activo' : 'inactivo';

      return id.contains(_filtro) ||
          nombre.contains(_filtro) ||
          ramo.contains(_filtro) ||
          aseg.contains(_filtro) ||
          desc.contains(_filtro) ||
          obs.contains(_filtro) ||
          comision.contains(_filtro) ||
          porcom.contains(_filtro) ||
          porcad.contains(_filtro) ||
          estado.contains(_filtro);
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
                labelText: 'Buscar (ID, producto, ramo, aseguradora, descripción, observaciones o estado)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          if (cargando) const LinearProgressIndicator(),
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : data.isEmpty
                    ? const Center(child: Text('No hay productos.'))
                    : Scrollbar(
                        controller: _verticalCtrl,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _verticalCtrl,
                          scrollDirection: Axis.vertical,
                          child: Scrollbar(
                            controller: _horizontalCtrl,
                            thumbVisibility: true,
                            notificationPredicate: (_) => true,
                            child: SingleChildScrollView(
                              controller: _horizontalCtrl,
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: MediaQuery.of(context).size.width - 24,
                                ),
                                child: DataTable(
                                  sortColumnIndex: _sortColumnIndex,
                                  sortAscending: _sortAscending,
                                  columnSpacing: 12,
                                  horizontalMargin: 0,
                                  headingRowColor:
                                      WidgetStateProperty.all(Colors.grey.shade200),
                                  columns: [
                                    DataColumn(
                                      label: const Text('ID          '),
                                      numeric: true,
                                      onSort: (columnIndex, ascending) {
                                        _sort<num>(
                                          (p) => p.id,
                                          columnIndex,
                                          ascending,
                                        );
                                      },
                                    ),
                                    DataColumn(
                                      label: const Text('Producto'),
                                      onSort: (columnIndex, ascending) {
                                        _sort<String>(
                                          (p) => p.nombreProd.toLowerCase(),
                                          columnIndex,
                                          ascending,
                                        );
                                      },
                                    ),
                                    DataColumn(
                                      label: const Text('Ramo'),
                                      onSort: (columnIndex, ascending) {
                                        _sort<String>(
                                          (p) => _ramoNombre(p.ramoId).toLowerCase(),
                                          columnIndex,
                                          ascending,
                                        );
                                      },
                                    ),
                                    DataColumn(
                                      label: const Text('Aseguradora'),
                                      onSort: (columnIndex, ascending) {
                                        _sort<String>(
                                          (p) => _asegNombre(p.aseguradoraId).toLowerCase(),
                                          columnIndex,
                                          ascending,
                                        );
                                      },
                                    ),
                                    DataColumn(
                                      label: const Text('Comisión fija'),
                                      onSort: (columnIndex, ascending) {
                                        _sort<num>(
                                          (p) => p.comisionProd ?? 0,
                                          columnIndex,
                                          ascending,
                                        );
                                      },
                                    ),
                                    DataColumn(
                                      label: const Text('% Comisión'),
                                      onSort: (columnIndex, ascending) {
                                        _sort<num>(
                                          (p) => p.porcomProd ?? 0,
                                          columnIndex,
                                          ascending,
                                        );
                                      },
                                    ),
                                    DataColumn(
                                      label: const Text('% Adicional'),
                                      onSort: (columnIndex, ascending) {
                                        _sort<num>(
                                          (p) => p.porcadProd ?? 0,
                                          columnIndex,
                                          ascending,
                                        );
                                      },
                                    ),
                                    DataColumn(
                                      label: const Text('Descripción'),
                                      onSort: (columnIndex, ascending) {
                                        _sort<String>(
                                          (p) => (p.descProd ?? '').toLowerCase(),
                                          columnIndex,
                                          ascending,
                                        );
                                      },
                                    ),
                                    DataColumn(
                                      label: const Text('Observaciones'),
                                      onSort: (columnIndex, ascending) {
                                        _sort<String>(
                                          (p) => (p.obsProd ?? '').toLowerCase(),
                                          columnIndex,
                                          ascending,
                                        );
                                      },
                                    ),
                                    DataColumn(
                                      label: const SizedBox(
                                        width: 90,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text('Estado'),
                                        ),
                                      ),
                                      onSort: (columnIndex, ascending) {
                                        _sort<String>(
                                          (p) => p.estadoProd ? 'activo' : 'inactivo',
                                          columnIndex,
                                          ascending,
                                        );
                                      },
                                    ),
                                    const DataColumn(
                                      label: SizedBox(
                                        width: 100,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text('Acciones'),
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: data.map((p) {
                                    final ramo = _ramoNombre(p.ramoId);
                                    final aseg = _asegNombre(p.aseguradoraId);

                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          SizedBox(
                                            width: 70,
                                            child: Text(p.id.toString()),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 220,
                                            child: Text(
                                              p.nombreProd,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 180,
                                            child: Text(
                                              ramo,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 200,
                                            child: Text(
                                              aseg,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 110,
                                            child: Text(p.comisionProd?.toString() ?? ''),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 100,
                                            child: Text(p.porcomProd?.toString() ?? ''),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 100,
                                            child: Text(p.porcadProd?.toString() ?? ''),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 200,
                                            child: Text(
                                              p.descProd ?? '',
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 220,
                                            child: Text(
                                              p.obsProd ?? '',
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 90,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: Chip(
                                                label: Text(p.estadoProd ? 'Activo' : 'Inactivo'),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 100,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    tooltip: 'Editar',
                                                    icon: const Icon(Icons.edit, size: 20),
                                                    onPressed: () async {
                                                      await Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) => FormProducto(producto: p),
                                                        ),
                                                      );
                                                      _cargar();
                                                    },
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Eliminar',
                                                    icon: const Icon(Icons.delete_outline, size: 20),
                                                    onPressed: () => _eliminar(p),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}