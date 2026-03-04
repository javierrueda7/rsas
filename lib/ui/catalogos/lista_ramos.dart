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

  // búsqueda local
  final TextEditingController _buscarCtrl = TextEditingController();
  String _filtro = '';

  // filtro activos
  bool _soloActivos = false;

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
      final res = await repo.listarRamos();
      if (!mounted) return;
      setState(() => items = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  bool _esErrorRelacion(dynamic e) {
    final s = e.toString();
    return s.contains('23503') || s.toLowerCase().contains('foreign key');
  }

  List<Ramo> get _filtrados {
    Iterable<Ramo> data = items;

    if (_soloActivos) {
      data = data.where((r) => r.estadoRamo == true);
    }

    if (_filtro.isNotEmpty) {
      data = data.where((r) => r.nombreRamo.toLowerCase().contains(_filtro));
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
            onPressed: _cargar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo ramo',
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const FormRamo()));
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
              decoration: InputDecoration(
                labelText: 'Buscar (nombre del ramo)',
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
          ),

          // Toggle Solo activos
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SwitchListTile(
              value: _soloActivos,
              onChanged: (v) => setState(() => _soloActivos = v),
              title: const Text('Solo activos'),
              subtitle: Text(_soloActivos ? 'Mostrando solo ramos activos' : 'Mostrando todos'),
              contentPadding: EdgeInsets.zero,
            ),
          ),

          if (cargando) const LinearProgressIndicator(),
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : data.isEmpty
                    ? const Center(child: Text('No hay ramos.'))
                    : ListView.separated(
                        itemCount: data.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final r = data[i];
                          return ListTile(
                            title: Row(
                              children: [
                                Expanded(child: Text(r.nombreRamo)),
                                const SizedBox(width: 8),
                                _EstadoChip(activo: r.estadoRamo),
                              ],
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                IconButton(
                                  tooltip: 'Editar',
                                  icon: const Icon(Icons.edit),
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => FormRamo(ramo: r)),
                                    );
                                    _cargar();
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Eliminar',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _eliminar(r),
                                ),
                              ],
                            ),
                          );
                        },
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
