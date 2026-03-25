import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'pagina_catalogos.dart';
import '../datos/poliza.dart';
import '../datos/repositorio_polizas.dart';
import 'pagina_formulario_polizas.dart';

class PaginaPolizas extends StatefulWidget {
  const PaginaPolizas({super.key});

  @override
  State<PaginaPolizas> createState() => _PaginaPolizasState();
}

class _PaginaPolizasState extends State<PaginaPolizas> {
  final repo = RepositorioPolizas();
  final ctrlBuscar = TextEditingController();
  final df = DateFormat('yyyy-MM-dd');
  final nf = NumberFormat.decimalPattern('es_CO');

  bool cargando = false;
  List<Poliza> polizas = [];

  StreamSubscription? subRealtime;
  Timer? debounce;

  @override
  void initState() {
    super.initState();
    _cargar();

    subRealtime = repo.escucharCambios().listen((_) {
      _cargar(silencioso: true);
    });
  }

  @override
  void dispose() {
    ctrlBuscar.dispose();
    subRealtime?.cancel();
    debounce?.cancel();
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso && mounted) {
      setState(() => cargando = true);
    }

    try {
      final data = await repo.listar(busqueda: ctrlBuscar.text);
      if (mounted) {
        setState(() => polizas = data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando pólizas: $e')),
        );
      }
    } finally {
      if (!silencioso && mounted) {
        setState(() => cargando = false);
      }
    }
  }

  void _onBuscarChanged(String _) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), _cargar);
  }

  String _fmtFecha(DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    return df.format(fecha);
  }

  String _fmtNum(num? valor) {
    if (valor == null) return '0';
    return nf.format(valor);
  }

  String _primerNoVacio(
    List<String?> valores, {
    String fallback = 'Sin dato',
  }) {
    for (final v in valores) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pólizas'),
        actions: [
          IconButton(
            tooltip: 'Nueva póliza',
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PaginaFormularioPolizas(),
                ),
              );
              _cargar();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Catálogos',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaginaCatalogos()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: ctrlBuscar,
              onChanged: _onBuscarChanged,
              decoration: const InputDecoration(
                labelText:
                    'Buscar por póliza, cliente, documento, aseguradora, ramo, producto, asesor, etc.',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          if (cargando) const LinearProgressIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _cargar,
              child: polizas.isEmpty && !cargando
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text('No se encontraron pólizas'),
                        ),
                      ],
                    )
                  : ListView.separated(
                      itemCount: polizas.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = polizas[i];

                        final titulo =
                            'Código: ${p.id} • Póliza: ${p.nroPoliza ?? 'Sin número'}';

                        final cliente = _primerNoVacio(
                          [
                            p.nombreCliente,
                            p.docCliente,
                          ],
                          fallback: 'Sin cliente',
                        );

                        final detalle2 = _primerNoVacio(
                          [
                            p.nombreAseg,
                            p.nombreRamo,
                            p.nombreProd,
                            p.nombreAsesor,
                          ],
                          fallback: 'Sin referencias',
                        );

                        return ListTile(
                          title: Text(titulo),
                          subtitle: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(cliente),
                              Text(detalle2),
                              Text(
                                'Vence: ${_fmtFecha(p.ffinPoliza)} • Prima: ${_fmtNum(p.primaPoliza)} • Valor: ${_fmtNum(p.valorPoliza)}',
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            tooltip: 'Editar',
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PaginaFormularioPolizas(
                                    poliza: p,
                                  ),
                                ),
                              );
                              _cargar();
                            },
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