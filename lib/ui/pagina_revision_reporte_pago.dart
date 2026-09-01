// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../datos/poliza.dart';
import '../datos/repositorio_pagos.dart';
import '../datos/repositorio_polizas.dart';
import '../utils/formatters.dart';
import 'theme/app_layout.dart';
import 'theme/app_theme.dart';
import 'widgets/buscador_dropdown.dart';

class _MoneyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue nv) {
    final raw = nv.text.replaceAll(RegExp(r'[^0-9,]'), '');
    if (raw.isEmpty) return nv.copyWith(text: '');
    final parts = raw.split(',');
    final entNum = int.tryParse(parts[0]) ?? 0;
    var fmt = _miles(entNum);
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

String _normalizar(String s) {
  var r = s.trim().toUpperCase();
  const acentos = {'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ñ': 'N'};
  acentos.forEach((k, v) => r = r.replaceAll(k, v));
  return r;
}

/// Una línea del documento importado, ya con sus controllers de edición.
class _LineaRevision {
  bool incluir;
  Poliza? poliza;
  final String nroExtraido;
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
    required this.nroExtraido,
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
/// todo editable antes de crear los abonos. Nunca guarda solo.
class PaginaRevisionReportePago extends StatefulWidget {
  final int idReporte;
  final List<Map<String, dynamic>> lineas;

  const PaginaRevisionReportePago({
    super.key,
    required this.idReporte,
    required this.lineas,
  });

  @override
  State<PaginaRevisionReportePago> createState() =>
      _PaginaRevisionReportePagoState();
}

class _PaginaRevisionReportePagoState
    extends State<PaginaRevisionReportePago> {
  final _repoPolizas = RepositorioPolizas();
  final _repoPagos = RepositorioPagos();
  final _df = DateFormat('dd/MM/yyyy');

  bool _cargando = true;
  bool _guardando = false;
  final List<_LineaRevision> _filas = [];

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
    for (final linea in widget.lineas) {
      final nro = (linea['nro_poliza'] as String?)?.trim() ?? '';
      final cliente = (linea['nombre_cliente'] as String?)?.trim() ?? '';
      final poliza = await _buscarPoliza(nro, cliente);

      final prima = linea['vlrprima_poliza'] as num? ?? poliza?.primaPoliza;
      final abono = linea['vlrabono_prima'] as num? ?? prima;
      final porcCom = linea['porccomision'] as num? ?? poliza?.porccomPoliza;

      _filas.add(_LineaRevision(
        incluir: poliza != null,
        poliza: poliza,
        nroExtraido: nro,
        clienteExtraido: cliente,
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

  Future<Poliza?> _buscarPoliza(String nro, String cliente) async {
    try {
      if (nro.isNotEmpty) {
        final res = await _repoPolizas.listar(busqueda: nro, limite: 10);
        final normNro = _normalizar(nro);
        for (final p in res) {
          if (p.nroPoliza != null && _normalizar(p.nroPoliza!) == normNro) {
            return p;
          }
        }
      }
      if (cliente.isNotEmpty) {
        final res = await _repoPolizas.listar(busqueda: cliente, limite: 10);
        final normCliente = _normalizar(cliente);
        for (final p in res) {
          if (p.nombreCliente != null &&
              _normalizar(p.nombreCliente!) == normCliente) {
            return p;
          }
        }
      }
    } catch (_) {
      // Si falla la búsqueda, la línea queda "no encontrada" para revisar a mano.
    }
    return null;
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
                  'Revisá cada línea antes de guardar. Las que no encontraron una póliza '
                  'coincidente están destildadas — asignala manualmente o dejala afuera.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 16),
                for (int i = 0; i < _filas.length; i++) ...[
                  _filaCard(_filas[i]),
                  const SizedBox(height: 10),
                ],
              ],
            )),
    );
  }

  Widget _filaCard(_LineaRevision f) {
    final cs = Theme.of(context).colorScheme;
    final encontrada = f.poliza != null;

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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: encontrada ? cs.secondaryContainer : AppTheme.warningContainer,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  encontrada ? 'Encontrada' : 'No encontrada',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: encontrada ? cs.onSecondaryContainer : AppTheme.onWarningContainer,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Extraído: ${f.nroExtraido.isEmpty ? '—' : f.nroExtraido}  ·  ${f.clienteExtraido.isEmpty ? '—' : f.clienteExtraido}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 8),
            if (encontrada)
              Padding(
                padding: const EdgeInsets.only(left: 48, bottom: 8),
                child: Text(
                  'Póliza ${f.poliza!.nroPoliza ?? f.poliza!.id} — ${f.poliza!.nombreCliente ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 48, bottom: 8),
                child: BuscadorDropdown<Poliza>(
                  label: 'Asignar póliza manualmente',
                  value: f.poliza,
                  items: f.poliza != null ? [f.poliza!] : [],
                  itemLabel: (p) => '${p.nroPoliza ?? p.id}  –  ${p.nombreCliente ?? ''}',
                  itemsLoader: (q) => _repoPolizas.listar(busqueda: q, limite: 60),
                  onChanged: (p) => setState(() {
                    f.poliza = p;
                    if (p != null) f.incluir = true;
                  }),
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
          final d = await showDatePicker(
            context: context,
            initialDate: f.fechaPago ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            locale: const Locale('es', 'CO'),
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
