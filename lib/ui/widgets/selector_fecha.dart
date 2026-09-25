import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _kMeses = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];
const _kDiasSemana = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// Selección de una sola fecha con el calendario compacto de SegurApp.
/// Reemplaza `showDatePicker` en toda la app: ese diálogo nativo de Flutter,
/// en Windows, abre un calendario enorme de un solo mes y obliga a hacer
/// scroll mes a mes para llegar a un año distinto. Acá se ve el año
/// completo (12 meses) de una vez, con botones para cambiar de año.
Future<DateTime?> mostrarSelectorFecha(
  BuildContext context, {
  DateTime? inicial,
  DateTime? primera,
  DateTime? ultima,
  String? titulo,
}) async {
  final r = await showDialog<DateTimeRange>(
    context: context,
    builder: (_) => _DialogoCalendario(
      modoRango: false,
      inicialUnica: inicial,
      primera: primera ?? DateTime(2000),
      ultima: ultima ?? DateTime(2100),
      titulo: titulo ?? 'Selecciona una fecha',
    ),
  );
  return r?.start;
}

/// Selección de un rango de fechas (desde–hasta) con el mismo calendario.
/// Reemplaza `showDateRangePicker`.
Future<DateTimeRange?> mostrarSelectorRangoFecha(
  BuildContext context, {
  DateTimeRange? inicial,
  DateTime? primera,
  DateTime? ultima,
  String? titulo,
}) {
  return showDialog<DateTimeRange>(
    context: context,
    builder: (_) => _DialogoCalendario(
      modoRango: true,
      inicialRango: inicial,
      primera: primera ?? DateTime(2000),
      ultima: ultima ?? DateTime(2100),
      titulo: titulo ?? 'Selecciona un rango de fechas',
    ),
  );
}

class _DialogoCalendario extends StatefulWidget {
  final bool modoRango;
  final DateTime? inicialUnica;
  final DateTimeRange? inicialRango;
  final DateTime primera;
  final DateTime ultima;
  final String titulo;

  const _DialogoCalendario({
    required this.modoRango,
    this.inicialUnica,
    this.inicialRango,
    required this.primera,
    required this.ultima,
    required this.titulo,
  });

  @override
  State<_DialogoCalendario> createState() => _DialogoCalendarioState();
}

class _DialogoCalendarioState extends State<_DialogoCalendario> {
  late int _anio;
  DateTime? _desde;
  DateTime? _hasta;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    if (widget.modoRango) {
      _desde = widget.inicialRango?.start;
      _hasta = widget.inicialRango?.end;
      _anio = (_hasta ?? _desde ?? hoy).year;
    } else {
      _desde = widget.inicialUnica;
      _anio = (_desde ?? hoy).year;
    }
    if (_anio < widget.primera.year) _anio = widget.primera.year;
    if (_anio > widget.ultima.year) _anio = widget.ultima.year;
  }

  bool get _puedeAplicar =>
      widget.modoRango ? (_desde != null && _hasta != null) : _desde != null;

  void _tocarDia(DateTime dia) {
    setState(() {
      if (!widget.modoRango) {
        _desde = dia;
        return;
      }
      if (_desde == null || _hasta != null) {
        _desde = dia;
        _hasta = null;
      } else if (dia.isBefore(_desde!)) {
        _hasta = _desde;
        _desde = dia;
      } else {
        _hasta = dia;
      }
    });
  }

  void _cambiarAnio(int delta) {
    final nuevo = _anio + delta;
    if (nuevo < widget.primera.year || nuevo > widget.ultima.year) return;
    setState(() => _anio = nuevo);
  }

  String _fmt(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final anchoDialogo = (size.width * 0.9).clamp(0, 900).toDouble();
    final altoDialogo = (size.height * 0.92).clamp(0, 880).toDouble();

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: anchoDialogo, maxHeight: altoDialogo),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(widget.titulo,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
              const SizedBox(height: 4),
              Wrap(spacing: 16, runSpacing: 4, children: [
                if (widget.modoRango) ...[
                  _ResumenFecha(label: 'Desde', valor: _fmt(_desde)),
                  _ResumenFecha(label: 'Hasta', valor: _fmt(_hasta)),
                ] else
                  _ResumenFecha(label: 'Fecha', valor: _fmt(_desde)),
              ]),
              const SizedBox(height: 10),
              // Navegación por año — sin scroll mes a mes para llegar lejos.
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed:
                      _anio > widget.primera.year ? () => _cambiarAnio(-1) : null,
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '$_anio',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: cs.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed:
                      _anio < widget.ultima.year ? () => _cambiarAnio(1) : null,
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _anio = DateTime.now().year),
                  child: const Text('Hoy'),
                ),
              ]),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  final columnas = constraints.maxWidth > 620
                      ? 4
                      : (constraints.maxWidth > 420 ? 3 : 2);
                  return GridView.builder(
                    itemCount: 12,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columnas,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.05,
                    ),
                    itemBuilder: (context, i) => _MiniMes(
                      anio: _anio,
                      mes: i + 1,
                      primera: widget.primera,
                      ultima: widget.ultima,
                      desde: _desde,
                      hasta: widget.modoRango ? _hasta : _desde,
                      onTap: _tocarDia,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () => setState(() {
                    _desde = null;
                    _hasta = null;
                  }),
                  child: const Text('Limpiar'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _puedeAplicar
                      ? () => Navigator.pop(
                          context,
                          DateTimeRange(start: _desde!, end: _hasta ?? _desde!))
                      : null,
                  child: const Text('Aplicar'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumenFecha extends StatelessWidget {
  final String label;
  final String valor;
  const _ResumenFecha({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$label: ',
          style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600)),
      Text(valor,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: cs.primary)),
    ]);
  }
}

class _MiniMes extends StatelessWidget {
  final int anio;
  final int mes;
  final DateTime primera;
  final DateTime ultima;
  final DateTime? desde;
  final DateTime? hasta;
  final ValueChanged<DateTime> onTap;

  const _MiniMes({
    required this.anio,
    required this.mes,
    required this.primera,
    required this.ultima,
    required this.desde,
    required this.hasta,
    required this.onTap,
  });

  bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hoy = DateTime.now();
    final primerDia = DateTime(anio, mes, 1);
    final diasEnMes = DateTime(anio, mes + 1, 0).day;
    final offset = primerDia.weekday - 1; // Lunes=1..Domingo=7

    final primeraD = DateTime(primera.year, primera.month, primera.day);
    final ultimaD = DateTime(ultima.year, ultima.month, ultima.day);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: AppTheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(_kMeses[mes - 1],
              style: TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.bold, color: cs.primary)),
          const SizedBox(height: 5),
          Row(
            children: _kDiasSemana
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: offset + diasEnMes,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
              itemBuilder: (context, i) {
                if (i < offset) return const SizedBox.shrink();
                final dia = DateTime(anio, mes, i - offset + 1);
                final habilitado =
                    !dia.isBefore(primeraD) && !dia.isAfter(ultimaD);
                final esHoy = _mismoDia(dia, hoy);
                final esDesde = desde != null && _mismoDia(dia, desde!);
                final esHasta = hasta != null && _mismoDia(dia, hasta!);
                final enRango = desde != null &&
                    hasta != null &&
                    dia.isAfter(desde!) &&
                    dia.isBefore(hasta!);

                Color? bg;
                Color fg = cs.onSurface;
                if (esDesde || esHasta) {
                  bg = cs.primary;
                  fg = cs.onPrimary;
                } else if (enRango) {
                  bg = cs.primaryContainer;
                  fg = cs.onPrimaryContainer;
                }

                return Padding(
                  padding: const EdgeInsets.all(1.5),
                  child: InkWell(
                    onTap: habilitado ? () => onTap(dia) : null,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: bg,
                        shape: BoxShape.circle,
                        border: esHoy && bg == null
                            ? Border.all(color: cs.primary, width: 1)
                            : null,
                      ),
                      child: Text(
                        '${dia.day}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: habilitado
                              ? fg
                              : cs.onSurfaceVariant.withOpacity(0.35),
                          fontWeight:
                              (esDesde || esHasta) ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
