import 'package:flutter/material.dart';
import '../../datos/catalogos.dart';
import '../../datos/repositorio_catalogos.dart';
import 'form_ramo.dart';

class ListaRamos extends StatefulWidget {
  const ListaRamos({super.key});

  @override
  State<ListaRamos> createState() => _ListaRamosState();
}

class _ListaRamosState extends State<ListaRamos> {
  final repo = RepositorioCatalogos();

  bool cargando = true;
  List<Ramo> items = [];

  final TextEditingController _buscarCtrl = TextEditingController();
  String _filtro = '';

  bool _soloActivos = false;

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
      final res = await repo.listarRamos(soloActivos: _soloActivos);

      res.sort((a, b) => a.id.compareTo(b.id));

      if (!mounted) return;
      setState(() {
        items = res;
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

  void _sort<T>(
    Comparable<T> Function(Ramo r) getField,
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

  List<Ramo> get _filtrados {
    Iterable<Ramo> data = items;

    if (_soloActivos) {
      data = data.where((r) => r.estadoRamo);
    }

    if (_filtro.isNotEmpty) {
      data = data.where((r) {
        final id = r.id.toString();
        final nombre = r.nombreRamo.toLowerCase();
        final obs = (r.obsRamo ?? '').toLowerCase();
        final porcom = r.porcomBaseRamo.toString().toLowerCase();
        final estado = r.estadoRamo ? 'activo' : 'inactivo';

        return id.contains(_filtro) ||
            nombre.contains(_filtro) ||
            obs.contains(_filtro) ||
            porcom.contains(_filtro) ||
            estado.contains(_filtro);
      });
    }

    return data.toList();
  }

  Future<void> _eliminar(Ramo r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar ramo'),
        content: Text('¿Eliminar "${r.nombreRamo}"?'),
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
      await repo.eliminarRamo(r.id);
      await _cargar();
    } catch (e) {
      final msg = _esErrorRelacion(e)
          ? 'No se puede eliminar porque este ramo está relacionado con productos o pólizas.'
          : 'Error eliminando: $e';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _filtrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ramos'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: cargando ? null : _cargar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo ramo',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FormRamo()),
          );
          _cargar();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              children: [
                TextField(
                  controller: _buscarCtrl,
                  decoration: InputDecoration(
                    labelText: 'Buscar (ID, nombre, observaciones, % base o estado)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _filtro.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar',
                            icon: const Icon(Icons.clear),
                            onPressed: () => _buscarCtrl.clear(),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _soloActivos,
                  onChanged: (v) async {
                    setState(() => _soloActivos = v);
                    await _cargar();
                  },
                  title: const Text('Solo activos'),
                  subtitle: Text(
                    _soloActivos ? 'Mostrando solo ramos activos' : 'Mostrando todos',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          if (cargando) const LinearProgressIndicator(),
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : data.isEmpty
                    ? const Center(child: Text('No hay ramos.'))
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
                                  horizontalMargin: 8,
                                  headingRowColor:
                                      WidgetStateProperty.all(Colors.grey.shade200),
                                  columns: [
                                    DataColumn(
                                      label: const Text('ID              '),
                                      numeric: true,
                                      onSort: (columnIndex, ascending) {
                                        _sort<num>(
                                          (r) => r.id,
                                          columnIndex,
                                          ascending,
                                        );
                                      },
                                    ),
                                    DataColumn(
                                      label: const Text('Nombre'),
                                      onSort: (columnIndex, ascending) {
                                        _sort<String>(
                                          (r) => r.nombreRamo.toLowerCase(),
                                          columnIndex,
                                          ascending,
                                        );
                                      },
                                    ),
                                    DataColumn(
                                      label: const Text('% Base'),
                                      onSort: (columnIndex, ascending) {
                                        _sort<num>(
                                          (r) => r.porcomBaseRamo,
                                          columnIndex,
                                          ascending,
                                        );
                                      },
                                    ),
                                    DataColumn(
                                      label: const Text('Observaciones'),
                                      onSort: (columnIndex, ascending) {
                                        _sort<String>(
                                          (r) => (r.obsRamo ?? '').toLowerCase(),
                                          columnIndex,
                                          ascending,
                                        );
                                      },
                                    ),
                                    DataColumn(
                                      label: const SizedBox(
                                        width: 90,
                                        child: Align(
                                          alignment: Alignment.center,
                                          child: Text('Estado'),
                                        ),
                                      ),
                                      onSort: (columnIndex, ascending) {
                                        _sort<String>(
                                          (r) => r.estadoRamo ? 'activo' : 'inactivo',
                                          columnIndex,
                                          ascending,
                                        );
                                      },
                                    ),
                                    const DataColumn(
                                      label: SizedBox(
                                        width: 100,
                                        child: Align(
                                          alignment: Alignment.center,
                                          child: Text('Acciones'),
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: data.map((r) {
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          SizedBox(
                                            width: 70,
                                            child: Text(r.id.toString()),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 220,
                                            child: Text(
                                              r.nombreRamo,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 90,
                                            child: Text(r.porcomBaseRamo.toString()),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 280,
                                            child: Text(
                                              r.obsRamo ?? '',
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
                                                label: Text(
                                                  r.estadoRamo ? 'Activo' : 'Inactivo',
                                                ),
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
                                                          builder: (_) => FormRamo(ramo: r),
                                                        ),
                                                      );
                                                      _cargar();
                                                    },
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Eliminar',
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      size: 20,
                                                    ),
                                                    onPressed: () => _eliminar(r),
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