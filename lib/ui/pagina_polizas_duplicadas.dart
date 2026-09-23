import 'package:flutter/material.dart';

import '../datos/poliza.dart';
import '../datos/repositorio_polizas.dart';
import '../utils/formatters.dart';
import 'pagina_formulario_polizas.dart';
import 'theme/app_layout.dart';
import 'theme/app_theme.dart';

/// Agrupa las pólizas cuyo número, ignorando espacios/guiones/separadores,
/// coincide — para que el usuario decida qué hacer con cada grupo (dejarlas
/// si en realidad son distintas, corregir una, eliminar la que sobra, etc.).
/// No borra ni modifica nada solo, es una vista de diagnóstico.
class PaginaPolizasDuplicadas extends StatefulWidget {
  const PaginaPolizasDuplicadas({super.key});

  @override
  State<PaginaPolizasDuplicadas> createState() =>
      _PaginaPolizasDuplicadasState();
}

class _PaginaPolizasDuplicadasState extends State<PaginaPolizasDuplicadas> {
  final _repo = RepositorioPolizas();
  bool _cargando = true;
  String? _error;
  List<List<Poliza>> _grupos = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      // vw_polizas_duplicadas ya filtra en la base — solo trae las pólizas
      // cuyo número está repetido, no el catálogo completo (mucho más
      // rápido que el listarTodos() que se usaba antes acá).
      final todas = await _repo.listarDuplicados();
      final porNumero = <String, List<Poliza>>{};
      for (final p in todas) {
        final nro = (p.nroPoliza ?? '').trim();
        if (nro.isEmpty) continue;
        final norm = RepositorioPolizas.normalizarNroPoliza(nro);
        if (norm.isEmpty) continue;
        porNumero.putIfAbsent(norm, () => []).add(p);
      }
      final grupos = porNumero.values.where((g) => g.length > 1).toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      if (!mounted) return;
      setState(() => _grupos = grupos);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _editar(Poliza p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaginaFormularioPolizas(poliza: p)),
    );
    // vw_polizas_duplicadas es una consulta chica (solo las pólizas
    // repetidas), así que recargar acá siempre — haya cambiado algo o no —
    // ya es rápido, sin necesitar un caché propio.
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalPolizas = _grupos.fold<int>(0, (s, g) => s + g.length);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pólizas con número repetido'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _cargando ? null : _cargar,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text('Error: $_error',
                      style: TextStyle(color: AppTheme.danger)))
              : _grupos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 52, color: AppTheme.green),
                          const SizedBox(height: 12),
                          const Text('No hay números de póliza repetidos.'),
                        ],
                      ),
                    )
                  : AppLayout.centered(ListView(
                      padding: AppLayout.pagePadding,
                      children: [
                        Text(
                          '${_grupos.length} número(s) repetido(s) — $totalPolizas póliza(s) en total. '
                          'Se ignoran espacios y guiones al comparar (mismo criterio que la app usa '
                          'para detectar duplicados al guardar). Esto no borra ni modifica nada solo.',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        for (final grupo in _grupos) ...[
                          _grupoCard(grupo),
                          const SizedBox(height: 10),
                        ],
                      ],
                    )),
    );
  }

  Widget _grupoCard(List<Poliza> grupo) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ExpansionTile(
          title: Text(
            grupo.first.nroPoliza ?? '—',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('${grupo.length} pólizas con este número'),
          leading: CircleAvatar(
            backgroundColor: AppTheme.warningContainer,
            child: Text('${grupo.length}',
                style: TextStyle(
                    color: AppTheme.onWarningContainer,
                    fontWeight: FontWeight.bold)),
          ),
          children: grupo.map((p) {
            return ListTile(
              dense: true,
              title: Text('#${p.id} — ${p.nombreCliente ?? '—'}'),
              subtitle: Text(
                '${p.nombreAseg ?? '—'} · ${p.nombreRamo ?? '—'} · '
                'Prima: \$ ${Fmt.money(p.primaPoliza)}'
                '${p.nroPoliza != null ? ' · Nro. exacto: "${p.nroPoliza}"' : ''}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => _editar(p),
            );
          }).toList(),
        ),
      ),
    );
  }
}
