import 'package:flutter/material.dart';
import '../../datos/catalogos.dart';
import '../../datos/repositorio_catalogos.dart';
import 'form_asesor.dart';

class ListaAsesores extends StatefulWidget {
  const ListaAsesores({super.key});

  @override
  State<ListaAsesores> createState() => _ListaAsesoresState();
}

class _ListaAsesoresState extends State<ListaAsesores> {
  final repo = RepositorioCatalogos();

  bool cargando = true;
  List<Asesor> items = [];

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
      final res = await repo.listarAsesores(soloActivos: _soloActivos);

      res.sort((a, b) => a.id.compareTo(b.id)); // 👈 orden inicial

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

  void _sort<T>(
    Comparable<T> Function(Asesor a) getField,
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

  List<Asesor> get _filtrados {
    Iterable<Asesor> data = items;

    if (_soloActivos) {
      data = data.where((a) => a.estadoAsesor);
    }

    if (_filtro.isNotEmpty) {
      data = data.where((a) {
        final id = a.id.toString();
        final nombre = a.nombreAsesor.toLowerCase();
        final doc = (a.docAsesor ?? '').toLowerCase();
        final tel = (a.telAsesor ?? '').toLowerCase();
        final correo = (a.correoAsesor ?? '').toLowerCase();
        final estado = a.estadoAsesor ? 'activo' : 'inactivo';

        return id.contains(_filtro) ||
            nombre.contains(_filtro) ||
            doc.contains(_filtro) ||
            tel.contains(_filtro) ||
            correo.contains(_filtro) ||
            estado.contains(_filtro);
      });
    }

    return data.toList();
  }

  Future<void> _eliminar(Asesor a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar asesor'),
        content: Text('¿Eliminar "${a.nombreAsesor}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await repo.eliminarAsesor(a.id);
      await _cargar();
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _filtrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asesores'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: cargando ? null : _cargar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo asesor',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FormAsesor()),
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
                    labelText: 'Buscar (ID, nombre, doc, tel, correo o estado)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _soloActivos,
                  onChanged: (v) async {
                    setState(() => _soloActivos = v);
                    await _cargar();
                  },
                  title: const Text('Solo activos'),
                ),
              ],
            ),
          ),
          if (cargando) const LinearProgressIndicator(),
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : data.isEmpty
                    ? const Center(child: Text('No hay asesores.'))
                    : Scrollbar(
                        controller: _verticalCtrl,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _verticalCtrl,
                          child: Scrollbar(
                            controller: _horizontalCtrl,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _horizontalCtrl,
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                sortColumnIndex: _sortColumnIndex,
                                sortAscending: _sortAscending,
                                columns: [
                                  DataColumn(
                                    label: const Text('ID'),
                                    onSort: (i, asc) => _sort<num>((a) => a.id, i, asc),
                                  ),
                                  DataColumn(
                                    label: const Text('Nombre'),
                                    onSort: (i, asc) =>
                                        _sort<String>((a) => a.nombreAsesor.toLowerCase(), i, asc),
                                  ),
                                  DataColumn(
                                    label: const Text('Documento'),
                                    onSort: (i, asc) =>
                                        _sort<String>((a) => (a.docAsesor ?? ''), i, asc),
                                  ),
                                  DataColumn(
                                    label: const Text('Teléfono'),
                                  ),
                                  DataColumn(
                                    label: const Text('Correo'),
                                  ),
                                  DataColumn(
                                    label: const Text('%'),
                                    onSort: (i, asc) =>
                                        _sort<num>((a) => a.porccomAsesor ?? 0, i, asc),
                                  ),
                                  DataColumn(
                                    label: const Text('Estado'),
                                  ),
                                  const DataColumn(label: Text('Acciones')),
                                ],
                                rows: data.map((a) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(a.id.toString())),
                                      DataCell(Text(a.nombreAsesor)),
                                      DataCell(Text(
                                          '${a.tipodocAsesor ?? ''} ${a.docAsesor ?? ''}')),
                                      DataCell(Text(a.telAsesor ?? '')),
                                      DataCell(Text(a.correoAsesor ?? '')),
                                      DataCell(Text(a.porccomAsesor?.toString() ?? '')),
                                      DataCell(
                                        Chip(
                                          label: Text(
                                            a.estadoAsesor ? 'Activo' : 'Inactivo',
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit),
                                              onPressed: () async {
                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        FormAsesor(asesor: a),
                                                  ),
                                                );
                                                _cargar();
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline),
                                              onPressed: () => _eliminar(a),
                                            ),
                                          ],
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
        ],
      ),
    );
  }
}