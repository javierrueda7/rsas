import 'package:flutter/material.dart';

import '../datos/poliza_pendiente.dart';
import '../datos/repositorio_polizas_pendientes.dart';
import 'pagina_formulario_polizas.dart';
import 'theme/app_layout.dart';
import 'theme/app_theme.dart';

/// Bandeja de trabajo: pólizas en "Borrador" (guardadas a medio llenar) o
/// "Pendiente de revisión" (predigitadas por IA, todavía sin revisar).
/// Ninguna tiene id real todavía — ver lib/fix_polizas_pendientes.sql.
class PaginaPolizasPendientes extends StatefulWidget {
  const PaginaPolizasPendientes({super.key});

  @override
  State<PaginaPolizasPendientes> createState() =>
      _PaginaPolizasPendientesState();
}

class _PaginaPolizasPendientesState extends State<PaginaPolizasPendientes> {
  final _repo = RepositorioPolizasPendientes();
  bool _cargando = true;
  String? _error;
  List<PolizaPendiente> _items = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final items = await _repo.listar();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _abrir(PolizaPendiente p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaginaFormularioPolizas(polizaPendiente: p),
      ),
    );
    _cargar();
  }

  Future<void> _eliminar(PolizaPendiente p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar'),
        content: Text(
          '¿Descartar "${p.resumen}"? Esto no se puede deshacer.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Descartar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.eliminar(p.id);
      _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borradores = _items.where((p) => p.estado == 'borrador').toList();
    final pendientes =
        _items.where((p) => p.estado == 'pendiente_revision').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pólizas pendientes'),
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
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 52, color: AppTheme.green),
                          const SizedBox(height: 12),
                          const Text('No hay pólizas pendientes.'),
                        ],
                      ),
                    )
                  : AppLayout.centered(ListView(
                      padding: AppLayout.pagePadding,
                      children: [
                        if (pendientes.isNotEmpty) ...[
                          Text('Pendientes de revisión (${pendientes.length})',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant)),
                          const SizedBox(height: 8),
                          for (final p in pendientes) ...[
                            _fila(p),
                            const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 16),
                        ],
                        if (borradores.isNotEmpty) ...[
                          Text('Borradores (${borradores.length})',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant)),
                          const SizedBox(height: 8),
                          for (final p in borradores) ...[
                            _fila(p),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ],
                    )),
    );
  }

  Widget _fila(PolizaPendiente p) {
    final cs = Theme.of(context).colorScheme;
    final esPendiente = p.estado == 'pendiente_revision';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              esPendiente ? AppTheme.warningContainer : cs.surfaceContainerHighest,
          child: Icon(
            esPendiente ? Icons.auto_awesome_outlined : Icons.description_outlined,
            color: esPendiente ? AppTheme.onWarningContainer : cs.onSurfaceVariant,
            size: 20,
          ),
        ),
        title: Text(p.resumen),
        subtitle: Text([
          if ((p.nombreArchivo ?? '').isNotEmpty) p.nombreArchivo!,
          if (p.errorMsg != null) 'Error: ${p.errorMsg}',
        ].join(' · ').isEmpty
            ? 'Guardado el ${_fecha(p.fcreado)}'
            : '${[
                if ((p.nombreArchivo ?? '').isNotEmpty) p.nombreArchivo!,
                if (p.errorMsg != null) 'Error: ${p.errorMsg}',
              ].join(' · ')} · ${_fecha(p.fcreado)}'),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: cs.error),
          tooltip: 'Descartar',
          onPressed: () => _eliminar(p),
        ),
        onTap: () => _abrir(p),
      ),
    );
  }

  String _fecha(DateTime d) {
    final l = d.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(l.day)}/${dos(l.month)}/${l.year} ${dos(l.hour)}:${dos(l.minute)}';
  }
}
