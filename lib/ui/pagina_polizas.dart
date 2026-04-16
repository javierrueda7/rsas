import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final df = DateFormat('dd/MM/yyyy');
  final nf = NumberFormat.decimalPattern('es_CO');

  bool cargando = false;
  List<Poliza> polizas = [];
  int _cargados = 0;            // progreso de carga total
  bool _datosCompletos = false; // true cuando ya se cargaron todos
  String? _errorCarga;          // mensaje de error persistente para mostrar retry

  // Columnas:
  // 0  Cód.          1  Nro Póliza    2  Bien Asegurado
  // 3  Cliente        4  Aseguradora   5  Ramo/Prod
  // 6  F. Ini.        7  F. Venc.      8  Prima
  // 9  Valor         10  F. Exp.      11  Asesor
  // 12 F. Registro   13  Usuario      14  (acciones)
  int _sortColumnIndex = 0;
  bool _sortAscending = false;

  Timer? debounce;

  final ScrollController _verticalCtrl = ScrollController();
  final ScrollController _horizontalCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    ctrlBuscar.dispose();
    debounce?.cancel();
    _verticalCtrl.dispose();
    _horizontalCtrl.dispose();
    super.dispose();
  }

  /// Carga inicial rápida: 500 más recientes.
  Future<void> _cargar() async {
    final busqueda = ctrlBuscar.text.trim();
    if (cargando) return;
    if (mounted) setState(() { cargando = true; _datosCompletos = false; _errorCarga = null; });
    try {
      final data = await repo.listar(busqueda: busqueda, limite: 500)
          .timeout(const Duration(seconds: 30));
      if (mounted) {
        setState(() {
          polizas = data;
          _aplicarOrden();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorCarga = _mensajeError(e));
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  /// Carga completa paginada: trae todos los registros de a 1.000.
  Future<void> _cargarTodo() async {
    if (cargando) return;
    if (mounted) setState(() { cargando = true; _cargados = 0; _errorCarga = null; });
    final busqueda = ctrlBuscar.text.trim();
    try {
      final data = await repo.listarTodos(
        busqueda: busqueda,
        onProgreso: (n) {
          if (mounted) setState(() => _cargados = n);
        },
      ).timeout(const Duration(minutes: 3));
      if (mounted) {
        setState(() {
          polizas = data;
          _datosCompletos = true;
          _aplicarOrden();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorCarga = _mensajeError(e));
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  String _mensajeError(Object e) {
    final s = e.toString();
    if (e is TimeoutException ||
        s.contains('57014') ||
        s.contains('timeout') ||
        s.contains('canceling') ||
        s.contains('TimeoutException')) {
      return 'La consulta tardó demasiado.\nVerifica tu conexión e intenta de nuevo.';
    }
    if (s.contains('network') ||
        s.contains('connection') ||
        s.contains('SocketException') ||
        s.contains('Failed host')) {
      return 'Sin conexión a internet.\nVerifica tu red e intenta de nuevo.';
    }
    return 'Error al cargar pólizas.\nIntenta de nuevo.';
  }

  void _aplicarOrden() {
    polizas.sort((a, b) {
      final int cmp;
      switch (_sortColumnIndex) {
        case 0:
          cmp = a.id.compareTo(b.id);
        case 1:
          cmp = (a.nroPoliza ?? '').compareTo(b.nroPoliza ?? '');
        case 2:
          cmp = (a.bienAsegurado ?? '').toLowerCase().compareTo(
                (b.bienAsegurado ?? '').toLowerCase(),
              );
        case 3:
          cmp = (a.nombreCliente ?? '').toLowerCase().compareTo(
                (b.nombreCliente ?? '').toLowerCase(),
              );
        case 4:
          cmp = (a.nombreAseg ?? '').toLowerCase().compareTo(
                (b.nombreAseg ?? '').toLowerCase(),
              );
        case 5:
          cmp = (a.nombreRamo ?? '').toLowerCase().compareTo(
                (b.nombreRamo ?? '').toLowerCase(),
              );
        case 6:
          final da = a.finiPoliza ?? DateTime(9999);
          final db = b.finiPoliza ?? DateTime(9999);
          cmp = da.compareTo(db);
        case 7:
          final da = a.ffinPoliza ?? DateTime(9999);
          final db = b.ffinPoliza ?? DateTime(9999);
          cmp = da.compareTo(db);
        case 8:
          cmp = a.primaPoliza.compareTo(b.primaPoliza);
        case 9:
          cmp = a.valorPoliza.compareTo(b.valorPoliza);
        case 10:
          final da = a.fexpPoliza ?? DateTime(9999);
          final db = b.fexpPoliza ?? DateTime(9999);
          cmp = da.compareTo(db);
        case 11:
          cmp = (a.nombreAsesor ?? '').toLowerCase().compareTo(
                (b.nombreAsesor ?? '').toLowerCase(),
              );
        case 12:
          final da = a.fcreado ?? DateTime(9999);
          final db = b.fcreado ?? DateTime(9999);
          cmp = da.compareTo(db);
        case 13:
          cmp = (a.apodoUsuario ?? '').toLowerCase().compareTo(
                (b.apodoUsuario ?? '').toLowerCase(),
              );
        default:
          cmp = a.id.compareTo(b.id);
      }
      return _sortAscending ? cmp : -cmp;
    });
  }

  void _sort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _aplicarOrden();
    });
  }

  void _onBuscarChanged(String _) {
    debounce?.cancel();
    debounce = Timer(
      const Duration(milliseconds: 400),
      () => _cargar(),
    );
  }

  Widget _vistaError() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 64, color: cs.error.withOpacity(0.7)),
            const SizedBox(height: 20),
            Text(
              _errorCarga!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant, height: 1.5),
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

  String _fmtFecha(DateTime? fecha) {
    if (fecha == null) return '—';
    return df.format(fecha);
  }

  String _fmtFechaHora(DateTime? fecha) {
    if (fecha == null) return '—';
    return DateFormat('dd/MM/yyyy HH:mm').format(fecha.toLocal());
  }

  String _fmtNum(num? valor) {
    if (valor == null || valor == 0) return '—';
    return nf.format(valor);
  }

  Future<void> _nuevaPoliza() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PaginaFormularioPolizas()),
    );
    _datosCompletos ? _cargarTodo() : _cargar();
  }

  void _abrirEditar(Poliza p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaginaFormularioPolizas(poliza: p),
      ),
    );
    _datosCompletos ? _cargarTodo() : _cargar();
  }

  Widget _vistaMovil(List<Poliza> data) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
      itemCount: data.length,
      itemBuilder: (_, i) {
        final p = data[i];

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _abrirEditar(p),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.nroPoliza ?? 'Sin número',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        'Cód. ${p.id}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.nombreCliente ?? '—',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if ((p.docCliente ?? '').isNotEmpty)
                    Text(
                      p.docCliente!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  if ((p.bienAsegurado ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 12,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            p.bienAsegurado!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if ((p.nombreAseg ?? '').isNotEmpty)
                        _etiqueta(p.nombreAseg!),
                      if ((p.nombreRamo ?? '').isNotEmpty)
                        _etiqueta(p.nombreRamo!),
                      if ((p.nombreAsesor ?? '').isNotEmpty)
                        _etiqueta(p.nombreAsesor!, icono: Icons.person_outline),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Fechas
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      _infoFecha(Icons.edit_calendar_outlined, 'Exp.', p.fexpPoliza),
                      _infoFecha(Icons.play_circle_outline, 'Ini.', p.finiPoliza),
                      _infoFecha(Icons.event_outlined, 'Vence', p.ffinPoliza),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Prima: ${_fmtNum(p.primaPoliza)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if ((p.apodoUsuario ?? '').isNotEmpty)
                        _etiqueta(p.apodoUsuario!, icono: Icons.person_pin_outlined),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _infoFecha(IconData icono, String label, DateTime? fecha) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 13, color: cs.outline),
        const SizedBox(width: 3),
        Text(
          '$label: ${_fmtFecha(fecha)}',
          style: TextStyle(fontSize: 12, color: cs.outline),
        ),
      ],
    );
  }

  Widget _etiqueta(String texto, {IconData? icono}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 11, color: cs.onSurfaceVariant),
            const SizedBox(width: 3),
          ],
          Text(
            texto,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // Anchos columnas escritorio
  static const _wCod = 60.0;
  static const _wNro = 180.0;
  static const _wBien = 160.0;
  static const _wCliente = 190.0;
  static const _wAseg = 150.0;
  static const _wRamo = 140.0;
  static const _wAsesor = 100.0;
  static const _wFecha = 80.0;
  static const _wPrima = 80.0;
  static const _wValor = 80.0;
  static const _wFCreado = 100.0;
  static const _wUsuario = 45.0;
  static const _wAcciones = 60.0;
  static const _totalAncho = _wCod + _wNro + _wBien + _wCliente + _wAseg +
      _wRamo + _wAsesor + _wFecha * 3 + _wPrima + _wValor + 12 + _wFCreado + _wUsuario + _wAcciones;

  Widget _encabezadoPolizas() {
    final cs = Theme.of(context).colorScheme;
    Widget col(String label, double w, int idx, {bool num = false}) {
      final activo = _sortColumnIndex == idx;
      return InkWell(
        onTap: () => _sort(idx, _sortColumnIndex != idx || !_sortAscending),
        child: SizedBox(
          width: w,
          child: Row(
            mainAxisAlignment: num ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: activo ? cs.primary : null)),
              if (activo) Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 13, color: cs.primary),
            ],
          ),
        ),
      );
    }
    return Container(
      color: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(children: [
        col('Cód.', _wCod, 0, num: true),
        col('Nro Póliza', _wNro, 1),
        col('Bien Asegurado', _wBien, 2),
        col('Cliente', _wCliente, 3),
        col('Aseguradora', _wAseg, 4),
        col('Ramo / Producto', _wRamo, 5),
        col('F. Ini.', _wFecha, 6),
        col('F. Venc.', _wFecha, 7),
        col('Prima', _wPrima, 8, num: true),
        col('Valor', _wValor, 9, num: true),
        const SizedBox(width: 12),
        col('F. Exp.', _wFecha, 10),
        col('Asesor', _wAsesor, 11),
        col('F. Registro', _wFCreado, 12),
        col('Usuario', _wUsuario, 10),
        const SizedBox(width: _wAcciones),
      ]),
    );
  }

  Widget _filaPoliza(Poliza p) {
    return InkWell(
      onTap: () => _abrirEditar(p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(width: _wCod, child: Text(p.id.toString(), style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
          const SizedBox(width: 8),
          SizedBox(width: _wNro - 8, child: Text(p.nroPoliza ?? '—', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
          SizedBox(width: _wBien, child: Text(p.bienAsegurado ?? '—', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
          SizedBox(
            width: _wCliente,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(p.nombreCliente ?? '—', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              if ((p.docCliente ?? '').isNotEmpty)
                Text(p.docCliente!, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
            ]),
          ),
          SizedBox(width: _wAseg, child: Text(p.nombreAseg ?? '—', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
          SizedBox(
            width: _wRamo,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(p.nombreRamo ?? '—', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              if ((p.nombreProd ?? '').isNotEmpty)
                Text(p.nombreProd!, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
            ]),
          ),
          SizedBox(width: _wFecha, child: Text(_fmtFecha(p.finiPoliza), style: const TextStyle(fontSize: 12))),
          SizedBox(width: _wFecha, child: Text(_fmtFecha(p.ffinPoliza), style: const TextStyle(fontSize: 12))),
          SizedBox(width: _wPrima, child: Text(_fmtNum(p.primaPoliza), style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
          SizedBox(width: _wValor, child: Text(_fmtNum(p.valorPoliza), style: const TextStyle(fontSize: 12), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 12),
          SizedBox(width: _wFecha, child: Text(_fmtFecha(p.fexpPoliza), style: const TextStyle(fontSize: 12))),
          SizedBox(width: _wAsesor, child: Text(p.nombreAsesor ?? '—', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
          SizedBox(width: _wFCreado, child: Text(_fmtFechaHora(p.fcreado), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
          SizedBox(width: _wUsuario, child: Text(p.apodoUsuario ?? '—', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
          SizedBox(width: _wAcciones, child: IconButton(tooltip: 'Editar', icon: const Icon(Icons.edit, size: 18), onPressed: () => _abrirEditar(p))),
        ]),
      ),
    );
  }

  Widget _vistaEscritorio(List<Poliza> data) {
    return Scrollbar(
      controller: _horizontalCtrl,
      thumbVisibility: true,
      notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
      child: SingleChildScrollView(
        controller: _horizontalCtrl,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _totalAncho + 16,
          child: Column(children: [
            _encabezadoPolizas(),
            Expanded(
              child: Scrollbar(
                controller: _verticalCtrl,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _verticalCtrl,
                  itemCount: data.length,
                  itemExtent: 48,
                  itemBuilder: (_, i) => _filaPoliza(data[i]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, alt: true): _nuevaPoliza,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
      appBar: AppBar(
        title: const Text('Pólizas'),
        actions: [
          IconButton(
            tooltip: 'Nueva póliza (Alt+N)',
            icon: const Icon(Icons.add),
            onPressed: _nuevaPoliza,
          ),
          IconButton(
            tooltip: 'Recargar lista',
            icon: const Icon(Icons.refresh),
            onPressed: cargando ? null : () => _datosCompletos ? _cargarTodo() : _cargar(),
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: ctrlBuscar,
              onChanged: _onBuscarChanged,
              decoration: const InputDecoration(
                labelText:
                    'Buscar por póliza, cliente, documento, aseguradora, ramo, asesor…',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(
              children: [
                Icon(Icons.keyboard_outlined, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(
                  'Presiona Alt+N para crear una nueva póliza',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (cargando) ...[
            const LinearProgressIndicator(),
            if (_cargados > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  'Cargando... ${_cargados.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} pólizas',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
          if (!cargando && !_datosCompletos && polizas.isNotEmpty)
            MaterialBanner(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              content: Text(
                'Mostrando las ${polizas.length} pólizas más recientes.',
                style: const TextStyle(fontSize: 13),
              ),
              leading: const Icon(Icons.info_outline, size: 20),
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              actions: [
                TextButton.icon(
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Cargar todas'),
                  onPressed: _cargarTodo,
                ),
              ],
            ),
          Expanded(
            child: cargando && polizas.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _errorCarga != null && polizas.isEmpty
                    ? _vistaError()
                    : polizas.isEmpty
                        ? const Center(child: Text('No se encontraron pólizas'))
                        : LayoutBuilder(
                        builder: (context, constraints) =>
                            constraints.maxWidth < 600
                                ? _vistaMovil(polizas)
                                : _vistaEscritorio(polizas),
                      ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}
