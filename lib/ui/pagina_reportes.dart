import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// ─────────────────────────────────────────────────────────────────────────────

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
  String? _errorCarga;

  // ── Filtros ────────────────────────────────────────────────────────────────
  bool _filtrosVisible = true;
  String? _filtroAseg;
  String? _filtroRamo;
  String? _filtroAsesor;
  String? _filtroProd;
  int _filtroEstado = 0;         // 0=Todas 1=Vigentes 2=Vencidas 3=Sin fecha
  DateTime? _filtroFfinDesde;    // F. Vencimiento desde
  DateTime? _filtroFfinHasta;    // F. Vencimiento hasta
  DateTime? _filtroFregDesde;    // F. Registro desde
  DateTime? _filtroFregHasta;    // F. Registro hasta
  DateTime? _filtroFexpDesde;    // F. Expedición desde
  DateTime? _filtroFexpHasta;    // F. Expedición hasta

  // ── Ordenamiento en tabs agrupados ────────────────────────────────────────
  bool _sortByPrima = false;

  final _df = DateFormat('dd/MM/yyyy');
  final _nf  = NumberFormat.decimalPattern('es_CO');

  static const _tabs = ['Resumen', 'Aseguradoras', 'Ramos', 'Asesores', 'Vencimientos'];
  // Índices de tabs para navegación
  static const _iAseg = 1, _iRamo = 2, _iVenc = 4;

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

  // ── Carga ─────────────────────────────────────────────────────────────────

  Future<void> _cargar() async {
    setState(() { _cargando = true; _cargados = 0; _errorCarga = null; });
    try {
      final data = await _repo.listarTodos(
        onProgreso: (n) { if (mounted) setState(() => _cargados = n); },
      ).timeout(const Duration(minutes: 3));
      if (mounted) setState(() { _polizas = data; _cargando = false; });
    } catch (e) {
      if (mounted) setState(() { _cargando = false; _errorCarga = _mensajeError(e); });
    }
  }

  String _mensajeError(Object e) {
    final s = e.toString();
    if (s.contains('57014') || s.contains('canceling') || s.contains('timeout') || s.contains('TimeoutException')) {
      return 'La consulta tardó demasiado.\nIntenta de nuevo o contacta al administrador.';
    }
    if (s.contains('SocketException') || s.contains('network') || s.contains('connection')) {
      return 'Sin conexión a internet.\nVerifica tu red e intenta de nuevo.';
    }
    return 'Error al cargar los datos.\n$s';
  }

  // ── Listas únicas (siempre del set completo) ──────────────────────────────

  List<String> get _listaAseg => _polizas
      .map((p) => p.nombreAseg ?? '').where((s) => s.isNotEmpty)
      .toSet().toList()..sort();

  List<String> get _listaRamos => _polizas
      .map((p) => p.nombreRamo ?? '').where((s) => s.isNotEmpty)
      .toSet().toList()..sort();

  List<String> get _listaAsesores => _polizas
      .map((p) => p.nombreAsesor ?? '').where((s) => s.isNotEmpty)
      .toSet().toList()..sort();

  List<String> get _listaProductos => _polizas
      .map((p) => p.nombreProd ?? '').where((s) => s.isNotEmpty)
      .toSet().toList()..sort();

  // ── Filtrado ──────────────────────────────────────────────────────────────

  List<Poliza> get _filtradas {
    final hoy = _hoy;
    return _polizas.where((p) {
      if (_filtroAseg   != null && (p.nombreAseg   ?? '') != _filtroAseg)   return false;
      if (_filtroRamo   != null && (p.nombreRamo   ?? '') != _filtroRamo)   return false;
      if (_filtroAsesor != null && (p.nombreAsesor ?? '') != _filtroAsesor) return false;
      if (_filtroProd   != null && (p.nombreProd   ?? '') != _filtroProd)   return false;
      if (_filtroEstado == 1 &&
          (p.ffinPoliza == null || p.ffinPoliza!.isBefore(hoy))) return false;
      if (_filtroEstado == 2 &&
          (p.ffinPoliza == null || !p.ffinPoliza!.isBefore(hoy))) return false;
      if (_filtroEstado == 3 && p.ffinPoliza != null) return false;
      if (_filtroFfinDesde != null &&
          (p.ffinPoliza == null || p.ffinPoliza!.isBefore(_filtroFfinDesde!))) return false;
      if (_filtroFfinHasta != null &&
          (p.ffinPoliza == null ||
           p.ffinPoliza!.isAfter(_filtroFfinHasta!.add(const Duration(days: 1))))) return false;
      if (_filtroFregDesde != null) {
        final fc = p.fcreado?.toLocal();
        if (fc == null || fc.isBefore(_filtroFregDesde!)) return false;
      }
      if (_filtroFregHasta != null) {
        final fc = p.fcreado?.toLocal();
        if (fc == null ||
            fc.isAfter(_filtroFregHasta!.add(const Duration(days: 1)))) return false;
      }
      if (_filtroFexpDesde != null &&
          (p.fexpPoliza == null || p.fexpPoliza!.isBefore(_filtroFexpDesde!))) return false;
      if (_filtroFexpHasta != null &&
          (p.fexpPoliza == null ||
           p.fexpPoliza!.isAfter(_filtroFexpHasta!.add(const Duration(days: 1))))) return false;
      return true;
    }).toList();
  }

  int get _filtrosActivos =>
      [_filtroAseg, _filtroRamo, _filtroAsesor, _filtroProd].where((f) => f != null).length +
      (_filtroEstado != 0 ? 1 : 0) +
      ((_filtroFfinDesde != null || _filtroFfinHasta != null) ? 1 : 0) +
      ((_filtroFregDesde != null || _filtroFregHasta != null) ? 1 : 0) +
      ((_filtroFexpDesde != null || _filtroFexpHasta != null) ? 1 : 0);

  void _limpiarFiltros() => setState(() {
        _filtroAseg = _filtroRamo = _filtroAsesor = _filtroProd = null;
        _filtroEstado = 0;
        _filtroFfinDesde = _filtroFfinHasta = null;
        _filtroFregDesde = _filtroFregHasta = null;
        _filtroFexpDesde = _filtroFexpHasta = null;
      });

  // ── Selectores de fechas ──────────────────────────────────────────────────

  Future<void> _seleccionarFfin() async {
    final picked = await showDateRangePicker(
      context: context,
      locale: const Locale('es', 'CO'),
      firstDate: DateTime(2000),
      lastDate: DateTime(2035),
      initialDateRange: (_filtroFfinDesde != null && _filtroFfinHasta != null)
          ? DateTimeRange(start: _filtroFfinDesde!, end: _filtroFfinHasta!)
          : DateTimeRange(start: DateTime(_hoy.year, 1, 1), end: _hoy),
      helpText: 'Rango F. Vencimiento',
      saveText: 'Aplicar',
    );
    if (picked != null && mounted) {
      setState(() {
        _filtroFfinDesde = picked.start;
        _filtroFfinHasta = picked.end;
      });
    }
  }

  Future<void> _seleccionarFreg() async {
    final picked = await showDateRangePicker(
      context: context,
      locale: const Locale('es', 'CO'),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: (_filtroFregDesde != null && _filtroFregHasta != null)
          ? DateTimeRange(start: _filtroFregDesde!, end: _filtroFregHasta!)
          : DateTimeRange(start: DateTime(_hoy.year, 1, 1), end: _hoy),
      helpText: 'Rango F. Registro',
      saveText: 'Aplicar',
    );
    if (picked != null && mounted) {
      setState(() {
        _filtroFregDesde = picked.start;
        _filtroFregHasta = picked.end;
      });
    }
  }

  // ── Presets de fecha ──────────────────────────────────────────────────────

  void _presetFfin(int diasDesde, int diasHasta) {
    final hoy = _hoy;
    setState(() {
      _filtroFfinDesde = hoy.add(Duration(days: diasDesde));
      _filtroFfinHasta = hoy.add(Duration(days: diasHasta));
    });
  }

  Future<void> _seleccionarFexp() async {
    final picked = await showDateRangePicker(
      context: context,
      locale: const Locale('es', 'CO'),
      firstDate: DateTime(2000),
      lastDate: DateTime(2035),
      initialDateRange: (_filtroFexpDesde != null && _filtroFexpHasta != null)
          ? DateTimeRange(start: _filtroFexpDesde!, end: _filtroFexpHasta!)
          : DateTimeRange(start: DateTime(_hoy.year, 1, 1), end: _hoy),
      helpText: 'Rango F. Expedición',
      saveText: 'Aplicar',
    );
    if (picked != null && mounted) {
      setState(() {
        _filtroFexpDesde = picked.start;
        _filtroFexpHasta = picked.end;
      });
    }
  }

  void _presetFexpMes() {
    final hoy = _hoy;
    setState(() {
      _filtroFexpDesde = DateTime(hoy.year, hoy.month, 1);
      _filtroFexpHasta = DateTime(hoy.year, hoy.month + 1, 0);
    });
  }

  void _presetFexpAnio() {
    final hoy = _hoy;
    setState(() {
      _filtroFexpDesde = DateTime(hoy.year, 1, 1);
      _filtroFexpHasta = DateTime(hoy.year, 12, 31);
    });
  }

  void _presetFregMes() {
    final hoy = _hoy;
    setState(() {
      _filtroFregDesde = DateTime(hoy.year, hoy.month, 1);
      _filtroFregHasta = DateTime(hoy.year, hoy.month + 1, 0);
    });
  }

  void _presetFregAnio() {
    final hoy = _hoy;
    setState(() {
      _filtroFregDesde = DateTime(hoy.year, 1, 1);
      _filtroFregHasta = DateTime(hoy.year, 12, 31);
    });
  }

  // ── Cálculos ──────────────────────────────────────────────────────────────

  DateTime get _hoy {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  List<Poliza> get _vigentes => _filtradas
      .where((p) => p.ffinPoliza != null && !p.ffinPoliza!.isBefore(_hoy))
      .toList();

  List<Poliza> get _vencidas => _filtradas
      .where((p) => p.ffinPoliza != null && p.ffinPoliza!.isBefore(_hoy))
      .toList()
    ..sort((a, b) => b.ffinPoliza!.compareTo(a.ffinPoliza!));

  List<Poliza> _porVencer(int desdeD, int hastaD) =>
      _filtradas.where((p) {
        if (p.ffinPoliza == null) return false;
        final diff = p.ffinPoliza!.difference(_hoy).inDays;
        return diff >= desdeD && diff <= hastaD;
      }).toList()
        ..sort((a, b) => a.ffinPoliza!.compareTo(b.ffinPoliza!));

  List<Poliza> get _sinFfin => _filtradas
      .where((p) => p.ffinPoliza == null)
      .toList()
        ..sort((a, b) => (b.fcreado ?? DateTime(0)).compareTo(a.fcreado ?? DateTime(0)));

  double get _primaTotal =>
      _filtradas.fold(0.0, (s, p) => s + p.primaPoliza);

  Map<String, _Grupo> _agrupar(List<Poliza> lista, String Function(Poliza) key) {
    final map = <String, _Grupo>{};
    for (final p in lista) {
      final k = key(p);
      (map[k] ??= _Grupo(k)).agregar(p);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => _sortByPrima
          ? b.value.prima.compareTo(a.value.prima)
          : b.value.cantidad.compareTo(a.value.cantidad));
    return Map.fromEntries(entries);
  }

  // ── Filtro rápido desde tab agrupado ──────────────────────────────────────

  void _filtrarPor(String tipo, String valor) {
    setState(() {
      if (tipo == 'aseg') _filtroAseg = valor;
      if (tipo == 'ramo') _filtroRamo = valor;
      if (tipo == 'asesor') _filtroAsesor = valor;
    });
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Filtrando por: $valor'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Quitar',
          onPressed: () => setState(() {
            if (tipo == 'aseg') _filtroAseg = null;
            if (tipo == 'ramo') _filtroRamo = null;
            if (tipo == 'asesor') _filtroAsesor = null;
          }),
        ),
      ),
    );
  }

  // ── Exportar Excel ────────────────────────────────────────────────────────

  Future<void> _exportarExcel() async {
    setState(() => _exportando = true);
    // Ceder el hilo para que Flutter repinte el indicador antes de trabajar
    await Future.delayed(const Duration(milliseconds: 80));
    try {
      final hoy = _hoy;
      final bytes = await compute(_buildExcelBytes, _ExcelParams(
        polizas: _filtradas,
        porVencer90: _porVencer(0, 90),
        hoy: hoy,
      ));
      if (bytes == null) throw Exception('No se pudo generar el archivo.');

      await FileSaver.instance.saveFile(
        name: 'polizas_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
        bytes: bytes,
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel generado correctamente.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final activos = _filtrosActivos;
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
          if (!_cargando) ...[
            // Botón filtros con badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: _filtrosVisible ? 'Ocultar filtros' : 'Mostrar filtros',
                  icon: Icon(_filtrosVisible
                      ? Icons.filter_list_off
                      : Icons.filter_list),
                  onPressed: () =>
                      setState(() => _filtrosVisible = !_filtrosVisible),
                ),
                if (activos > 0)
                  Positioned(
                    right: 6, top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                      child: Text('$activos',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onError)),
                    ),
                  ),
              ],
            ),
            _exportando
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : IconButton(
                    tooltip: 'Exportar a Excel',
                    icon: const Icon(Icons.download_outlined),
                    onPressed: _exportarExcel,
                  ),
            IconButton(
              tooltip: 'Recargar',
              icon: const Icon(Icons.refresh),
              onPressed: _cargar,
            ),
          ],
        ],
      ),
      body: _cargando
          ? _vistaCargando()
          : _errorCarga != null
              ? _vistaError()
              : Column(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child: _filtrosVisible
                      ? _panelFiltros()
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _tabResumen(),
                      _tabAgrupado(
                          _agrupar(_filtradas, (p) => p.nombreAseg ?? 'Sin aseguradora'),
                          'Aseguradora', 'aseg'),
                      _tabAgrupado(
                          _agrupar(_filtradas, (p) => p.nombreRamo ?? 'Sin ramo'),
                          'Ramo', 'ramo'),
                      _tabAgrupado(
                          _agrupar(_filtradas, (p) => p.nombreAsesor ?? 'Sin asesor'),
                          'Asesor', 'asesor'),
                      _tabVencimientos(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ── Panel filtros ─────────────────────────────────────────────────────────

  Widget _panelFiltros() {
    final cs = Theme.of(context).colorScheme;
    final nFil = _filtradas.length;
    final nTot = _polizas.length;

    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Fila 1: dropdowns ──────────────────────────────────────────
          Wrap(spacing: 10, runSpacing: 8, children: [
            _filtroAuto(
              label: 'Aseguradora',
              value: _filtroAseg,
              opciones: _listaAseg,
              onChanged: (v) => setState(() => _filtroAseg = v),
            ),
            _filtroAuto(
              label: 'Ramo',
              value: _filtroRamo,
              opciones: _listaRamos,
              onChanged: (v) => setState(() => _filtroRamo = v),
            ),
            _filtroAuto(
              label: 'Producto',
              value: _filtroProd,
              opciones: _listaProductos,
              onChanged: (v) => setState(() => _filtroProd = v),
            ),
            _filtroAuto(
              label: 'Asesor',
              value: _filtroAsesor,
              opciones: _listaAsesores,
              onChanged: (v) => setState(() => _filtroAsesor = v),
            ),
          ]),
          const SizedBox(height: 8),

          // ── Fila 2: fechas ─────────────────────────────────────────────
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _btnFecha(
              label: 'F. Vencimiento',
              desde: _filtroFfinDesde,
              hasta: _filtroFfinHasta,
              onTap: _seleccionarFfin,
              onClear: () => setState(() {
                _filtroFfinDesde = _filtroFfinHasta = null;
              }),
            ),
            // Presets vencimiento
            _presetChip('Próx. 30d',  () => _presetFfin(0, 30)),
            _presetChip('Próx. 90d',  () => _presetFfin(0, 90)),
            _presetChip('Próx. 180d', () => _presetFfin(0, 180)),
            const SizedBox(width: 8),
            _btnFecha(
              label: 'F. Registro',
              desde: _filtroFregDesde,
              hasta: _filtroFregHasta,
              onTap: _seleccionarFreg,
              onClear: () => setState(() {
                _filtroFregDesde = _filtroFregHasta = null;
              }),
            ),
            // Presets registro
            _presetChip('Este mes', _presetFregMes),
            _presetChip('Este año', _presetFregAnio),
            const SizedBox(width: 8),
            _btnFecha(
              label: 'F. Expedición',
              desde: _filtroFexpDesde,
              hasta: _filtroFexpHasta,
              onTap: _seleccionarFexp,
              onClear: () => setState(() {
                _filtroFexpDesde = _filtroFexpHasta = null;
              }),
            ),
            _presetChip('Exp. este mes', _presetFexpMes),
            _presetChip('Exp. este año', _presetFexpAnio),
          ]),
          const SizedBox(height: 8),

          // ── Fila 3: estado + contador + limpiar ────────────────────────
          Row(
            children: [
              _chipEstado(label: 'Todas',     valor: 0),
              const SizedBox(width: 6),
              _chipEstado(label: 'Vigentes',  valor: 1),
              const SizedBox(width: 6),
              _chipEstado(label: 'Vencidas',  valor: 2),
              const SizedBox(width: 6),
              _chipEstado(label: 'Sin fecha', valor: 3),
              const Spacer(),
              Text(
                '$nFil de $nTot pólizas',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
              if (_filtrosActivos > 0) ...[
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: _limpiarFiltros,
                  icon: const Icon(Icons.clear, size: 14),
                  label: const Text('Limpiar', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.error,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Autocomplete con búsqueda por texto
  Widget _filtroAuto({
    required String label,
    required String? value,
    required List<String> opciones,
    required ValueChanged<String?> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 210,
      child: Autocomplete<String>(
        // ObjectKey fuerza reinicio cuando el valor cambia externamente (limpiar filtros)
        key: ObjectKey(value),
        initialValue: TextEditingValue(text: value ?? ''),
        optionsBuilder: (TextEditingValue tv) {
          final q = tv.text.toLowerCase().trim();
          if (q.isEmpty) return opciones;
          return opciones.where((o) => o.toLowerCase().contains(q));
        },
        optionsViewBuilder: (ctx, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260, maxWidth: 280),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final o = options.elementAt(i);
                  final q = value == o; // ya seleccionado
                  return ListTile(
                    dense: true,
                    selected: q,
                    title: Text(o, style: const TextStyle(fontSize: 13)),
                    onTap: () => onSelected(o),
                  );
                },
              ),
            ),
          ),
        ),
        onSelected: (sel) => setState(() => onChanged(sel)),
        fieldViewBuilder: (ctx, ctrl, focusNode, _) => TextFormField(
          controller: ctrl,
          focusNode: focusNode,
          style: const TextStyle(fontSize: 13),
          onChanged: (t) {
            // Si el usuario borra el campo manualmente, limpia el filtro
            if (t.isEmpty && value != null) setState(() => onChanged(null));
          },
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: cs.surface,
            prefixIcon: const Icon(Icons.search, size: 16),
            suffixIcon: value != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      ctrl.clear();
                      setState(() => onChanged(null));
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }

  // Botón de rango de fecha
  Widget _btnFecha({
    required String label,
    required DateTime? desde,
    required DateTime? hasta,
    required Future<void> Function() onTap,
    required VoidCallback onClear,
  }) {
    final cs = Theme.of(context).colorScheme;
    final hasDate = desde != null || hasta != null;
    final rangeText = hasDate
        ? '${desde != null ? _df.format(desde) : '—'} → ${hasta != null ? _df.format(hasta) : '—'}'
        : 'Cualquier fecha';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hasDate ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasDate
                ? cs.primary.withOpacity(0.5)
                : cs.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.date_range_outlined,
                size: 15,
                color: hasDate ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: hasDate ? cs.primary : cs.onSurfaceVariant)),
                Text(rangeText,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            hasDate ? FontWeight.bold : FontWeight.normal,
                        color: hasDate ? cs.onPrimaryContainer : cs.onSurface)),
              ],
            ),
            if (hasDate) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClear,
                child:
                    Icon(Icons.close, size: 14, color: cs.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Chip preset de fecha
  Widget _presetChip(String label, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: cs.outline.withOpacity(0.4)),
      onPressed: onTap,
    );
  }

  // Chip de estado
  Widget _chipEstado({required String label, required int valor}) {
    final cs = Theme.of(context).colorScheme;
    final activo = _filtroEstado == valor;
    return GestureDetector(
      onTap: () => setState(() => _filtroEstado = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: activo ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                color: activo ? cs.onPrimary : cs.onSurface)),
      ),
    );
  }

  // ── Error de carga ────────────────────────────────────────────────────────

  Widget _vistaError() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text(
              _errorCarga!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cargando ──────────────────────────────────────────────────────────────

  Widget _vistaCargando() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        // Barra de progreso indeterminada en todo el ancho
        LinearProgressIndicator(
          backgroundColor: cs.surfaceContainerHighest,
          color: cs.primary,
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ícono pulsante
                    const _IconoCargando(),
                    const SizedBox(height: 32),

                    // Contador grande
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _cargados == 0
                          ? Text(
                              'Conectando...',
                              key: const ValueKey('conectando'),
                              style: tt.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary),
                            )
                          : Text(
                              _nf.format(_cargados),
                              key: ValueKey(_cargados),
                              style: tt.displaySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary),
                            ),
                    ),
                    if (_cargados > 0) ...[
                      const SizedBox(height: 4),
                      Text('pólizas cargadas',
                          style: tt.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 24),

                    // Mensaje
                    Text(
                      'Cargando el historial completo de pólizas.',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Esto puede tardar unos segundos.\nNo cierres la aplicación.',
                      textAlign: TextAlign.center,
                      style: tt.bodySmall?.copyWith(color: cs.outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Tab Resumen ───────────────────────────────────────────────────────────

  Widget _tabResumen() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fil = _filtradas;
    final total = fil.length;
    final sinFfin = _sinFfin.length;
    final vigentes = _vigentes;
    final vencidas = _vencidas;
    final pv30 = _porVencer(0, 30);
    final pv60 = _porVencer(31, 60);
    final pv90 = _porVencer(61, 90);
    final topAseg = _agrupar(fil, (p) => p.nombreAseg ?? 'Sin aseguradora').values.take(5).toList();
    final topRamo = _agrupar(fil, (p) => p.nombreRamo ?? 'Sin ramo').values.take(5).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Resumen general',
                        style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    Text(
                      'Datos al ${_df.format(_hoy)} · ${_nf.format(total)} pólizas con fecha'
                      '${sinFfin > 0 ? ' · ${_nf.format(sinFfin)} sin fecha' : ''}'
                      '${_filtrosActivos > 0 ? ' (filtradas de ${_nf.format(_polizas.length)})' : ''}',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                )),
              ]),
              const SizedBox(height: 20),

              // KPIs clicables
              Wrap(spacing: 12, runSpacing: 12, children: [
                _kpi('Total pólizas', _nf.format(total),
                    Icons.receipt_long_outlined, cs.primary),
                _kpi('Vigentes', _nf.format(vigentes.length),
                    Icons.check_circle_outline, Colors.green.shade600,
                    onTap: () {
                      setState(() => _filtroEstado = 1);
                      if (!_filtrosVisible) setState(() => _filtrosVisible = true);
                    }),
                _kpi('Vencidas', _nf.format(vencidas.length),
                    Icons.cancel_outlined, Colors.red.shade600,
                    onTap: () {
                      setState(() => _filtroEstado = 2);
                      _tabCtrl.animateTo(_iVenc);
                    }),
                _kpi('Prima total', _nf.format(_primaTotal),
                    Icons.attach_money, cs.secondary),
                if (sinFfin > 0)
                  _kpi('Sin fecha venc.', _nf.format(sinFfin),
                      Icons.event_busy_outlined, Colors.blueGrey.shade400,
                      onTap: () => _tabCtrl.animateTo(_iVenc)),
              ]),
              const SizedBox(height: 24),

              Text('Vencimientos próximos',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _kpi('0 – 30 días', _nf.format(pv30.length),
                    Icons.warning_amber_outlined, Colors.red.shade600,
                    onTap: () {
                      _presetFfin(0, 30);
                      _tabCtrl.animateTo(_iVenc);
                    }),
                _kpi('31 – 60 días', _nf.format(pv60.length),
                    Icons.access_time_outlined, Colors.orange.shade700,
                    onTap: () {
                      _presetFfin(31, 60);
                      _tabCtrl.animateTo(_iVenc);
                    }),
                _kpi('61 – 90 días', _nf.format(pv90.length),
                    Icons.event_outlined, Colors.amber.shade700,
                    onTap: () {
                      _presetFfin(61, 90);
                      _tabCtrl.animateTo(_iVenc);
                    }),
              ]),
              const SizedBox(height: 28),

              // Top aseguradoras — clic filtra y va al tab
              Row(children: [
                Text('Top 5 aseguradoras',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text('(toca para filtrar)',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              ]),
              const SizedBox(height: 10),
              ...topAseg.map((g) => _miniBar(
                g.nombre, g.cantidad, total, cs.primary,
                onTap: () {
                  setState(() => _filtroAseg = g.nombre);
                  _tabCtrl.animateTo(_iAseg);
                },
              )),
              const SizedBox(height: 28),

              Row(children: [
                Text('Top 5 ramos',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text('(toca para filtrar)',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              ]),
              const SizedBox(height: 10),
              ...topRamo.map((g) => _miniBar(
                g.nombre, g.cantidad, total, cs.tertiary,
                onTap: () {
                  setState(() => _filtroRamo = g.nombre);
                  _tabCtrl.animateTo(_iRamo);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kpi(String titulo, String valor, IconData icono, Color color,
      {VoidCallback? onTap}) {
    final isClickable = onTap != null;
    return SizedBox(
      width: 200,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icono, color: color, size: 22),
                if (isClickable) ...[
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 16,
                      color: color.withOpacity(0.5)),
                ],
              ]),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(valor,
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              ),
              const SizedBox(height: 4),
              Text(titulo,
                  style: const TextStyle(fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _miniBar(String nombre, int cantidad, int total, Color color,
      {VoidCallback? onTap}) {
    final pct = total == 0 ? 0.0 : (cantidad / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
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
            if (onTap != null)
              Icon(Icons.chevron_right, size: 14, color: color.withOpacity(0.5)),
          ]),
        ),
      ),
    );
  }

  // ── Tab Agrupado ──────────────────────────────────────────────────────────

  Widget _tabAgrupado(Map<String, _Grupo> grupos, String colNombre, String filterKey) {
    final cs = Theme.of(context).colorScheme;
    if (grupos.isEmpty) return const Center(child: Text('Sin datos'));

    final maxRef = _sortByPrima
        ? grupos.values.first.prima
        : grupos.values.first.cantidad.toDouble();
    final total = _filtradas.length;
    final primaTotal = _primaTotal;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Encabezado con toggle de orden
        Row(children: [
          SizedBox(width: 200,
              child: Text(colNombre,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          Expanded(
            child: Row(children: [
              const Text('Cant.',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _sortByPrima = !_sortByPrima),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.swap_vert, size: 13, color: cs.primary),
                    const SizedBox(width: 3),
                    Text(
                      _sortByPrima ? 'Por prima' : 'Por cant.',
                      style: TextStyle(fontSize: 10, color: cs.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
          SizedBox(width: 175,
              child: Text('Prima total',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          SizedBox(width: 55,
              child: Text('% total',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
        ]),
        const Divider(height: 8),

        // Filas clicables
        ...grupos.values.map((g) {
          final ref = _sortByPrima ? g.prima : g.cantidad.toDouble();
          final pct = maxRef == 0 ? 0.0 : (ref / maxRef).clamp(0.0, 1.0);
          final pctTotal = total == 0 ? 0.0 : g.cantidad / total * 100;
          final pctPrima = primaTotal == 0 ? 0.0 : g.prima / primaTotal * 100;

          // Filtro activo para esta fila
          final esActivo = (filterKey == 'aseg' && _filtroAseg == g.nombre) ||
              (filterKey == 'ramo' && _filtroRamo == g.nombre) ||
              (filterKey == 'asesor' && _filtroAsesor == g.nombre);

          return Material(
            color: esActivo
                ? cs.primaryContainer.withOpacity(0.4)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                if (esActivo) {
                  // Quitar filtro si ya estaba activo
                  setState(() {
                    if (filterKey == 'aseg') _filtroAseg = null;
                    if (filterKey == 'ramo') _filtroRamo = null;
                    if (filterKey == 'asesor') _filtroAsesor = null;
                  });
                } else {
                  _filtrarPor(filterKey, g.nombre);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  SizedBox(
                    width: 200,
                    child: Row(children: [
                      if (esActivo)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.filter_alt, size: 13, color: cs.primary),
                        ),
                      Expanded(
                        child: Text(g.nombre,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: esActivo
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: LayoutBuilder(builder: (_, c) => Row(children: [
                      SizedBox(
                        width: c.maxWidth * 0.65,
                        height: 18,
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
                              color: cs.primary.withOpacity(esActivo ? 0.75 : 0.45),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _sortByPrima
                            ? '${pctPrima.toStringAsFixed(1)}%'
                            : '${g.cantidad}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ])),
                  ),
                  SizedBox(
                    width: 175,
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
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Tab Vencimientos ──────────────────────────────────────────────────────

  Widget _tabVencimientos() {
    final cs = Theme.of(context).colorScheme;
    final secciones = [
      ('Vencen en 0 – 30 días',      _porVencer(0, 30),  Colors.red.shade600,    Icons.warning_amber_outlined),
      ('Vencen en 31 – 60 días',     _porVencer(31, 60), Colors.orange.shade700,  Icons.access_time_outlined),
      ('Vencen en 61 – 90 días',     _porVencer(61, 90), Colors.amber.shade700,   Icons.event_outlined),
      ('Ya vencidas (últimas 100)', _vencidas.take(100).toList(), Colors.grey.shade500, Icons.cancel_outlined),
      ('Sin fecha de vencimiento',  _sinFfin, Colors.blueGrey.shade400, Icons.event_busy_outlined),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: secciones.expand<Widget>((rec) {
        final (titulo, lista, color, icono) = rec;
        if (lista.isEmpty) return const [];

        final primaSeccion = lista.fold(0.0, (s, p) => s + p.primaPoliza);

        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
            child: Row(children: [
              Icon(icono, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text('$titulo  (${lista.length})',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13, color: color)),
              ),
              Text('Prima: ${_nf.format(primaSeccion)}',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ]),
          ),
          ...lista.map((p) {
            final tieneFfin = p.ffinPoliza != null;
            final dias = tieneFfin ? p.ffinPoliza!.difference(_hoy).inDays : null;
            final prod = p.nombreProd;
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: color.withOpacity(0.25)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _mostrarDetalleVencimiento(context, p, color),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.nroPoliza ?? 'Sin número',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(p.nombreCliente ?? '—',
                            style: const TextStyle(fontSize: 12)),
                        Text(
                          '${p.nombreAseg ?? '—'}  ·  ${p.nombreRamo ?? '—'}',
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                        if (prod != null && prod.isNotEmpty)
                          Text(prod,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.primary,
                                  fontStyle: FontStyle.italic)),
                      ],
                    )),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(
                        tieneFfin ? _df.format(p.ffinPoliza!) : 'Sin fecha',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: color),
                      ),
                      if (dias != null)
                        Text(
                          dias < 0 ? '${-dias} días vencida' : '$dias días',
                          style: TextStyle(fontSize: 11, color: color),
                        ),
                      if ((p.nombreAsesor ?? '').isNotEmpty)
                        Text(p.nombreAsesor!,
                            style: TextStyle(
                                fontSize: 11, color: cs.onSurfaceVariant)),
                      Text(_nf.format(p.primaPoliza),
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                    ]),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
        ];
      }).toList(),
    );
  }

  // Detalle de póliza en vencimientos
  void _mostrarDetalleVencimiento(BuildContext context, Poliza p, Color color) {
    final cs = Theme.of(context).colorScheme;
    final dias = p.ffinPoliza != null ? p.ffinPoliza!.difference(_hoy).inDays : null;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(children: [
                Expanded(
                  child: Text(p.nroPoliza ?? 'Sin número',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (dias != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      dias < 0 ? '${-dias} días vencida' : '$dias días',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: color),
                    ),
                  ),
              ]),
              const Divider(height: 20),
              _detRow('Cliente',      p.nombreCliente),
              _detRowCopiable('Teléfono', p.telCliente),
              _detRow('Aseguradora',  p.nombreAseg),
              _detRow('Ramo',         p.nombreRamo),
              _detRow('Producto',     p.nombreProd),
              _detRow('Bien aseg.',   p.bienAsegurado),
              _detRow('F. Inicio',    p.finiPoliza != null ? _df.format(p.finiPoliza!) : null),
              _detRow('F. Venc.',     p.ffinPoliza != null ? _df.format(p.ffinPoliza!) : null, color: color),
              _detRow('Prima',        _nf.format(p.primaPoliza)),
              _detRow('Asesor',       p.nombreAsesor),
            ],
          ),
        );
      },
    );
  }

  Widget _detRowCopiable(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          iconSize: 16,
          tooltip: 'Copiar',
          icon: Icon(Icons.copy_rounded, color: cs.outline),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label copiado'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ]),
    );
  }

  Widget _detRow(String label, String? value, {Color? color}) {
    final cs = Theme.of(context).colorScheme;
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color)),
        ),
      ]),
    );
  }
}

// ── Datos para generación de Excel en isolate ─────────────────────────────────

class _ExcelParams {
  final List<Poliza> polizas;
  final List<Poliza> porVencer90;
  final DateTime hoy;
  const _ExcelParams({required this.polizas, required this.porVencer90, required this.hoy});
}

Uint8List? _buildExcelBytes(_ExcelParams p) {
  final df  = DateFormat('dd/MM/yyyy');
  final dfh = DateFormat('dd/MM/yyyy HH:mm');

  Map<String, ({int cantidad, double prima})> agrupar(
    List<Poliza> lista, String Function(Poliza) key,
  ) {
    final map = <String, ({int cantidad, double prima})>{};
    for (final pol in lista) {
      final k = key(pol);
      final prev = map[k] ?? (cantidad: 0, prima: 0.0);
      map[k] = (cantidad: prev.cantidad + 1, prima: prev.prima + pol.primaPoliza.toDouble());
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.prima.compareTo(a.value.prima));
    return {for (final e in sorted) e.key: e.value};
  }

  final wb = Excel.createExcel();

  // Hoja 1: Pólizas
  final sh1 = wb['Pólizas'];
  sh1.appendRow([
    TextCellValue('Cód'), TextCellValue('Nro Póliza'),
    TextCellValue('Bien Asegurado'), TextCellValue('Cliente'),
    TextCellValue('Doc. Cliente'), TextCellValue('Aseguradora'),
    TextCellValue('Ramo'), TextCellValue('Producto'),
    TextCellValue('F. Inicio'), TextCellValue('F. Vencimiento'),
    TextCellValue('Prima'), TextCellValue('Valor Póliza'),
    TextCellValue('Valor Asegurado'),
    TextCellValue('F. Expedición'), TextCellValue('Asesor'),
    TextCellValue('F. Registro'), TextCellValue('F. Ult. Mod'), TextCellValue('Usuario'),
  ]);
  for (final pol in p.polizas) {
    sh1.appendRow([
      IntCellValue(pol.id),
      TextCellValue(pol.nroPoliza ?? ''),
      TextCellValue(pol.bienAsegurado ?? ''),
      TextCellValue(pol.nombreCliente ?? ''),
      TextCellValue(pol.docCliente ?? ''),
      TextCellValue(pol.nombreAseg ?? ''),
      TextCellValue(pol.nombreRamo ?? ''),
      TextCellValue(pol.nombreProd ?? ''),
      TextCellValue(pol.finiPoliza != null ? df.format(pol.finiPoliza!) : ''),
      TextCellValue(pol.ffinPoliza != null ? df.format(pol.ffinPoliza!) : ''),
      DoubleCellValue(pol.primaPoliza.toDouble()),
      DoubleCellValue(pol.valorPoliza.toDouble()),
      pol.vlrasegPoliza != null ? DoubleCellValue(pol.vlrasegPoliza!.toDouble()) : TextCellValue(''),
      TextCellValue(pol.fexpPoliza != null ? df.format(pol.fexpPoliza!) : ''),
      TextCellValue(pol.nombreAsesor ?? ''),
      TextCellValue(pol.fcreado != null ? dfh.format(pol.fcreado!.toLocal()) : ''),
      TextCellValue(pol.fultmod != null ? dfh.format(pol.fultmod!.toLocal()) : ''),
      TextCellValue(pol.apodoUsuario ?? ''),
    ]);
  }

  // Hoja 2: Por Aseguradora
  final sh2 = wb['Por Aseguradora'];
  sh2.appendRow([TextCellValue('Aseguradora'), TextCellValue('Pólizas'), TextCellValue('Prima Total')]);
  agrupar(p.polizas, (pol) => pol.nombreAseg ?? 'Sin aseguradora').forEach((nombre, g) {
    sh2.appendRow([TextCellValue(nombre), IntCellValue(g.cantidad), DoubleCellValue(g.prima)]);
  });

  // Hoja 3: Por Ramo
  final sh3 = wb['Por Ramo'];
  sh3.appendRow([TextCellValue('Ramo'), TextCellValue('Pólizas'), TextCellValue('Prima Total')]);
  agrupar(p.polizas, (pol) => pol.nombreRamo ?? 'Sin ramo').forEach((nombre, g) {
    sh3.appendRow([TextCellValue(nombre), IntCellValue(g.cantidad), DoubleCellValue(g.prima)]);
  });

  // Hoja 4: Por Asesor
  final sh4 = wb['Por Asesor'];
  sh4.appendRow([TextCellValue('Asesor'), TextCellValue('Pólizas'), TextCellValue('Prima Total')]);
  agrupar(p.polizas, (pol) => pol.nombreAsesor ?? 'Sin asesor').forEach((nombre, g) {
    sh4.appendRow([TextCellValue(nombre), IntCellValue(g.cantidad), DoubleCellValue(g.prima)]);
  });

  // Hoja 5: Vencimientos 90 días
  final sh5 = wb['Vencimientos 90 días'];
  sh5.appendRow([
    TextCellValue('Cód'), TextCellValue('Nro Póliza'),
    TextCellValue('Cliente'), TextCellValue('Aseguradora'),
    TextCellValue('Ramo'), TextCellValue('Producto'),
    TextCellValue('F. Vencimiento'), TextCellValue('Días restantes'),
    TextCellValue('Prima'), TextCellValue('Asesor'),
  ]);
  for (final pol in p.porVencer90) {
    sh5.appendRow([
      IntCellValue(pol.id),
      TextCellValue(pol.nroPoliza ?? ''),
      TextCellValue(pol.nombreCliente ?? ''),
      TextCellValue(pol.nombreAseg ?? ''),
      TextCellValue(pol.nombreRamo ?? ''),
      TextCellValue(pol.nombreProd ?? ''),
      TextCellValue(df.format(pol.ffinPoliza!)),
      IntCellValue(pol.ffinPoliza!.difference(p.hoy).inDays),
      DoubleCellValue(pol.primaPoliza.toDouble()),
      TextCellValue(pol.nombreAsesor ?? ''),
    ]);
  }

  wb.delete('Sheet1');
  final bytes = wb.encode();
  return bytes == null ? null : Uint8List.fromList(bytes);
}

// ── Ícono animado para la pantalla de carga ───────────────────────────────────

class _IconoCargando extends StatefulWidget {
  const _IconoCargando();

  @override
  State<_IconoCargando> createState() => _IconoCargandoState();
}

class _IconoCargandoState extends State<_IconoCargando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _escala;
  late final Animation<double> _opacidad;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _escala = Tween<double>(begin: 0.88, end: 1.08).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _opacidad = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _opacidad.value,
        child: ScaleTransition(
          scale: _escala,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primaryContainer,
            ),
            child: Icon(
              Icons.shield_outlined,
              size: 52,
              color: cs.primary,
            ),
          ),
        ),
      ),
    );
  }
}
