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

  bool _soloActivos = false; // 👈 toggle

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
      // Si ya aplicaste el repo mejorado con {soloActivos}, úsalo:
      final res = await repo.listarAsesores(soloActivos: _soloActivos);

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

  List<Asesor> get _filtrados {
    if (_filtro.isEmpty) return items;

    return items.where((a) {
      final nombre = a.nombreAsesor.toLowerCase();
      final doc = (a.docAsesor ?? '').toLowerCase();
      final tel = (a.telAsesor ?? '').toLowerCase();
      final correo = (a.correoAsesor ?? '').toLowerCase();

      return nombre.contains(_filtro) ||
          doc.contains(_filtro) ||
          tel.contains(_filtro) ||
          correo.contains(_filtro);
    }).toList();
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
      // Tu repo ya puede lanzar Exception(mensajeFK). Mostramos eso:
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
            onPressed: _cargar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo asesor',
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const FormAsesor()));
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
                    labelText: 'Buscar (nombre, doc, tel, correo)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 10),

                // 👇 filtro rápido de activos
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Solo activos'),
                      selected: _soloActivos,
                      onSelected: (v) async {
                        setState(() => _soloActivos = v);
                        await _cargar();
                      },
                    ),
                  ],
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
                    : ListView.separated(
                        itemCount: data.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final a = data[i];

                          final docTxt = [
                            if ((a.tipodocAsesor ?? '').trim().isNotEmpty) a.tipodocAsesor!.trim(),
                            if ((a.docAsesor ?? '').trim().isNotEmpty) a.docAsesor!.trim(),
                          ].join(' ');

                          final parts = <String>[
                            if (docTxt.trim().isNotEmpty) 'Doc: $docTxt',
                            if ((a.telAsesor ?? '').trim().isNotEmpty) 'Tel: ${a.telAsesor!.trim()}',
                            if ((a.correoAsesor ?? '').trim().isNotEmpty) a.correoAsesor!.trim(),
                          ];

                          return ListTile(
                            title: Row(
                              children: [
                                Expanded(child: Text(a.nombreAsesor)),
                                const SizedBox(width: 8),
                                _EstadoChip(activo: a.estadoAsesor),
                              ],
                            ),
                            subtitle: parts.isEmpty ? null : Text(parts.join(' • ')),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                IconButton(
                                  tooltip: 'Editar',
                                  icon: const Icon(Icons.edit),
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => FormAsesor(asesor: a)),
                                    );
                                    _cargar();
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Eliminar',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _eliminar(a),
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
