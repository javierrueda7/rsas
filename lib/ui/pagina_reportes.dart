import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../datos/poliza.dart';
import '../datos/repositorio_polizas.dart';

// ── Modelo auxiliar ───────────────────────────────────────────────────────────

class _Grupo {
  final String nombre;
  int cantidad = 0;
  double prima = 0;

  _Grupo(this.nombre);

  void agregar(Poliza p) {
    cantidad++;
    prima += p.primaPoliza;
  }
}

// ── Widget principal ──────────────────────────────────────────────────────────

class PaginaReportes extends StatefulWidget {
  const PaginaReportes({super.key});

  @override
  State<PaginaReportes> createState() => _PaginaReportesState();
}

class _PaginaReportesState extends State<PaginaReportes>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _repo = RepositorioPolizas();

  List<Poliza> _polizas = [];
  bool _cargando = true;
  int _cargados = 0;
  bool _exportando = false;

  final _df = DateFormat('dd/MM/yyyy');
  final _dfh = DateFormat('dd/MM/yyyy HH:mm');
  final _nf = NumberFormat.decimalPattern('es_CO');

  static const _tabs = ['Resumen', 'Aseguradoras', 'Ramos', 'Asesores', 'Vencimientos'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Carga de datos ────────────────────────────────────────────────────────

  Future<void> _cargar() async {
    setState(() { _cargando = true; _cargados = 0; });
    try {
      final data = await _repo.listarTodos(
        onProgreso: (n) { if (mounted) setState(() => _cargados = n); },
      );
      if (mounted) setState(() { _polizas = data; _cargando = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando datos: $e')),
        );
      }
    }
  }

  // ── Cálculos ──────────────────────────────────────────────────────────────

  DateTime get _hoy =>
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  List<Poliza> get _vigentes => _polizas
      .where((p) => p.ffinPoliza != null && !p.ffinPoliza!.isBefore(_hoy))
      .toList();

  List<Poliza> get _vencidas => _polizas
      .where((p) => p.ffinPoliza != null && p.ffinPoliza!.isBefore(_hoy))
      .toList()
    ..sort((a, b) => b.ffinPoliza!.compareTo(a.ffinPoliza!));

  List<Poliza> _porVencer(int desdeD, int hastaD) => _polizas.where((p) {
        if (p.ffinPoliza == null) return false;
        final diff = p.ffinPoliza!.difference(_hoy).inDays;
        return diff >= desdeD && diff <= hastaD;
      }).toList()
        ..sort((a, b) => a.ffinPoliza!.compareTo(b.ffinPoliza!));

  double get _primaTotal =>
      _polizas.fold(0.0, (s, p) => s + p.primaPoliza);

  Map<String, _Grupo> _agrupar(String Function(Poliza) getKey) {
    final map = <String, _Grupo>{};
    for (final p in _polizas) {
      final k = getKey(p);
      (map[k] ??= _Grupo(k)).agregar(p);
    }
    return Map.fromEntries(
      map.entries.toList()
        ..sort((a, b) => b.value.cantidad.compareTo(a.value.cantidad)),
    );
  }

  // ── Exportar Excel ────────────────────────────────────────────────────────

  Future<void> _exportarExcel() async {
    setState(() => _exportando = true);
    try {
      final wb = Excel.createExcel();

      // ── Hoja 1: Todas las pólizas ─────────────────────────────────────
      final sh1 = wb['Pólizas'];
      sh1.appendRow([
        TextCellValue('Cód'), TextCellValue('Nro Póliza'),
        TextCellValue('Bien Asegurado'), TextCellValue('Cliente'),
        TextCellValue('Doc. Cliente'), TextCellValue('Aseguradora'),
        TextCellValue('Ramo'), TextCellValue('Producto'),
        TextCellValue('F. Inicio'), TextCellValue('F. Vencimiento'),
        TextCellValue('Prima'), TextCellValue('Valor Asegurado'),
        TextCellValue('F. Expedición'), TextCellValue('Asesor'),
        TextCellValue('F. Registro'), TextCellValue('Usuario'),
      ]);
      for (final p in _polizas) {
        sh1.appendRow([
          IntCellValue(p.id),
          TextCellValue(p.nroPoliza ?? ''),
          TextCellValue(p.bienAsegurado ?? ''),
          TextCellValue(p.nombreCliente ?? ''),
          TextCellValue(p.docCliente ?? ''),
          TextCellValue(p.nombreAseg ?? ''),
          TextCellValue(p.nombreRamo ?? ''),
          TextCellValue(p.nombreProd ?? ''),
          TextCellValue(p.finiPoliza != null ? _df.format(p.finiPoliza!) : ''),
          TextCellValue(p.ffinPoliza != null ? _df.format(p.ffinPoliza!) : ''),
          DoubleCellValue(p.primaPoliza.toDouble()),
          DoubleCellValue(p.valorPoliza.toDouble()),
          TextCellValue(p.fexpPoliza != null ? _df.format(p.fexpPoliza!) : ''),
          TextCellValue(p.nombreAsesor ?? ''),
          TextCellValue(p.fcreado != null ? _dfh.format(p.fcreado!.toLocal()) : ''),
          TextCellValue(p.apodoUsuario ?? ''),
        ]);
      }

      // ── Hoja 2: Por Aseguradora ───────────────────────────────────────
      final sh2 = wb['Por Aseguradora'];
      sh2.appendRow([
        TextCellValue('Aseguradora'),
        TextCellValue('Pólizas'),
        TextCellValue('Prima Total'),
      ]);
      for (final g in _agrupar((p) => p.nombreAseg ?? 'Sin aseguradora').values) {
        sh2.appendRow([
          TextCellValue(g.nombre),
          IntCellValue(g.cantidad),
          DoubleCellValue(g.prima),
        ]);
      }

      // ── Hoja 3: Por Ramo ─────────────────────────────────────────────
      final sh3 = wb['Por Ramo'];
      sh3.appendRow([
        TextCellValue('Ramo'),
        TextCellValue('Pólizas'),
        TextCellValue('Prima Total'),
      ]);
      for (final g in _agrupar((p) => p.nombreRamo ?? 'Sin ramo').values) {
        sh3.appendRow([
          TextCellValue(g.nombre),
          IntCellValue(g.cantidad),
          DoubleCellValue(g.prima),
        ]);
      }

      // ── Hoja 4: Por Asesor ────────────────────────────────────────────
      final sh4 = wb['Por Asesor'];
      sh4.appendRow([
        TextCellValue('Asesor'),
        TextCellValue('Pólizas'),
        TextCellValue('Prima Total'),
      ]);
      for (final g in _agrupar((p) => p.nombreAsesor ?? 'Sin asesor').values) {
        sh4.appendRow([
          TextCellValue(g.nombre),
          IntCellValue(g.cantidad),
          DoubleCellValue(g.prima),
        ]);
      }

      // ── Hoja 5: Vencimientos próximos 90 días ─────────────────────────
      final sh5 = wb['Vencimientos 90 días'];
      sh5.appendRow([
        TextCellValue('Cód'), TextCellValue('Nro Póliza'),
        TextCellValue('Cliente'), TextCellValue('Aseguradora'),
        TextCellValue('Ramo'), TextCellValue('F. Vencimiento'),
        TextCellValue('Días restantes'), TextCellValue('Prima'),
        TextCellValue('Asesor'),
      ]);
      for (final p in _porVencer(0, 90)) {
        sh5.appendRow([
          IntCellValue(p.id),
          TextCellValue(p.nroPoliza ?? ''),
          TextCellValue(p.nombreCliente ?? ''),
          TextCellValue(p.nombreAseg ?? ''),
          TextCellValue(p.nombreRamo ?? ''),
          TextCellValue(_df.format(p.ffinPoliza!)),
          IntCellValue(p.ffinPoliza!.difference(_hoy).inDays),
          DoubleCellValue(p.primaPoliza.toDouble()),
          TextCellValue(p.nombreAsesor ?? ''),
        ]);
      }

      // Eliminar la hoja vacía por defecto si existe
      wb.delete('Sheet1');

      final bytes = wb.encode();
      if (bytes == null) throw Exception('No se pudo generar el archivo.');

      final nombre =
          'polizas_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
      await FileSaver.instance.saveFile(
        name: nombre,
        bytes: Uint8List.fromList(bytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archivo Excel generado correctamente.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        bottom: _cargando
            ? null
            : TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
              ),
        actions: [
          if (!_cargando)
            _exportando
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Exportar a Excel',
                    icon: const Icon(Icons.download_outlined),
                    onPressed: _exportarExcel,
                  ),
          if (!_cargando)
            IconButton(
              tooltip: 'Recargar datos',
              icon: const Icon(Icons.refresh),
              onPressed: _cargar,
            ),
        ],
      ),
      body: _cargando
          ? _vistaCargando()
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _tabResumen(),
                _tabAgrupado(
                  _agrupar((p) => p.nombreAseg ?? 'Sin aseguradora'),
                  'Aseguradora',
                ),
                _tabAgrupado(
                  _agrupar((p) => p.nombreRamo ?? 'Sin ramo'),
                  'Ramo',
                ),
                _tabAgrupado(
                  _agrupar((p) => p.nombreAsesor ?? 'Sin asesor'),
                  'Asesor',
                ),
                _tabVencimientos(),
              ],
            ),
    );
  }

  Widget _vistaCargando() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            _cargados == 0
                ? 'Cargando datos...'
                : 'Cargando... ${_nf.format(_cargados)} pólizas',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 6),
          const Text(
            'Esto puede tardar unos segundos.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ── Tab Resumen ───────────────────────────────────────────────────────────

  Widget _tabResumen() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final vigentes = _vigentes;
    final vencidas = _vencidas;
    final pv30 = _porVencer(0, 30);
    final pv60 = _porVencer(31, 60);
    final pv90 = _porVencer(61, 90);
    final topAseg = _agrupar((p) => p.nombreAseg ?? 'Sin aseguradora').values.take(5).toList();
    final topRamo = _agrupar((p) => p.nombreRamo ?? 'Sin ramo').values.take(5).toList();
    final total = _polizas.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Encabezado ──────────────────────────────────────────────
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Resumen general', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Datos al ${_df.format(_hoy)} · ${_nf.format(total)} pólizas en total',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ])),
              ]),
              const SizedBox(height: 20),

              // ── KPI cards principales ────────────────────────────────────
              Wrap(spacing: 12, runSpacing: 12, children: [
                _kpi('Total pólizas', _nf.format(total), Icons.receipt_long_outlined, cs.primary),
                _kpi('Vigentes', _nf.format(vigentes.length), Icons.check_circle_outline, Colors.green.shade600),
                _kpi('Vencidas', _nf.format(vencidas.length), Icons.cancel_outlined, Colors.red.shade600),
                _kpi('Prima total', _nf.format(_primaTotal), Icons.attach_money, cs.secondary),
              ]),
              const SizedBox(height: 24),

              // ── Vencimientos ─────────────────────────────────────────────
              Text('Vencimientos próximos', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _kpi('0 – 30 días', _nf.format(pv30.length), Icons.warning_amber_outlined, Colors.red.shade600),
                _kpi('31 – 60 días', _nf.format(pv60.length), Icons.access_time_outlined, Colors.orange.shade700),
                _kpi('61 – 90 días', _nf.format(pv90.length), Icons.event_outlined, Colors.amber.shade700),
              ]),
              const SizedBox(height: 28),

              // ── Top aseguradoras ─────────────────────────────────────────
              Text('Top aseguradoras', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ...topAseg.map((g) => _miniBar(g.nombre, g.cantidad, total, cs.primary)),
              const SizedBox(height: 28),

              // ── Top ramos ────────────────────────────────────────────────
              Text('Top ramos', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ...topRamo.map((g) => _miniBar(g.nombre, g.cantidad, total, cs.tertiary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kpi(String titulo, String valor, IconData icono, Color color) {
    return SizedBox(
      width: 175,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icono, color: color, size: 22),
            const SizedBox(height: 10),
            Text(valor,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(titulo, style: const TextStyle(fontSize: 12)),
          ]),
        ),
      ),
    );
  }

  Widget _miniBar(String nombre, int cantidad, int total, Color color) {
    final pct = total == 0 ? 0.0 : (cantidad / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(
          width: 180,
          child: Text(nombre,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: LayoutBuilder(builder: (_, c) => SizedBox(
            height: 18,
            child: Stack(children: [
              Container(
                width: c.maxWidth,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: c.maxWidth * pct,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ]),
          )),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 45,
          child: Text('$cantidad',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  // ── Tab Agrupado (Aseguradoras / Ramos / Asesores) ───────────────────────

  Widget _tabAgrupado(Map<String, _Grupo> grupos, String colNombre) {
    final cs = Theme.of(context).colorScheme;
    if (grupos.isEmpty) {
      return const Center(child: Text('Sin datos'));
    }
    final maxCantidad = grupos.values.first.cantidad;
    final total = _polizas.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Encabezado tabla
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            SizedBox(width: 200, child: Text(colNombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
            const Expanded(child: Text('Cantidad', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
            SizedBox(width: 130, child: Text('Prima total', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
            SizedBox(width: 55, child: Text('% total', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          ]),
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),

        ...grupos.values.map((g) {
          final pct = maxCantidad == 0 ? 0.0 : (g.cantidad / maxCantidad).clamp(0.0, 1.0);
          final pctTotal = total == 0 ? 0.0 : g.cantidad / total * 100;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              SizedBox(
                width: 200,
                child: Text(g.nombre,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
              ),
              Expanded(
                child: LayoutBuilder(builder: (_, c) => Row(children: [
                  SizedBox(
                    width: c.maxWidth * 0.65,
                    height: 20,
                    child: Stack(children: [
                      Container(
                        width: c.maxWidth * 0.65,
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        width: c.maxWidth * 0.65 * pct,
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Text('${g.cantidad}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ])),
              ),
              SizedBox(
                width: 130,
                child: Text(_nf.format(g.prima),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12)),
              ),
              SizedBox(
                width: 55,
                child: Text('${pctTotal.toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ),
            ]),
          );
        }),
      ],
    );
  }

  // ── Tab Vencimientos ──────────────────────────────────────────────────────

  Widget _tabVencimientos() {
    final cs = Theme.of(context).colorScheme;
    final secciones = [
      ('Vencen en 0 – 30 días', _porVencer(0, 30), Colors.red.shade600, Icons.warning_amber_outlined),
      ('Vencen en 31 – 60 días', _porVencer(31, 60), Colors.orange.shade700, Icons.access_time_outlined),
      ('Vencen en 61 – 90 días', _porVencer(61, 90), Colors.amber.shade700, Icons.event_outlined),
      ('Ya vencidas (últimas 100)', _vencidas.take(100).toList(), Colors.grey.shade500, Icons.cancel_outlined),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: secciones.expand<Widget>((rec) {
        final (titulo, lista, color, icono) = rec;
        if (lista.isEmpty) return const [];
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
            child: Row(children: [
              Icon(icono, size: 16, color: color),
              const SizedBox(width: 6),
              Text('$titulo  (${lista.length})',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color)),
            ]),
          ),
          ...lista.map((p) {
            final dias = p.ffinPoliza!.difference(_hoy).inDays;
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: color.withOpacity(0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.nroPoliza ?? 'Sin número',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(p.nombreCliente ?? '—', style: const TextStyle(fontSize: 12)),
                    Text(
                      '${p.nombreAseg ?? '—'}  ·  ${p.nombreRamo ?? '—'}',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_df.format(p.ffinPoliza!),
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color)),
                    Text(
                      dias < 0 ? '${-dias} días vencida' : '$dias días',
                      style: TextStyle(fontSize: 11, color: color),
                    ),
                    if ((p.nombreAsesor ?? '').isNotEmpty)
                      Text(p.nombreAsesor!,
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ]),
                ]),
              ),
            );
          }),
          const SizedBox(height: 8),
        ];
      }).toList(),
    );
  }
}
