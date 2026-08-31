// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../datos/abono_poliza.dart';
import '../datos/repositorio_pagos.dart';
import '../utils/formatters.dart';
import 'pagina_formulario_reporte.dart';
import 'pagina_estado_cuenta.dart';
import 'theme/app_layout.dart';
import 'theme/app_theme.dart';

class PaginaReportesPago extends StatefulWidget {
  const PaginaReportesPago({super.key});

  @override
  State<PaginaReportesPago> createState() => _PaginaReportesPagoState();
}

class _PaginaReportesPagoState extends State<PaginaReportesPago> {
  final _repo      = RepositorioPagos();
  final _ctrlBuscar = TextEditingController();
  final _df        = DateFormat('dd/MM/yyyy');
  final _hScroll   = ScrollController();
  final _vScroll   = ScrollController();
  Timer? _debounce;

  bool _cargando = false;
  List<ReportePago> _reportes = [];
  String _filtroEstado = 'TODOS';

  static const _estados = ['TODOS', 'I', 'C', 'R', 'V', 'A'];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _ctrlBuscar.dispose();
    _debounce?.cancel();
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (_cargando) return;
    setState(() => _cargando = true);
    try {
      final data = await _repo.listarReportes(busqueda: _ctrlBuscar.text.trim());
      if (mounted) setState(() => _reportes = data);
    } catch (e) {
      if (mounted) _snack('Error al cargar: $e', error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _onBuscar(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _cargar);
  }

  List<ReportePago> get _filtrados {
    if (_filtroEstado == 'TODOS') return _reportes;
    return _reportes.where((r) => r.estadoRep == _filtroEstado).toList();
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.danger : null,
    ));
  }

  Future<void> _abrirFormulario({ReportePago? reporte}) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => FormularioReportePago(reporte: reporte)),
    );
    if (ok == true) _cargar();
  }

  Future<void> _confirmarEliminar(ReportePago r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar reporte'),
        content: Text(
          'Se eliminará el Reporte #${r.id} (${_df.format(r.fechaRep)}) '
          'y sus ${r.numAbonos} abono(s). Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.eliminarReporte(r.id);
      _snack('Reporte #${r.id} eliminado');
      _cargar();
    } catch (e) {
      _snack('Error: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final lista  = _filtrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de Comisiones'),
        actions: [
          if (_cargando)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _cargar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nuevo reporte'),
        onPressed: () => _abrirFormulario(),
      ),
      body: AppLayout.centered(Column(
        children: [
          // ── Buscador ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: TextField(
              controller: _ctrlBuscar,
              onChanged: _onBuscar,
              decoration: InputDecoration(
                hintText: 'Buscar por aseguradora o intermediario...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _ctrlBuscar.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () { _ctrlBuscar.clear(); _cargar(); },
                      )
                    : null,
              ),
            ),
          ),
          // ── Filtros de estado ────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: _estados.map((e) {
                final selected = _filtroEstado == e;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(e == 'TODOS' ? 'Todos' : labelEstadoPago(e)),
                    selected: selected,
                    onSelected: (_) => setState(() => _filtroEstado = e),
                  ),
                );
              }).toList(),
            ),
          ),
          // ── Contador ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${lista.length} reporte(s)',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
          ),
          // ── Tabla ───────────────────────────────────────────────────────
          Expanded(
            child: lista.isEmpty && !_cargando
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 52, color: cs.outlineVariant),
                        const SizedBox(height: 12),
                        Text('Sin reportes', style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  )
                : Scrollbar(
                    controller: _vScroll,
                    child: Scrollbar(
                      controller: _hScroll,
                      notificationPredicate: (n) => n.depth == 1,
                      child: SingleChildScrollView(
                        controller: _vScroll,
                        child: SingleChildScrollView(
                          controller: _hScroll,
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              cs.surfaceContainerHighest,
                            ),
                            dataRowMinHeight: 44,
                            dataRowMaxHeight: 56,
                            columnSpacing: 14,
                            columns: const [
                              DataColumn(label: Text('#')),
                              DataColumn(label: Text('Fecha')),
                              DataColumn(label: Text('Aseguradora')),
                              DataColumn(label: Text('Intermediario')),
                              DataColumn(label: Text('Período')),
                              DataColumn(label: Text('Pólizas'), numeric: true),
                              DataColumn(label: Text('Suma Prima'), numeric: true),
                              DataColumn(label: Text('Suma Comisión'), numeric: true),
                              DataColumn(label: Text('Estado')),
                              DataColumn(label: Text('Acciones')),
                            ],
                            rows: lista.map((r) {
                              final periodo =
                                  (r.finiRep != null && r.ffinRep != null)
                                      ? '${_df.format(r.finiRep!)} – ${_df.format(r.ffinRep!)}'
                                      : '—';
                              return DataRow(
                                cells: [
                                  DataCell(Text(
                                    '#${r.id}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  )),
                                  DataCell(Text(_df.format(r.fechaRep))),
                                  DataCell(Text(r.nombreAseg ?? '—')),
                                  DataCell(Text(r.nombreInterm ?? '—')),
                                  DataCell(Text(periodo,
                                      style: const TextStyle(fontSize: 11))),
                                  DataCell(
                                    Center(child: _BadgeNum(r.numAbonos)),
                                  ),
                                  DataCell(Text(
                                    '\$ ${Fmt.money(r.vlrsumprimaRep)}',
                                    style: TextStyle(
                                        fontFamily: AppTheme.monoFamily, fontSize: 12),
                                  )),
                                  DataCell(Text(
                                    '\$ ${Fmt.money(r.vlrsumcomRep)}',
                                    style: TextStyle(
                                        fontFamily: AppTheme.monoFamily, fontSize: 12),
                                  )),
                                  DataCell(_ChipEstado(r.estadoRep)),
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                            Icons.edit_outlined, size: 18),
                                        tooltip: 'Editar reporte',
                                        onPressed: () =>
                                            _abrirFormulario(reporte: r),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.account_balance_wallet_outlined,
                                            size: 18),
                                        tooltip: 'Estado de cuenta',
                                        color: cs.primary,
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                PaginaEstadoCuenta.reporte(
                                                    idReporte: r.id),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.delete_outline, size: 18),
                                        tooltip: 'Eliminar',
                                        color: AppTheme.danger,
                                        onPressed: () =>
                                            _confirmarEliminar(r),
                                      ),
                                    ],
                                  )),
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
      )),
    );
  }
}

// ── Widgets locales ───────────────────────────────────────────────────────────

class _BadgeNum extends StatelessWidget {
  final int n;
  const _BadgeNum(this.n);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$n',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _ChipEstado extends StatelessWidget {
  final String estado;
  const _ChipEstado(this.estado);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (estado) {
      'C' => (cs.secondaryContainer, cs.onSecondaryContainer),
      'R' => (cs.primaryContainer, cs.onPrimaryContainer),
      'I' => (AppTheme.warningContainer, AppTheme.onWarningContainer),
      'V' => (cs.errorContainer, cs.onErrorContainer),
      _   => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        labelEstadoPago(estado),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
