import 'package:flutter/material.dart';
import '../../datos/catalogos.dart';
import '../../datos/repositorio_catalogos.dart';
import 'form_cliente.dart';

class ListaClientes extends StatefulWidget {
  const ListaClientes({super.key});

  @override
  State<ListaClientes> createState() => _ListaClientesState();
}

class _ListaClientesState extends State<ListaClientes> {
  final repo = RepositorioCatalogos();

  bool cargando = true;
  List<Cliente> items = [];

  // búsqueda local
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
      final res = await repo.listarClientes();
      if (!mounted) return;
      setState(() => items = res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  bool _esErrorRelacion(dynamic e) {
    final s = e.toString();
    return s.contains('23503') || s.toLowerCase().contains('foreign key');
  }

  List<Cliente> get _filtrados {
    if (_filtro.isEmpty) return items;

    return items.where((c) {
      final nombre = c.nombreCliente.toLowerCase();
      final doc = (c.docCliente ?? '').toLowerCase();
      final tel = (c.telCliente ?? '').toLowerCase();
      final correo = (c.correoCliente ?? '').toLowerCase();
      final ciudad = (c.ciudadCliente ?? '').toLowerCase();

      return nombre.contains(_filtro) ||
          doc.contains(_filtro) ||
          tel.contains(_filtro) ||
          correo.contains(_filtro) ||
          ciudad.contains(_filtro);
    }).toList();
  }

  Future<void> _eliminar(Cliente c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text('¿Eliminar "${c.nombreCliente}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await repo.eliminarCliente(c.id);
      await _cargar();
    } catch (e) {
      final msg = _esErrorRelacion(e)
          ? 'No se puede eliminar porque este cliente ya está relacionado con pólizas.'
          : 'Error eliminando: $e';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _filtrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: cargando ? null : _cargar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo cliente',
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const FormCliente()));
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
                labelText: 'Buscar (nombre, doc, tel, correo, ciudad)',
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
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No hay clientes.')),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: data.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = data[i];

                        final docTxt = [
                          if ((c.tipodocCliente ?? '').trim().isNotEmpty) c.tipodocCliente!.trim(),
                          if ((c.docCliente ?? '').trim().isNotEmpty) c.docCliente!.trim(),
                        ].join(' ');

                        final parts = <String>[
                          if (docTxt.trim().isNotEmpty) 'Doc: $docTxt',
                          if ((c.telCliente ?? '').trim().isNotEmpty) 'Tel: ${c.telCliente!.trim()}',
                          if ((c.correoCliente ?? '').trim().isNotEmpty) c.correoCliente!.trim(),
                          if ((c.ciudadCliente ?? '').trim().isNotEmpty) 'Ciudad: ${c.ciudadCliente!.trim()}',
                          if ((c.notasCliente ?? '').trim().isNotEmpty) 'Notas: ${c.notasCliente!.trim()}',
                        ];

                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          isThreeLine: parts.length >= 3,
                          title: Text(c.nombreCliente),
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
                                    MaterialPageRoute(builder: (_) => FormCliente(cliente: c)),
                                  );
                                  _cargar();
                                },
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _eliminar(c),
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
