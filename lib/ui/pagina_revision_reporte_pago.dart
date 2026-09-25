// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../datos/abono_poliza.dart';
import '../datos/matching_reporte_pago.dart';
import '../datos/poliza.dart';
import '../datos/repositorio_catalogos.dart';
import '../datos/repositorio_pagos.dart';
import '../datos/repositorio_polizas.dart';
import '../utils/formatters.dart';
import 'theme/app_layout.dart';
import 'theme/app_theme.dart';
import 'widgets/buscador_dropdown.dart';
import 'widgets/selector_fecha.dart';

class _MoneyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue nv) {
    // Admite negativos — se usan para reversar comisiones cuando se
    // cancela una póliza ya pagada.
    final raw = nv.text.replaceAll(RegExp(r'[^0-9,\-]'), '');
    if (raw.isEmpty) return nv.copyWith(text: '');
    final parts = raw.split(',');
    final enteraTxt = parts[0].replaceAll(RegExp(r'[^0-9\-]'), '');
    final negativo = enteraTxt.startsWith('-');
    final entNum = int.tryParse(enteraTxt.replaceAll('-', '')) ?? 0;
    var fmt = '${negativo ? '-' : ''}${_miles(entNum)}';
    if (parts.length > 1) {
      final dec = parts[1].length > 2 ? parts[1].substring(0, 2) : parts[1];
      fmt += ',$dec';
    }
    return nv.copyWith(text: fmt, selection: TextSelection.collapsed(offset: fmt.length));
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

bool _mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Una línea del documento importado, ya con sus controllers de edición.
class _LineaRevision {
  bool incluir;
  Poliza? poliza;
  final ResultadoMatch match;

  /// El usuario eligió la póliza a mano (reemplaza el estado automático).
  bool manual = false;

  /// Motivo si parece un abono ya cargado antes.
  String? duplicado;

  final String nroExtraido;
  final String anexoExtraido;
  final String docExtraido;
  final String clienteExtraido;
  final TextEditingController primaCtrl;
  final TextEditingController abonoCtrl;
  final TextEditingController porcComCtrl;
  final TextEditingController vlrComCtrl;
  final TextEditingController porcComAdCtrl;
  final TextEditingController vlrComAdCtrl;
  final TextEditingController facturaCtrl;
  DateTime? fechaPago;

  _LineaRevision({
    required this.incluir,
    required this.poliza,
    required this.match,
    required this.nroExtraido,
    required this.anexoExtraido,
    required this.docExtraido,
    required this.clienteExtraido,
    required this.primaCtrl,
    required this.abonoCtrl,
    required this.porcComCtrl,
    required this.vlrComCtrl,
    required this.porcComAdCtrl,
    required this.vlrComAdCtrl,
    required this.facturaCtrl,
    required this.fechaPago,
  });

  bool get lista => !manual && match.seIncluyeSolo && duplicado == null;

  void dispose() {
    for (final c in [
      primaCtrl, abonoCtrl, porcComCtrl, vlrComCtrl,
      porcComAdCtrl, vlrComAdCtrl, facturaCtrl,
    ]) {
      c.dispose();
    }
  }
}

/// Pantalla de revisión de la importación masiva de un reporte de
/// comisiones: matchea cada línea extraída contra una póliza real y deja
/// todo editable antes de crear los abonos. Nunca guarda solo, y solo
/// deja tildadas de entrada las líneas con coincidencia exacta.
class PaginaRevisionReportePago extends StatefulWidget {
  final int idReporte;
  final List<Map<String, dynamic>> lineas;

  /// Aseguradora del reporte — descarta pólizas de otra aseguradora que
  /// casualmente tengan el mismo número.
  final int? aseguradoraId;

  const PaginaRevisionReportePago({
    super.key,
    required this.idReporte,
    required this.lineas,
    this.aseguradoraId,
  });

  @override
  State<PaginaRevisionReportePago> createState() =>
      _PaginaRevisionReportePagoState();
}

class _PaginaRevisionReportePagoState
    extends State<PaginaRevisionReportePago> {
  final _repoPolizas = RepositorioPolizas();
  final _repoPagos = RepositorioPagos();
  final _repoCat = RepositorioCatalogos();
  final _df = DateFormat('dd/MM/yyyy');

  bool _cargando = true;
  bool _guardando = false;
  final List<_LineaRevision> _filas = [];
  final Map<int, List<AbonoPoliza>> _abonosPorPoliza = {};

  @override
  void initState() {
    super.initState();
    _matchearTodas();
  }

  @override
  void dispose() {
    for (final f in _filas) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _matchearTodas() async {
    final resultados = await Future.wait(widget.lineas.map((linea) {
      final nro = (linea['nro_poliza'] as String?)?.trim() ?? '';
      final anexo = linea['anexo']?.toString().trim() ?? '';
      final doc = (linea['doc_cliente'] as String?)?.trim() ?? '';
      return _resolver(nro, anexo, doc, linea['vlrprima_poliza'] as num?);
    }));

    for (var i = 0; i < widget.lineas.length; i++) {
      final linea = widget.lineas[i];
      final match = resultados[i];
      final poliza = match.poliza;

      final prima = linea['vlrprima_poliza'] as num? ?? poliza?.primaPoliza;
      final abono = linea['vlrabono_prima'] as num? ?? prima;
      final porcCom = linea['porccomision'] as num? ?? poliza?.porccomPoliza;

      _filas.add(_LineaRevision(
        incluir: match.seIncluyeSolo,
        poliza: poliza,
        match: match,
        nroExtraido: (linea['nro_poliza'] as String?)?.trim() ?? '',
        anexoExtraido: linea['anexo']?.toString().trim() ?? '',
        docExtraido: (linea['doc_cliente'] as String?)?.trim() ?? '',
        clienteExtraido: (linea['nombre_cliente'] as String?)?.trim() ?? '',
        primaCtrl: TextEditingController(text: prima != null ? Fmt.money(prima) : ''),
        abonoCtrl: TextEditingController(text: abono != null ? Fmt.money(abono) : ''),
        porcComCtrl: TextEditingController(text: porcCom != null ? Fmt.numCO(porcCom, dec: 2) : ''),
        vlrComCtrl: TextEditingController(
            text: linea['vlrcomision'] != null ? Fmt.money(linea['vlrcomision'] as num) : ''),
        porcComAdCtrl: TextEditingController(
            text: linea['porccomad'] != null ? Fmt.numCO(linea['porccomad'] as num, dec: 2) : ''),
        vlrComAdCtrl: TextEditingController(
            text: linea['vlrcomad'] != null ? Fmt.money(linea['vlrcomad'] as num) : ''),
        facturaCtrl: TextEditingController(text: (linea['num_factura'] as String?)?.trim() ?? ''),
        fechaPago: _parseFechaISO(linea['fecha_pago']),
      ));
    }

    for (final f in _filas) {
      await _verificarDuplicado(f);
    }
    if (mounted) setState(() => _cargando = false);
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

  /// Trae de la base las pólizas que podrían corresponder (por número y por
  /// documento del cliente) y deja que [resolverMatch] decida con precisión.
  Future<ResultadoMatch> _resolver(String nro, String anexo, String doc, num? prima) async {
    var porNumero = <Poliza>[];
    var delCliente = <Poliza>[];
    try {
      final busqueda = normalizarDoc(nro).replaceFirst(RegExp(r'^0+'), '');
      if (busqueda.isNotEmpty) {
        porNumero = await _repoPolizas.listarPorNroContiene(busqueda);
      }
      if (doc.isNotEmpty) {
        final cliente = await _repoCat.buscarClientePorDocExacto(normalizarDoc(doc));
        if (cliente != null) delCliente = await _repoPolizas.listarPorCliente(cliente.id);
      }
    } catch (e) {
      return ResultadoMatch(EstadoMatch.noEncontrada,
          motivo: 'No se pudo consultar la base ($e). Asignala a mano.');
    }
    if (nro.isEmpty) {
      return ResultadoMatch(EstadoMatch.noEncontrada,
          candidatos: delCliente,
          motivo: 'Esta línea del reporte no trae número de póliza.');
    }
    return resolverMatch(
      nucleo: nro,
      anexo: anexo.isEmpty ? null : anexo,
      docCliente: doc,
      aseguradoraId: widget.aseguradoraId,
      primaLinea: prima,
      candidatos: [...porNumero, ...delCliente],
      polizasDelCliente: delCliente,
    );
  }

  /// Marca la línea si ya existe en la base un abono igual (misma póliza,
  /// mismo valor y misma factura — o misma fecha si no hay factura). Evita
  /// cargar dos veces el mismo pago si se importa el reporte de nuevo.
  ///
  /// No compara contra otras líneas del mismo reporte: ahí líneas con igual
  /// póliza, valor y transacción son movimientos distintos (ej. Mundial:
  /// emisión +, reversión −, re-emisión + con distinto certificado).
  Future<void> _verificarDuplicado(_LineaRevision f) async {
    f.duplicado = null;
    final p = f.poliza;
    if (p == null) return;
    final abono = _parseCO(f.abonoCtrl.text);
    final factura = f.facturaCtrl.text.trim();

    bool igual(num valor, String? fac, DateTime? fecha) {
      if ((valor - abono).abs() >= 0.01) return false;
      if (factura.isNotEmpty) return (fac ?? '').trim() == factura;
      return f.fechaPago != null && fecha != null && _mismoDia(f.fechaPago!, fecha);
    }

    try {
      final existentes =
          _abonosPorPoliza[p.id] ??= await _repoPagos.listarAbonosPorPoliza(p.id);
      for (final a in existentes) {
        if (igual(a.vlrabonoprima, a.numFactura, a.fechaPago)) {
          f.duplicado = 'Ya existe un abono igual para esta póliza '
              '(factura ${a.numFactura ?? '—'}'
              '${a.fechaPago != null ? ', ${_df.format(a.fechaPago!)}' : ''}). '
              'Parece un reporte ya cargado.';
          break;
        }
      }
    } catch (_) {}
    if (f.duplicado != null) f.incluir = false;
  }

  Future<void> _asignar(_LineaRevision f, Poliza? p) async {
    setState(() {
      f.poliza = p;
      f.manual = true;
      f.incluir = p != null;
    });
    await _verificarDuplicado(f);
    if (mounted) setState(() {});
  }

  int get _incluidas => _filas.where((f) => f.incluir).length;

  Future<void> _guardar() async {
    final aGuardar = _filas.where((f) => f.incluir).toList();
    final sinPoliza = aGuardar.where((f) => f.poliza == null).toList();
    if (sinPoliza.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${sinPoliza.length} línea(s) incluida(s) no tienen póliza asignada. Asignala o destildala.'),
        backgroundColor: AppTheme.danger,
      ));
      return;
    }
    if (aGuardar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No hay líneas para guardar.'),
      ));
      return;
    }

    setState(() => _guardando = true);
    var creados = 0;
    var fallidos = 0;
    for (final f in aGuardar) {
      try {
        await _repoPagos.crearAbono({
          'idrep_pago': widget.idReporte,
          'id_poliza': f.poliza!.id,
          'fecha_pago': f.fechaPago?.toIso8601String().substring(0, 10),
          'vlrprima_poliza': _parseCO(f.primaCtrl.text),
          'vlrabono_prima': _parseCO(f.abonoCtrl.text),
          'porccomision': _parseCO(f.porcComCtrl.text),
          'vlrcomision': _parseCO(f.vlrComCtrl.text),
          'porccomad': _parseCO(f.porcComAdCtrl.text),
          'vlrcomad': _parseCO(f.vlrComAdCtrl.text),
          'num_factura': f.facturaCtrl.text.trim().isEmpty ? null : f.facturaCtrl.text.trim(),
          'estado_pago': 'I',
        });
        await _repoPagos.actualizarEstadoPolizaSegunPagos(f.poliza!.id);
        creados++;
      } catch (_) {
        fallidos++;
      }
    }

    if (!mounted) return;
    setState(() => _guardando = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(fallidos == 0
          ? 'Se crearon $creados abono(s).'
          : 'Se crearon $creados abono(s). $fallidos fallaron.'),
      backgroundColor: fallidos == 0 ? null : AppTheme.warning,
    ));
    Navigator.pop(context, creados > 0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final listas = _filas.where((f) => f.lista).length;
    final sinPoliza = _filas.where((f) => f.poliza == null).length;
    final porRevisar = _filas.length - listas - sinPoliza;

    return Scaffold(
      appBar: AppBar(
        title: Text('Revisar importación (${widget.lineas.length} línea(s))'),
        actions: [
          if (_guardando)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton.icon(
              onPressed: _cargando ? null : _guardar,
              icon: const Icon(Icons.save_outlined),
              label: Text('Guardar $_incluidas abono(s)'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : AppLayout.centered(ListView(
              padding: AppLayout.pagePadding,
              children: [
                Text(
                  'Revisá cada línea antes de guardar. Solo quedan tildadas de entrada las que '
                  'coinciden exacto (número de póliza + anexo). Las demás necesitan que elijas '
                  'la póliza o las dejes afuera.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _chip('$listas coinciden exacto', cs.secondaryContainer, cs.onSecondaryContainer),
                  _chip('$porRevisar por revisar', AppTheme.warningContainer, AppTheme.onWarningContainer),
                  _chip('$sinPoliza sin póliza', cs.errorContainer, cs.onErrorContainer),
                ]),
                const SizedBox(height: 16),
                for (int i = 0; i < _filas.length; i++) ...[
                  _filaCard(_filas[i]),
                  const SizedBox(height: 10),
                ],
              ],
            )),
    );
  }

  Widget _chip(String texto, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
        child: Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
      );

  (String, Color, Color) _estadoVisual(_LineaRevision f) {
    final cs = Theme.of(context).colorScheme;
    if (f.manual) {
      return f.poliza == null
          ? ('Sin póliza', cs.errorContainer, cs.onErrorContainer)
          : ('Asignada a mano', cs.primaryContainer, cs.onPrimaryContainer);
    }
    return switch (f.match.estado) {
      EstadoMatch.exacta => ('Coincide exacto', cs.secondaryContainer, cs.onSecondaryContainer),
      EstadoMatch.unicaSinAnexo =>
        ('Coincide (reporte sin anexo)', cs.secondaryContainer, cs.onSecondaryContainer),
      EstadoMatch.revisar => ('Revisar', AppTheme.warningContainer, AppTheme.onWarningContainer),
      EstadoMatch.ambigua => ('Varias opciones', AppTheme.warningContainer, AppTheme.onWarningContainer),
      EstadoMatch.anexoNoRegistrado =>
        ('Anexo no registrado', AppTheme.warningContainer, AppTheme.onWarningContainer),
      EstadoMatch.noEncontrada => ('No encontrada', cs.errorContainer, cs.onErrorContainer),
    };
  }

  Widget _filaCard(_LineaRevision f) {
    final cs = Theme.of(context).colorScheme;
    final (etiqueta, bg, fg) = _estadoVisual(f);
    final mostrarMotivo = !f.manual && f.match.motivo.isNotEmpty && !f.match.seIncluyeSolo;
    final opciones = f.match.candidatos;

    final extraido = [
      'Póliza ${f.nroExtraido.isEmpty ? '—' : f.nroExtraido}',
      'anexo ${f.anexoExtraido.isEmpty ? '—' : f.anexoExtraido}',
      if (f.docExtraido.isNotEmpty) 'doc ${f.docExtraido}',
      if (f.clienteExtraido.isNotEmpty) f.clienteExtraido,
    ].join('  ·  ');

    return Card(
      color: f.incluir ? null : cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Checkbox(
                value: f.incluir,
                onChanged: (v) => setState(() => f.incluir = v ?? false),
              ),
              _chip(etiqueta, bg, fg),
              if (f.duplicado != null) ...[
                const SizedBox(width: 6),
                _chip('Posible duplicado', cs.errorContainer, cs.onErrorContainer),
              ],
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Reporte: $extraido',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            if (mostrarMotivo || f.duplicado != null)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 2, bottom: 6),
                child: Text(
                  [if (f.duplicado != null) f.duplicado!, if (mostrarMotivo) f.match.motivo].join('\n'),
                  style: TextStyle(
                    fontSize: 12,
                    color: f.duplicado != null ? cs.error : AppTheme.onWarningContainer,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            if (f.poliza != null)
              Padding(
                padding: const EdgeInsets.only(left: 48, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Póliza ${f.poliza!.nroPoliza ?? f.poliza!.id} — ${f.poliza!.nombreCliente ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      '${f.poliza!.nombreAseg ?? '—'} · ${f.poliza!.nombreRamo ?? '—'} · '
                      '${f.poliza!.nombreProd ?? '—'}  ·  Prima póliza: \$ ${Fmt.money(f.poliza!.primaPoliza)}',
                      style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            if (opciones.isNotEmpty && !f.match.seIncluyeSolo)
              Padding(
                padding: const EdgeInsets.only(left: 48, bottom: 8),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final c in opciones)
                    ChoiceChip(
                      label: Text(
                        '${c.nroPoliza ?? c.id} — ${c.nombreCliente ?? ''} '
                        '(\$ ${Fmt.money(c.primaPoliza)})',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      selected: f.poliza?.id == c.id,
                      onSelected: (_) => _asignar(f, c),
                    ),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 48, bottom: 8),
              child: BuscadorDropdown<Poliza>(
                label: f.poliza == null ? 'Asignar póliza manualmente' : 'Cambiar póliza',
                value: f.poliza,
                items: f.poliza != null ? [f.poliza!] : [],
                itemLabel: (p) => '${p.nroPoliza ?? p.id}  –  ${p.nombreCliente ?? ''}',
                itemsLoader: (q) => _repoPolizas.listar(busqueda: q, limite: 60),
                onChanged: (p) => _asignar(f, p),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Wrap(spacing: 10, runSpacing: 10, children: [
                _campoFecha(f),
                _campo('Prima', f.primaCtrl),
                _campo('Abono', f.abonoCtrl),
                _campo('% Com.', f.porcComCtrl),
                _campo('Vlr Com.', f.vlrComCtrl),
                _campo('% Com. Ad.', f.porcComAdCtrl),
                _campo('Vlr Com. Ad.', f.vlrComAdCtrl),
                _campo('Factura', f.facturaCtrl, money: false),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campo(String label, TextEditingController ctrl, {bool money = true}) {
    return SizedBox(
      width: 140,
      child: TextFormField(
        controller: ctrl,
        keyboardType: money ? TextInputType.number : TextInputType.text,
        inputFormatters: money ? [_MoneyFormatter()] : null,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _campoFecha(_LineaRevision f) {
    return SizedBox(
      width: 140,
      child: InkWell(
        onTap: () async {
          final d = await mostrarSelectorFecha(
            context,
            inicial: f.fechaPago,
            primera: DateTime(2000),
            ultima: DateTime(2100),
          );
          if (d != null) setState(() => f.fechaPago = d);
        },
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Fecha pago',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          child: Text(
            f.fechaPago != null ? _df.format(f.fechaPago!) : '—',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ),
    );
  }
}
