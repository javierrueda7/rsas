// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../datos/abono_poliza.dart';
import '../datos/catalogos.dart';
import '../datos/poliza.dart';
import '../datos/repositorio_catalogos.dart';
import '../datos/repositorio_ia.dart';
import '../datos/repositorio_pagos.dart';
import '../datos/repositorio_polizas.dart';
import '../datos/sesion.dart';
import '../utils/formatters.dart';
import 'theme/app_layout.dart';
import 'theme/app_theme.dart';
import 'widgets/stat_card.dart';
import 'pagina_estado_cuenta.dart';
import 'pagina_revision_reporte_pago.dart';
import 'widgets/buscador_dropdown.dart';

// ── Formateo moneda colombiana mientras escribe ───────────────────────────────
class _ColMoneyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue nv) {
    final raw = nv.text.replaceAll(RegExp(r'[^0-9,]'), '');
    if (raw.isEmpty) return nv.copyWith(text: '');
    final parts = raw.split(',');
    final entNum = int.tryParse(parts[0]) ?? 0;
    String fmt = _miles(entNum);
    if (parts.length > 1) {
      final dec = parts[1].length > 2 ? parts[1].substring(0, 2) : parts[1];
      fmt += ',$dec';
    }
    return nv.copyWith(
        text: fmt, selection: TextSelection.collapsed(offset: fmt.length));
  }

  static String _miles(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

num _parseCO(String s) =>
    num.tryParse(s.replaceAll('.', '').replaceAll(',', '.')) ?? 0;

extension _FirstOrNull<E> on Iterable<E> {
  E? firstOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FormularioReportePago
// ─────────────────────────────────────────────────────────────────────────────

/// La importación de reportes de comisiones con IA sigue en pruebas —
/// oculta hasta validarla más.
const bool _mostrarImportarReporte = false;

class FormularioReportePago extends StatefulWidget {
  final ReportePago? reporte;
  const FormularioReportePago({super.key, this.reporte});

  @override
  State<FormularioReportePago> createState() => _FormularioReporteState();
}

class _FormularioReporteState extends State<FormularioReportePago> {
  final _formKey        = GlobalKey<FormState>();
  final _repoPagos      = RepositorioPagos();
  final _repoCatalogos  = RepositorioCatalogos();
  final _repoIA         = RepositorioIA();
  final _df             = DateFormat('dd/MM/yyyy');

  bool _guardando       = false;
  bool _cargandoCatalogos = false;
  bool _cargandoAbonos  = false;
  bool _importando      = false;
  List<Map<String, dynamic>> _lineasPendientes = [];

  List<AbonoPoliza>  _abonos        = [];
  List<Aseguradora>  _aseguradoras  = [];
  List<Intermediario> _intermediarios = [];

  // Campos del formulario
  late DateTime   _fechaRep;
  DateTime?       _finiRep;
  DateTime?       _ffinRep;
  String          _estadoRep = 'I';
  Aseguradora?    _aseguradora;
  Intermediario?  _intermediario;

  final _ctrlPrimaManual = TextEditingController();
  final _ctrlComManual   = TextEditingController();
  final _ctrlObs         = TextEditingController();

  bool get _esNuevo   => widget.reporte == null;
  int? get _idReporte => widget.reporte?.id;

  // Totales calculados de los abonos cargados
  num get _sumaPrima => _abonos.fold(0, (s, a) => s + a.vlrabonoprima);
  num get _sumaCom   => _abonos.fold(0, (s, a) => s + a.vlrcomision + a.vlrcomad);

  @override
  void initState() {
    super.initState();
    final r = widget.reporte;
    _fechaRep    = r?.fechaRep ?? DateTime.now();
    _finiRep     = r?.finiRep;
    _ffinRep     = r?.ffinRep;
    _estadoRep   = r?.estadoRep ?? 'I';
    _ctrlPrimaManual.text = r != null ? Fmt.money(r.vlrprimaRep) : '';
    _ctrlComManual.text   = r != null ? Fmt.money(r.vlrcomRep) : '';
    _ctrlObs.text         = r?.obsRep ?? '';
    _cargarCatalogos();
    if (!_esNuevo) _cargarAbonos();
  }

  @override
  void dispose() {
    _ctrlPrimaManual.dispose();
    _ctrlComManual.dispose();
    _ctrlObs.dispose();
    super.dispose();
  }

  // ── Carga de catálogos ────────────────────────────────────────────────────
  Future<void> _cargarCatalogos() async {
    setState(() => _cargandoCatalogos = true);
    try {
      final res = await Future.wait([
        _repoCatalogos.listarAseguradoras(),
        _repoCatalogos.listarIntermediarios(),
      ]);
      if (!mounted) return;
      setState(() {
        _aseguradoras   = res[0] as List<Aseguradora>;
        _intermediarios = res[1] as List<Intermediario>;
        final r = widget.reporte;
        if (r?.asegId != null) {
          _aseguradora = _aseguradoras.firstOrNull((a) => a.id == r!.asegId);
        }
        if (r?.intermId != null) {
          _intermediario = _intermediarios.firstOrNull((i) => i.id == r!.intermId);
        }
      });
    } catch (_) {}
    if (mounted) setState(() => _cargandoCatalogos = false);
  }

  // ── Carga de abonos ───────────────────────────────────────────────────────
  Future<void> _cargarAbonos() async {
    if (_idReporte == null) return;
    setState(() => _cargandoAbonos = true);
    try {
      final data = await _repoPagos.listarAbonosPorReporte(_idReporte!);
      if (mounted) setState(() => _abonos = data);
    } catch (_) {}
    if (mounted) setState(() => _cargandoAbonos = false);
  }

  // ── Guardar reporte ───────────────────────────────────────────────────────
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final data = {
        'fecha_rep':        _fechaRep.toIso8601String().substring(0, 10),
        'aseg_id':          _aseguradora?.id,
        'interm_id':        _intermediario?.id,
        'fini_rep':         _finiRep?.toIso8601String().substring(0, 10),
        'ffin_rep':         _ffinRep?.toIso8601String().substring(0, 10),
        'vlrprima_rep':     _parseCO(_ctrlPrimaManual.text),
        'vlrcom_rep':       _parseCO(_ctrlComManual.text),
        'vlrsumprima_rep':  _sumaPrima,
        'vlrsumcom_rep':    _sumaCom,
        'estado_rep':       _estadoRep,
        'obs_rep':          _ctrlObs.text.trim().isEmpty ? null : _ctrlObs.text.trim(),
        'usuario_id':       Sesion.usuarioId,
      };
      if (_esNuevo) {
        final id = await _repoPagos.crearReporte(data);
        if (!mounted) return;

        // Si se había importado un documento antes de guardar, las líneas
        // quedaron pendientes esperando un id real — ahora que existe, se
        // revisan/confirman antes de volver.
        if (_lineasPendientes.isNotEmpty) {
          final lineas = _lineasPendientes;
          setState(() => _lineasPendientes = []);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaginaRevisionReportePago(
                idReporte: id,
                lineas: lineas,
              ),
            ),
          );
          if (!mounted) return;
        }

        // Reemplaza la pantalla con la del reporte recién creado
        final nuevo = await _repoPagos.obtenerReporte(id);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => FormularioReportePago(reporte: nuevo)),
        );
      } else {
        await _repoPagos.actualizarReporte(_idReporte!, data);
        if (mounted) {
          _snack('Reporte actualizado');
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── Acciones de abono ─────────────────────────────────────────────────────
  Future<void> _abrirDialogoAbono({AbonoPoliza? abono}) async {
    if (_idReporte == null) {
      _snack('Guarda primero el reporte y luego añade pólizas', error: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogAbono(
        idReporte: _idReporte!,
        abono: abono,
        repo: _repoPagos,
      ),
    );
    if (ok == true) {
      await _cargarAbonos();
      await _repoPagos.recalcularTotales(_idReporte!);
    }
  }

  Future<void> _importarDesdeArchivo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    final ext = (file.extension ?? '').toLowerCase();
    final mimeType = switch (ext) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
    if (bytes == null || mimeType == null) {
      _snack('No se pudo leer el archivo. Usá PDF, JPG, PNG o WEBP.', error: true);
      return;
    }

    setState(() => _importando = true);
    try {
      final extraido = await _repoIA.extraerReportePago(bytes, mimeType);
      if (!mounted) return;

      // Cabecera: solo se aplica lo que efectivamente se reconoció.
      final nombreAseg = extraido.cabecera['nombre_aseguradora'] as String?;
      final matchAseg = _matchPorNombre(
          _aseguradoras, (a) => a.nombreAseg, nombreAseg);
      final dRep = _parseFechaISO(extraido.cabecera['fecha_reporte']);
      final dIni = _parseFechaISO(extraido.cabecera['fecha_inicio_periodo']);
      final dFin = _parseFechaISO(extraido.cabecera['fecha_fin_periodo']);
      setState(() {
        if (matchAseg != null) _aseguradora = matchAseg;
        if (dRep != null) _fechaRep = dRep;
        if (dIni != null) _finiRep = dIni;
        if (dFin != null) _ffinRep = dFin;
      });

      if (extraido.lineas.isEmpty) {
        _snack('Se completó la cabecera. No se encontraron líneas de pólizas en el documento.');
        return;
      }

      if (_idReporte != null) {
        // El reporte ya existe: se revisan las líneas de una.
        final creoAlgo = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PaginaRevisionReportePago(
              idReporte: _idReporte!,
              lineas: extraido.lineas,
            ),
          ),
        );
        if (creoAlgo == true) {
          await _cargarAbonos();
          await _repoPagos.recalcularTotales(_idReporte!);
        }
      } else {
        // Reporte nuevo, todavía sin id: las líneas quedan pendientes hasta
        // que se guarde — recién ahí se pueden crear los abonos.
        setState(() => _lineasPendientes = extraido.lineas);
        _snack(
            'Se completó la cabecera y se detectaron ${extraido.lineas.length} línea(s). '
            'Guardá el reporte para revisarlas y crear los abonos.');
      }
    } catch (e) {
      _snack('Error al importar: $e', error: true);
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  DateTime? _parseFechaISO(dynamic v) {
    if (v is! String || v.trim().isEmpty) return null;
    try {
      final d = DateTime.parse(v.trim());
      return DateTime(d.year, d.month, d.day);
    } catch (_) {
      return null;
    }
  }

  T? _matchPorNombre<T>(
      List<T> lista, String Function(T) nombre, String? candidato) {
    if (candidato == null || candidato.trim().isEmpty) return null;
    final norm = _normalizarTexto(candidato);
    for (final item in lista) {
      if (_normalizarTexto(nombre(item)) == norm) return item;
    }
    for (final item in lista) {
      final n = _normalizarTexto(nombre(item));
      if (n.isNotEmpty && (n.contains(norm) || norm.contains(n))) return item;
    }
    return null;
  }

  String _normalizarTexto(String s) {
    var r = s.trim().toUpperCase();
    const acentos = {
      'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ñ': 'N',
    };
    acentos.forEach((k, v) => r = r.replaceAll(k, v));
    return r;
  }

  Future<void> _confirmarEliminarAbono(AbonoPoliza a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar abono'),
        content: Text(
            '¿Eliminar el abono de ${a.nombreCliente ?? 'Póliza ${a.idPoliza}'}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
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
      await _repoPagos.eliminarAbono(a.id);
      await _cargarAbonos();
      await _repoPagos.recalcularTotales(_idReporte!);
    } catch (e) {
      _snack('Error: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.danger : null,
    ));
  }

  Future<DateTime?> _pickDate(DateTime? initial) => showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        locale: const Locale('es', 'CO'),
      );

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_esNuevo ? 'Nuevo Reporte' : 'Reporte #$_idReporte'),
        actions: [
          // Oculto por ahora: la importación de reportes de comisiones
          // sigue en pruebas. Para reactivarla, poner en true.
          if (_mostrarImportarReporte && _importando)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_mostrarImportarReporte)
            TextButton.icon(
              onPressed: _importarDesdeArchivo,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Importar desde PDF/imagen'),
            ),
          if (!_esNuevo)
            IconButton(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              tooltip: 'Estado de cuenta del reporte',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PaginaEstadoCuenta.reporte(idReporte: _idReporte!),
                ),
              ),
            ),
          if (_guardando)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
              onPressed: _guardar,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: AppLayout.centered(CustomScrollView(
          slivers: [
            SliverPadding(
              padding: AppLayout.pagePadding,
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── 1. Cabecera del reporte ──────────────────────────────
                  _SeccionHeader(
                      icon: Icons.description_outlined,
                      title: 'Datos del Reporte'),
                  const SizedBox(height: 12),

                  // Fecha + Estado
                  Row(children: [
                    Expanded(
                      child: _DateField(
                        label: 'Fecha del reporte *',
                        value: _fechaRep,
                        df: _df,
                        onTap: () async {
                          final d = await _pickDate(_fechaRep);
                          if (d != null) setState(() => _fechaRep = d);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _estadoRep,
                        decoration: const InputDecoration(
                          labelText: 'Estado',
                          border: OutlineInputBorder(),
                        ),
                        items: kEstadoPagoLabels.entries
                            .map((e) => DropdownMenuItem(
                                value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _estadoRep = v ?? 'I'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // Aseguradora + Intermediario
                  if (_cargandoCatalogos)
                    const LinearProgressIndicator()
                  else ...[
                    BuscadorDropdown<Aseguradora>(
                      label: 'Aseguradora *',
                      value: _aseguradora,
                      items: _aseguradoras,
                      itemLabel: (a) => a.nombreAseg,
                      onChanged: (a) => setState(() => _aseguradora = a),
                      validator: (v) => v == null ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    BuscadorDropdown<Intermediario>(
                      label: 'Intermediario',
                      value: _intermediario,
                      items: _intermediarios,
                      itemLabel: (i) => i.nombreInterm,
                      onChanged: (i) => setState(() => _intermediario = i),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Período inicio – fin
                  Row(children: [
                    Expanded(
                      child: _DateField(
                        label: 'Inicio período',
                        value: _finiRep,
                        df: _df,
                        onTap: () async {
                          final d = await _pickDate(_finiRep);
                          if (d != null) setState(() => _finiRep = d);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateField(
                        label: 'Fin período',
                        value: _ffinRep,
                        df: _df,
                        onTap: () async {
                          final d = await _pickDate(_ffinRep);
                          if (d != null) setState(() => _ffinRep = d);
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // Valores manuales
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ctrlPrimaManual,
                        inputFormatters: [_ColMoneyFormatter()],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Vlr Prima (manual)',
                          border: OutlineInputBorder(),
                          prefixText: '\$ ',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _ctrlComManual,
                        inputFormatters: [_ColMoneyFormatter()],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Vlr Comisión (manual)',
                          border: OutlineInputBorder(),
                          prefixText: '\$ ',
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ctrlObs,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── 2. Resumen calculado (solo si no es nuevo) ───────────
                  if (!_esNuevo) ...[
                    _SeccionHeader(
                        icon: Icons.calculate_outlined,
                        title: 'Resumen Calculado'),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: StatCard(
                          width: null,
                          label: 'Prima total (calculada)',
                          value: '\$ ${Fmt.money(_sumaPrima)}',
                          icon: Icons.attach_money,
                          color: AppTheme.navy,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          width: null,
                          label: 'Comisión total (calculada)',
                          value: '\$ ${Fmt.money(_sumaCom)}',
                          icon: Icons.percent,
                          color: AppTheme.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          width: null,
                          label: 'Pólizas en reporte',
                          value: '${_abonos.length}',
                          icon: Icons.receipt_long,
                          color: AppTheme.warning,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // ── 3. Tabla de abonos ───────────────────────────────
                    Row(children: [
                      Expanded(
                        child: _SeccionHeader(
                            icon: Icons.list_alt_outlined,
                            title: 'Pólizas en este Reporte'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Añadir póliza'),
                        onPressed: () => _abrirDialogoAbono(),
                      ),
                    ]),
                    const SizedBox(height: 10),

                    if (_cargandoAbonos)
                      const Center(
                          child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator()))
                    else if (_abonos.isEmpty)
                      Card(
                        color: cs.surfaceContainerLow,
                        child: const Padding(
                          padding: EdgeInsets.all(28),
                          child: Center(
                            child: Text(
                              'Sin pólizas en este reporte.\nPresiona "Añadir póliza" para comenzar.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      )
                    else
                      _TablaAbonos(
                        abonos: _abonos,
                        onEdit: (a) => _abrirDialogoAbono(abono: a),
                        onDelete: _confirmarEliminarAbono,
                        onEstadoCuenta: (a) => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaginaEstadoCuenta.poliza(
                                idPoliza: a.idPoliza),
                          ),
                        ),
                      ),
                  ],
                ]),
              ),
            ),
          ],
        )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tabla embebida de abonos
// ─────────────────────────────────────────────────────────────────────────────

class _TablaAbonos extends StatelessWidget {
  final List<AbonoPoliza> abonos;
  final void Function(AbonoPoliza) onEdit;
  final void Function(AbonoPoliza) onDelete;
  final void Function(AbonoPoliza) onEstadoCuenta;

  const _TablaAbonos({
    required this.abonos,
    required this.onEdit,
    required this.onDelete,
    required this.onEstadoCuenta,
  });

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final hScroll = ScrollController();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: hScroll,
        child: SingleChildScrollView(
          controller: hScroll,
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(cs.surfaceContainerHighest),
            dataRowMinHeight: 52,
            dataRowMaxHeight: 68,
            columnSpacing: 12,
            columns: const [
              DataColumn(label: Text('N° Póliza')),
              DataColumn(label: Text('Cliente')),
              DataColumn(label: Text('Ramo / Producto')),
              DataColumn(label: Text('Bien asegurado')),
              DataColumn(label: Text('Vlr Prima'), numeric: true),
              DataColumn(label: Text('Abono'), numeric: true),
              DataColumn(label: Text('% Com'), numeric: true),
              DataColumn(label: Text('Vlr Com'), numeric: true),
              DataColumn(label: Text('Estado')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: abonos.map((a) {
              return DataRow(cells: [
                DataCell(Text(
                  a.nroPoliza ?? '${a.idPoliza}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                )),
                DataCell(Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.nombreCliente ?? '—',
                        style: const TextStyle(fontSize: 12)),
                    if (a.docCliente != null)
                      Text(
                        '${a.tipodocCliente ?? ''} ${a.docCliente}',
                        style:
                            TextStyle(fontSize: 10, color: AppTheme.inkSoft),
                      ),
                  ],
                )),
                DataCell(Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.nombreRamo ?? '—',
                        style: const TextStyle(fontSize: 12)),
                    if (a.nombreProd != null)
                      Text(a.nombreProd!,
                          style: TextStyle(
                              fontSize: 10, color: AppTheme.inkSoft)),
                  ],
                )),
                DataCell(SizedBox(
                  width: 140,
                  child: Text(
                    a.bienAsegurado ?? '—',
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
                DataCell(Text('\$ ${Fmt.money(a.vlrprimaPoliza)}',
                    style: TextStyle(
                        fontFamily: AppTheme.monoFamily, fontSize: 12))),
                DataCell(Text('\$ ${Fmt.money(a.vlrabonoprima)}',
                    style: TextStyle(
                        fontFamily: AppTheme.monoFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.bold))),
                DataCell(Text(Fmt.percent(a.porccomision, dec: 1))),
                DataCell(Text('\$ ${Fmt.money(a.vlrcomision)}',
                    style: TextStyle(
                        fontFamily: AppTheme.monoFamily, fontSize: 12))),
                DataCell(_ChipEstadoAbono(a.estadoPago)),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      tooltip: 'Editar',
                      onPressed: () => onEdit(a),
                    ),
                    IconButton(
                      icon: const Icon(Icons.account_balance_wallet_outlined,
                          size: 17),
                      tooltip: 'Estado de cuenta',
                      color: AppTheme.navy,
                      onPressed: () => onEstadoCuenta(a),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 17),
                      tooltip: 'Eliminar',
                      color: AppTheme.danger,
                      onPressed: () => onDelete(a),
                    ),
                  ],
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo añadir / editar abono
// ─────────────────────────────────────────────────────────────────────────────

class _DialogAbono extends StatefulWidget {
  final int idReporte;
  final AbonoPoliza? abono;
  final RepositorioPagos repo;

  const _DialogAbono({
    required this.idReporte,
    this.abono,
    required this.repo,
  });

  @override
  State<_DialogAbono> createState() => _DialogAbonoState();
}

class _DialogAbonoState extends State<_DialogAbono> {
  final _formKey     = GlobalKey<FormState>();
  final _repoPolizas = RepositorioPolizas();
  final _df          = DateFormat('dd/MM/yyyy');

  bool _guardando       = false;
  bool _cargandoPoliza  = false;

  Poliza?   _poliza;
  DateTime? _fechaPago;
  String    _estadoPago = 'R';

  final _ctrlPrima    = TextEditingController();
  final _ctrlAbono    = TextEditingController();
  final _ctrlPorcCom  = TextEditingController();
  final _ctrlVlrCom   = TextEditingController();
  final _ctrlPorcAd   = TextEditingController();
  final _ctrlVlrAd    = TextEditingController();
  final _ctrlFactura  = TextEditingController();
  final _ctrlObs      = TextEditingController();

  bool get _esNuevo => widget.abono == null;

  @override
  void initState() {
    super.initState();
    _fechaPago = DateTime.now();
    final a = widget.abono;
    if (a != null) {
      _fechaPago  = a.fechaPago ?? DateTime.now();
      _estadoPago = a.estadoPago;
      _ctrlPrima.text   = Fmt.money(a.vlrprimaPoliza);
      _ctrlAbono.text   = Fmt.money(a.vlrabonoprima);
      _ctrlPorcCom.text = Fmt.numCO(a.porccomision, dec: 2);
      _ctrlVlrCom.text  = Fmt.money(a.vlrcomision);
      _ctrlPorcAd.text  = Fmt.numCO(a.porccomad, dec: 2);
      _ctrlVlrAd.text   = Fmt.money(a.vlrcomad);
      _ctrlFactura.text = a.numFactura ?? '';
      _ctrlObs.text     = a.obsPago ?? '';
      _cargarPolizaInicial(a.idPoliza);
    }
  }

  @override
  void dispose() {
    _ctrlPrima.dispose();
    _ctrlAbono.dispose();
    _ctrlPorcCom.dispose();
    _ctrlVlrCom.dispose();
    _ctrlPorcAd.dispose();
    _ctrlVlrAd.dispose();
    _ctrlFactura.dispose();
    _ctrlObs.dispose();
    super.dispose();
  }

  Future<void> _cargarPolizaInicial(int id) async {
    setState(() => _cargandoPoliza = true);
    try {
      final p = await _repoPolizas.obtenerPoliza(id);
      if (mounted && p != null) setState(() => _poliza = p);
    } catch (_) {}
    if (mounted) setState(() => _cargandoPoliza = false);
  }

  void _onPolizaSeleccionada(Poliza p) {
    setState(() {
      _poliza = p;
      _ctrlPrima.text   = Fmt.money(p.primaPoliza);
      _ctrlAbono.text   = Fmt.money(p.primaPoliza);
      _ctrlPorcCom.text = Fmt.numCO(p.porccomPoliza ?? 0, dec: 2);
      _recalcular();
    });
  }

  void _recalcular() {
    final abono   = _parseCO(_ctrlAbono.text);
    final pCom    = _parseCO(_ctrlPorcCom.text);
    final pComAd  = _parseCO(_ctrlPorcAd.text);
    _ctrlVlrCom.text = Fmt.money(abono * pCom / 100);
    _ctrlVlrAd.text  = Fmt.money(abono * pComAd / 100);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_poliza == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecciona una póliza'),
        backgroundColor: AppTheme.danger,
      ));
      return;
    }
    setState(() => _guardando = true);
    try {
      final data = {
        'idrep_pago':      widget.idReporte,
        'id_poliza':       _poliza!.id,
        'fecha_pago':      _fechaPago?.toIso8601String().substring(0, 10),
        'vlrprima_poliza': _parseCO(_ctrlPrima.text),
        'vlrabono_prima':  _parseCO(_ctrlAbono.text),
        'porccomision':    _parseCO(_ctrlPorcCom.text),
        'vlrcomision':     _parseCO(_ctrlVlrCom.text),
        'porccomad':       _parseCO(_ctrlPorcAd.text),
        'vlrcomad':        _parseCO(_ctrlVlrAd.text),
        'num_factura':     _ctrlFactura.text.trim().isEmpty
            ? null
            : _ctrlFactura.text.trim(),
        'estado_pago': _estadoPago,
        'obs_pago':    _ctrlObs.text.trim().isEmpty ? null : _ctrlObs.text.trim(),
      };
      if (_esNuevo) {
        await widget.repo.crearAbono(data);
      } else {
        await widget.repo.actualizarAbono(widget.abono!.id, data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(_esNuevo ? 'Añadir póliza al reporte' : 'Editar abono'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Búsqueda de póliza (solo al crear) ──────────────────────
                if (_esNuevo) ...[
                  BuscadorDropdown<Poliza>(
                    label: 'Buscar y seleccionar póliza *',
                    value: _poliza,
                    items: _poliza != null ? [_poliza!] : [],
                    itemLabel: (p) =>
                        '${p.nroPoliza ?? p.id}  –  ${p.nombreCliente ?? ''}',
                    itemSubtitle: (p) =>
                        '${p.nombreRamo ?? ''}  |  ${p.bienAsegurado ?? ''}',
                    itemsLoader: (q) =>
                        _repoPolizas.listar(busqueda: q, limite: 60),
                    onChanged: (p) {
                      if (p != null) _onPolizaSeleccionada(p);
                    },
                    validator: (v) => v == null ? 'Selecciona una póliza' : null,
                  ),
                  const SizedBox(height: 10),
                ],
                // ── Info póliza seleccionada ─────────────────────────────────
                if (_cargandoPoliza)
                  const LinearProgressIndicator()
                else if (_poliza != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.primaryContainer),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 14, color: cs.primary),
                          const SizedBox(width: 6),
                          Text('Póliza seleccionada',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.primary,
                                  fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 6),
                        _InfoRow('Cliente', _poliza!.nombreCliente ?? '—'),
                        _InfoRow('Ramo', _poliza!.nombreRamo ?? '—'),
                        _InfoRow('Producto', _poliza!.nombreProd ?? '—'),
                        _InfoRow(
                            'Bien asegurado', _poliza!.bienAsegurado ?? '—'),
                        _InfoRow('Prima póliza',
                            '\$ ${Fmt.money(_poliza!.primaPoliza)}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // ── Fecha de pago + Estado ──────────────────────────────────
                Row(children: [
                  Expanded(
                    child: _DateField(
                      label: 'Fecha de pago *',
                      value: _fechaPago,
                      df: _df,
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _fechaPago ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          locale: const Locale('es', 'CO'),
                        );
                        if (d != null) setState(() => _fechaPago = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _estadoPago,
                      decoration: const InputDecoration(
                          labelText: 'Estado', border: OutlineInputBorder()),
                      items: kEstadoPagoLabels.entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setState(() => _estadoPago = v ?? 'R'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                // ── Valores ─────────────────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ctrlPrima,
                      inputFormatters: [_ColMoneyFormatter()],
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _recalcular(),
                      decoration: const InputDecoration(
                          labelText: 'Vlr Prima Póliza',
                          border: OutlineInputBorder(),
                          prefixText: '\$ '),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _ctrlAbono,
                      inputFormatters: [_ColMoneyFormatter()],
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _recalcular(),
                      decoration: InputDecoration(
                        labelText: 'Vlr Abono Prima *',
                        border: const OutlineInputBorder(),
                        prefixText: '\$ ',
                        filled: true,
                        fillColor: cs.primaryContainer.withOpacity(0.15),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Requerido' : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                // Comisión principal
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ctrlPorcCom,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _recalcular(),
                      decoration: const InputDecoration(
                          labelText: '% Comisión',
                          border: OutlineInputBorder(),
                          suffixText: '%'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _ctrlVlrCom,
                      inputFormatters: [_ColMoneyFormatter()],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Vlr Comisión',
                          border: OutlineInputBorder(),
                          prefixText: '\$ '),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                // Comisión adicional
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ctrlPorcAd,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _recalcular(),
                      decoration: const InputDecoration(
                          labelText: '% Com. Adicional',
                          border: OutlineInputBorder(),
                          suffixText: '%'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _ctrlVlrAd,
                      inputFormatters: [_ColMoneyFormatter()],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Vlr Com. Adicional',
                          border: OutlineInputBorder(),
                          prefixText: '\$ '),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                // N° Factura + obs
                TextFormField(
                  controller: _ctrlFactura,
                  decoration: const InputDecoration(
                    labelText: 'N° Factura',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.receipt, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _ctrlObs,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Observaciones',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          icon: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save, size: 18),
          label: Text(_esNuevo ? 'Añadir' : 'Actualizar'),
          onPressed: _guardando ? null : _guardar,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares compartidos
// ─────────────────────────────────────────────────────────────────────────────

class _ChipEstadoAbono extends StatelessWidget {
  final String estado;
  const _ChipEstadoAbono(this.estado);

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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        labelEstadoPago(estado),
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}

class _SeccionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SeccionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Icon(icon, size: 18, color: cs.primary),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: cs.primary)),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: cs.primary.withOpacity(0.3))),
    ]);
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final DateFormat df;
  final VoidCallback onTap;
  const _DateField(
      {required this.label,
      required this.value,
      required this.df,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today, size: 16),
        ),
        child: Text(value != null ? df.format(value!) : '—'),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(children: [
        SizedBox(
          width: 110,
          child: Text('$label:',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600)),
        ),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}
