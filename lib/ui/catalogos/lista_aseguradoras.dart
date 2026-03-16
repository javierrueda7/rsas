import 'package:flutter/material.dart';
import '../../datos/catalogos.dart';
import '../../datos/repositorio_catalogos.dart';
import 'form_aseguradora.dart';

class ListaAseguradoras extends StatefulWidget {
  const ListaAseguradoras({super.key});

  @override
  State<ListaAseguradoras> createState() => _ListaAseguradorasState();
}

class _ListaAseguradorasState extends State<ListaAseguradoras> {
  final repo = RepositorioCatalogos();

  bool cargando = true;
  List<Aseguradora> items = [];

  final TextEditingController _buscarCtrl = TextEditingController();
  String _filtro = '';

  bool _soloActivas = false;

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
      final res = await repo.listarAseguradoras(soloActivas: _soloActivas);
      if (!mounted) return;
      setState(() => items = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  bool _esErrorRelacion(dynamic e) {
    final s = e.toString();
    return s.contains('23503') || s.toLowerCase().contains('foreign key');
  }

  void _sort<T>(
    Comparable<T> Function(Aseguradora a) getField,
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

  List<Aseguradora> get _filtrados {
    Iterable<Aseguradora> data = items;

    if (_soloActivas) {
      data = data.where((a) => a.estadoAseg == true);
    }

    if (_filtro.isNotEmpty) {
      data = data.where((a) {
        final nombre = a.nombreAseg.toLowerCase();
        final nit = (a.nitAseg ?? '').toLowerCase();
        final clave = (a.clave ?? '').toLowerCase();
        final estado = a.estadoAseg ? 'activo' : 'inactivo';
        return nombre.contains(_filtro) ||
            nit.contains(_filtro) ||
            clave.contains(_filtro) ||
            estado.contains(_filtro);
      });
    }

    return data.toList();
  }

  Future<void> _eliminar(Aseguradora a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar aseguradora'),
        content: Text('¿Eliminar "${a.nombreAseg}"?'),
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
      await repo.eliminarAseguradora(a.id);
      await _cargar();
    } catch (e) {
      final msg = _esErrorRelacion(e)
          ? 'No se puede eliminar porque esta aseguradora está relacionada con productos o pólizas.'
          : 'Error eliminando: $e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _filtrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aseguradoras'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nueva aseguradora',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FormAseguradora()),
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
                  decoration: const InputDecoration(
                    labelText: 'Buscar (nombre, NIT o clave)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _soloActivas,
                  onChanged: (v) async {
                    setState(() => _soloActivas = v);
                    await _cargar();
                  },
                  title: const Text('Solo activas'),
                  subtitle: Text(
                    _soloActivas
                        ? 'Mostrando solo aseguradoras activas'
                        : 'Mostrando activas e inactivas',
                  ),
                ),
              ],
            ),
          ),
          if (cargando) const LinearProgressIndicator(),
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : data.isEmpty
                    ? const Center(child: Text('No hay aseguradoras.'))
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
                                      label: const Text('Nombre'),
                                      onSort: (columnIndex, ascending) {
                                        _sort<String>(
                                          (a) => a.nombreAseg.toLowerCase(),
                                          columnIndex,
                                          ascending,
                                        );
                                      },
                                    ),
                                    DataColumn(
                                      label: const Text('Clave'),
                                      onSort: (columnIndex, ascending) {
                                        _sort<String>(
                                          (a) => (a.clave ?? '').toLowerCase(),
                                          columnIndex,
                                          ascending,
                                        );
                                      },
                                    ),
                                    DataColumn(
                                      label: const Text('NIT'),
                                      onSort: (columnIndex, ascending) {
                                        _sort<String>(
                                          (a) => (a.nitAseg ?? '').toLowerCase(),
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
                                          (a) => a.estadoAseg ? 'activo' : 'inactivo',
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
                                  rows: data.map((a) {
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          SizedBox(
                                            width: 320,
                                            child: Text(
                                              a.nombreAseg,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 70,
                                            child: Text(a.clave ?? ''),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 130,
                                            child: Text(a.nitAseg ?? ''),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 90,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: Chip(
                                                label: Text(a.estadoAseg ? 'Activo' : 'Inactivo'),
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
                                                    icon: const Icon(Icons.edit, size: 20),
                                                    onPressed: () async {
                                                      await Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              FormAseguradora(aseguradora: a),
                                                        ),
                                                      );
                                                      _cargar();
                                                    },
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline, size: 20),
                                                    onPressed: () => _eliminar(a),
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