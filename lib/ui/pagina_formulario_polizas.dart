// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter, TextEditingValue;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../datos/repositorio_catalogos.dart';
import '../datos/repositorio_polizas.dart';
import '../datos/catalogos.dart';
import '../datos/poliza.dart';
import '../datos/sesion.dart';
import '../utils/formatters.dart';
import 'catalogos/form_cliente.dart';
import 'widgets/buscador_dropdown.dart';

extension FirstWhereOrNullExt<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

class FormaPagoLite {
  final int id;
  final String nombre;

  FormaPagoLite({
    required this.id,
    required this.nombre,
  });

  factory FormaPagoLite.fromMap(Map<String, dynamic> m) => FormaPagoLite(
        id: (m['id'] as num).toInt(),
        nombre: (m['nombre_forma_pago'] ?? '') as String,
      );
}

class EstadoPolizaLite {
  final String id;
  final String nombre;

  EstadoPolizaLite({
    required this.id,
    required this.nombre,
  });

  factory EstadoPolizaLite.fromMap(Map<String, dynamic> m) => EstadoPolizaLite(
        id: (m['id'] ?? '').toString(),
        nombre: (m['nombre_estado'] ?? '') as String,
      );
}

class IntermediarioLite {
  final int id;
  final String nombre;

  IntermediarioLite({
    required this.id,
    required this.nombre,
  });

  factory IntermediarioLite.fromMap(Map<String, dynamic> m) =>
      IntermediarioLite(
        id: (m['id'] as num).toInt(),
        nombre: (m['nombre_interm'] ?? '') as String,
      );
}

/// Formatea números al estilo colombiano (1.234.567,89) mientras el usuario escribe.
class _ColMoneyInputFormatter extends TextInputFormatter {
  final int maxDec;
  const _ColMoneyInputFormatter({this.maxDec = 2});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text;
    // Solo dígitos, coma y signo negativo
    final soloDigitos = raw.replaceAll(RegExp(r'[^0-9,\-]'), '');
    if (soloDigitos.isEmpty) return newValue.copyWith(text: '');

    // Separar parte entera y decimal (coma como separador)
    final partes = soloDigitos.split(',');
    final entera = partes[0].replaceAll(RegExp(r'[^0-9\-]'), '');
    final decimal = partes.length > 1 ? partes[1].replaceAll(RegExp(r'[^0-9]'), '') : null;

    // Formatear miles con punto
    final enteroNum = int.tryParse(entera.replaceAll('-', '')) ?? 0;
    final negativo = entera.startsWith('-');
    final enteroFmt = _formatMiles(enteroNum);
    final decStr = decimal != null
        ? ',${decimal.substring(0, decimal.length > maxDec ? maxDec : decimal.length)}'
        : '';
    final resultado = '${negativo ? '-' : ''}$enteroFmt$decStr';

    return newValue.copyWith(
      text: resultado,
      selection: TextSelection.collapsed(offset: resultado.length),
    );
  }

  String _formatMiles(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class FormaExpLite {
  final int id;
  final String nombre;

  FormaExpLite({required this.id, required this.nombre});

  factory FormaExpLite.fromMap(Map<String, dynamic> m) => FormaExpLite(
        id: (m['id'] as num).toInt(),
        nombre: (m['nombre_formaexp'] ?? '') as String,
      );
}

class PaginaFormularioPolizas extends StatefulWidget {
  final Poliza? poliza;
  const PaginaFormularioPolizas({super.key, this.poliza});

  @override
  State<PaginaFormularioPolizas> createState() =>
      _PaginaFormularioPolizasState();
}

class _PaginaFormularioPolizasState extends State<PaginaFormularioPolizas> {
  final _formKey = GlobalKey<FormState>();

  final _repoCat = RepositorioCatalogos();
  final _repoPol = RepositorioPolizas();
  final _db = Supabase.instance.client;

  bool _cargando = true;
  bool _guardando = false;

  final _idCtrl = TextEditingController();
  final _nroCtrl = TextEditingController();

  final _fExpCtrl = TextEditingController();
  final _fIniCtrl = TextEditingController();
  final _fFinCtrl = TextEditingController();

  final _bienCtrl = TextEditingController();
  final _vlrAsegCtrl = TextEditingController();
  final _primaCtrl = TextEditingController();
  final _valorPolizaCtrl = TextEditingController();
  final _vlrBaseComCtrl = TextEditingController();
  final _porcComCtrl = TextEditingController();
  final _porcomAgenciaCtrl = TextEditingController();
  final _vlrComCtrl = TextEditingController();
  final _vlrComFijaCtrl = TextEditingController();
  final _porcomAdicCtrl = TextEditingController();
  final _vlrComAdicCtrl = TextEditingController();
  final _comDistribCtrl = TextEditingController();
  final _comAdicDistribCtrl = TextEditingController();
  final _porcomAsesor1Ctrl = TextEditingController();
  final _porcomAsesor2Ctrl = TextEditingController();
  final _porcomAsesor3Ctrl = TextEditingController();
  final _porcomAsesoradCtrl = TextEditingController();
  final _porcomAgenciaadCtrl = TextEditingController();
  final _vlrPrimaPagadaCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  Cliente? cliente;
  Aseguradora? aseguradora;
  Ramo? ramo;
  Producto? producto;

  IntermediarioLite? intermediario;

  Asesor? asesor1;
  Asesor? agencia;
  Asesor? asesor2;
  Asesor? asesor3;
  Asesor? asesorAd;
  Asesor? agenciaAd;

  FormaPagoLite? formaPago;
  EstadoPolizaLite? estadoPoliza;

  DateTime? fExp;
  DateTime? fIni;
  DateTime? fFin;

  List<Cliente> clientes = [];
  List<Asesor> asesores = [];
  List<Aseguradora> aseguradoras = [];
  List<Ramo> ramos = [];
  List<Producto> productos = [];
  List<FormaPagoLite> formasPago = [];
  List<EstadoPolizaLite> estadosPoliza = [];
  List<IntermediarioLite> intermediarios = [];
  List<FormaExpLite> formasExp = [];
  FormaExpLite? formaExp;

  bool get esEdicion => widget.poliza != null;

  @override
  void initState() {
    super.initState();
    _cargar();
    // Rebuild en tiempo real para los valores calculados por asesor
    for (final ctrl in [
      _comDistribCtrl, _comAdicDistribCtrl,
      _porcomAsesor1Ctrl, _porcomAsesor2Ctrl, _porcomAsesor3Ctrl,
      _porcomAsesoradCtrl, _porcomAgenciaCtrl, _porcomAgenciaadCtrl,
    ]) {
      ctrl.addListener(_onComDistribChanged);
    }
  }

  void _onComDistribChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _nroCtrl.dispose();
    _fExpCtrl.dispose();
    _fIniCtrl.dispose();
    _fFinCtrl.dispose();
    _bienCtrl.dispose();
    _vlrAsegCtrl.dispose();
    _primaCtrl.dispose();
    _valorPolizaCtrl.dispose();
    _vlrBaseComCtrl.dispose();
    _porcComCtrl.dispose();
    _porcomAgenciaCtrl.dispose();
    _vlrComCtrl.dispose();
    _vlrComFijaCtrl.dispose();
    _porcomAdicCtrl.dispose();
    _vlrComAdicCtrl.dispose();
    _comDistribCtrl.dispose();
    _comAdicDistribCtrl.dispose();
    _porcomAsesor1Ctrl.dispose();
    _porcomAsesor2Ctrl.dispose();
    _porcomAsesor3Ctrl.dispose();
    _porcomAsesoradCtrl.dispose();
    _porcomAgenciaadCtrl.dispose();
    _vlrPrimaPagadaCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  String _formatearFecha(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";

  String _soloFecha(String v) {
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 2) return digits;
    if (digits.length <= 4) {
      return '${digits.substring(0, 2)}-${digits.substring(2)}';
    }
    return '${digits.substring(0, 2)}-${digits.substring(2, 4)}-${digits.substring(4, 8)}';
  }

  DateTime? _parseFecha(String v) {
    try {
      final p = v.split('-');
      if (p.length != 3) return null;

      final d = int.parse(p[0]);
      final m = int.parse(p[1]);
      final y = int.parse(p[2]);

      if (y < 1900 || y > 2100) return null;

      final dt = DateTime(y, m, d);
      if (dt.day != d || dt.month != m || dt.year != y) return null;

      return dt;
    } catch (_) {
      return null;
    }
  }

  DateTime _addOneYearSafe(DateTime d) {
    final y = d.year + 1;
    final m = d.month;
    final day = d.day;

    final candidate = DateTime(y, m, day);
    if (candidate.month == m) return candidate;

    return DateTime(y, m + 1, 0);
  }

  num? _parseNumero(String s) {
    final limpio = s
        .replaceAll(RegExp(r'[^0-9,.\-]'), '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    if (limpio.trim().isEmpty) return null;
    return num.tryParse(limpio);
  }

  String _fmtMoney(num? n) => n == null ? '' : Fmt.money(n, dec: 2);
  String _fmtNum(num? n) => n == null ? '' : Fmt.numCO(n, dec: 2);

  void _formatearMoney(TextEditingController ctrl) {
    final n = _parseNumero(ctrl.text);
    if (n == null) return;
    ctrl.text = _fmtMoney(n);
  }

  void _formatearNum(TextEditingController ctrl) {
    final n = _parseNumero(ctrl.text);
    if (n == null) return;
    ctrl.text = _fmtNum(n);
  }

  void _aplicarDefaultsDesdeRamo() {
    if (ramo == null) return;
    _recalcularBaseCom();
  }

  void _aplicarDefaultsDesdeProducto() {
    if (producto == null) return;

    if (producto!.porcomProd != null) {
      _porcComCtrl.text = _fmtNum(producto!.porcomProd);
    }

    if (producto!.porcadProd != null) {
      _porcomAdicCtrl.text = _fmtNum(producto!.porcadProd);
    }

    _recalcularComision();
  }

  void _recalcularBaseCom() {
    final prima = _parseNumero(_primaCtrl.text) ?? 0;
    _vlrBaseComCtrl.text = _fmtMoney(prima);
    _recalcularComision();
  }

  void _recalcularComision() {
    final vlrBase = _parseNumero(_vlrBaseComCtrl.text) ?? 0;
    final porc = _parseNumero(_porcComCtrl.text) ?? 0;
    final calculado = vlrBase * (porc / 100);
    _vlrComCtrl.text = _fmtMoney(calculado);
    // Sugerir Com a distrib = Vlr Com + Com Fija (solo si el usuario no lo ha editado)
    final comFija = _parseNumero(_vlrComFijaCtrl.text) ?? 0;
    _comDistribCtrl.text = _fmtMoney(calculado + comFija);
  }

  /// Valor que le corresponde a un participante según Com a distrib y su %.
  num _vlrParticipante(TextEditingController porcCtrl, TextEditingController baseCtrl) {
    final base = _parseNumero(baseCtrl.text) ?? 0;
    final porc = _parseNumero(porcCtrl.text) ?? 0;
    return base * (porc / 100);
  }

  int? _idValido(int? v) {
    if (v == null || v <= 0) return null;
    return v;
  }

  Future<void> _cargarCatalogosExtra() async {
    final results = await Future.wait([
      _db.from('formas_pago').select().eq('estado_forma_pago', true).order('nombre_forma_pago', ascending: true),
      _db.from('estados_poliza').select().eq('estado_activo', true).order('nombre_estado', ascending: true),
      _db.from('intermediarios').select().eq('estado_interm', true).order('nombre_interm', ascending: true),
      _db.from('formaexp').select().order('nombre_formaexp', ascending: true),
    ]);

    formasPago    = (results[0] as List).cast<Map<String, dynamic>>().map(FormaPagoLite.fromMap).toList();
    estadosPoliza = (results[1] as List).cast<Map<String, dynamic>>().map(EstadoPolizaLite.fromMap).toList();
    intermediarios = (results[2] as List).cast<Map<String, dynamic>>().map(IntermediarioLite.fromMap).toList();
    formasExp     = (results[3] as List).cast<Map<String, dynamic>>().map(FormaExpLite.fromMap).toList();
  }

  Future<Asesor?> _asegurarAsesor(int? id) async {
    if (id == null) return null;

    final existente = asesores.firstWhereOrNull((a) => a.id == id);
    if (existente != null) return existente;

    final nuevo = await _repoCat.obtenerAsesor(id);
    if (nuevo != null) {
      asesores = [...asesores, nuevo]
        ..sort((a, b) => a.nombreAsesor.compareTo(b.nombreAsesor));
    }

    return nuevo;
  }

  Future<Cliente?> _asegurarCliente(int? id) async {
    if (id == null) return null;

    final existente = clientes.firstWhereOrNull((c) => c.id == id);
    if (existente != null) return existente;

    final nuevo = await _repoCat.obtenerCliente(id);
    if (nuevo != null) {
      clientes = [...clientes, nuevo]
        ..sort((a, b) => a.nombreCliente.compareTo(b.nombreCliente));
    }

    return nuevo;
  }

  Future<void> _cargar() async {
    try {
      final results = await Future.wait([
        _repoCat.listarAsesores(soloActivos: true),
        _repoCat.listarAseguradoras(soloActivas: true),
        _repoCat.listarRamos(soloActivos: true),
        _repoCat.listarProductos(soloActivos: true),
        _cargarCatalogosExtra(),
      ]);

      asesores = results[0] as List<Asesor>;
      aseguradoras = results[1] as List<Aseguradora>;
      ramos = results[2] as List<Ramo>;
      final allProductosActivos = results[3] as List<Producto>;

      if (esEdicion) {
        final p = await _repoPol.obtenerPoliza(widget.poliza!.id) ?? widget.poliza!;

        _idCtrl.text = p.id.toString();
        _nroCtrl.text = p.nroPoliza ?? '';

        _bienCtrl.text = p.bienAsegurado ?? '';
        _vlrAsegCtrl.text = _fmtMoney(p.vlrasegPoliza);
        _primaCtrl.text = _fmtMoney(p.primaPoliza);
        _valorPolizaCtrl.text = _fmtMoney(p.valorPoliza);
        _vlrBaseComCtrl.text = _fmtMoney(p.vlrbasecomPoliza);
        _porcComCtrl.text = _fmtNum(p.porccomPoliza);
        _porcomAgenciaCtrl.text = _fmtNum(p.porcomAgencia);
        _vlrComCtrl.text = _fmtMoney(p.vlrcomPoliza);
        _vlrComFijaCtrl.text = _fmtMoney(p.vlrcomfijaPoliza);
        final comDistrib = (p.vlrcomPoliza ?? 0) + (p.vlrcomfijaPoliza ?? 0);
        _comDistribCtrl.text = _fmtMoney(comDistrib);
        _comAdicDistribCtrl.text = _fmtMoney(p.vlrcomadicPoliza);
        _porcomAdicCtrl.text = _fmtNum(p.porcomadicPoliza);
        _vlrComAdicCtrl.text = _fmtMoney(p.vlrcomadicPoliza);
        _porcomAsesor1Ctrl.text = _fmtNum(p.porcomAsesor1);
        _porcomAsesor2Ctrl.text = _fmtNum(p.porcomAsesor2);
        _porcomAsesor3Ctrl.text = _fmtNum(p.porcomAsesor3);
        _porcomAsesoradCtrl.text = _fmtNum(p.porcomAsesorad);
        _porcomAgenciaadCtrl.text = _fmtNum(p.porcomAgenciaad);
        _vlrPrimaPagadaCtrl.text = _fmtMoney(p.vlrprimapagadaPoliza);
        _obsCtrl.text = p.obsPoliza ?? '';

        fExp = p.fexpPoliza;
        fIni = p.finiPoliza;
        fFin = p.ffinPoliza;

        _fExpCtrl.text = fExp == null ? '' : _formatearFecha(fExp!);
        _fIniCtrl.text = fIni == null ? '' : _formatearFecha(fIni!);
        _fFinCtrl.text = fFin == null ? '' : _formatearFecha(fFin!);

        cliente = await _asegurarCliente(p.clienteId);
        intermediario = intermediarios.firstWhereOrNull((x) => x.id == p.intermediarioId);
        formaExp = formasExp.firstWhereOrNull((x) => x.id == p.formaexpId);

        asesor1 = await _asegurarAsesor(p.asesorId);
        asesor2 = await _asegurarAsesor(p.asesor2Id);
        asesor3 = await _asegurarAsesor(p.asesor3Id);
        asesorAd = await _asegurarAsesor(p.asesoradId);
        agencia = await _asegurarAsesor(p.agenciaId);
        agenciaAd = await _asegurarAsesor(p.agenciaadId);

        Producto? prod =
            allProductosActivos.firstWhereOrNull((x) => x.id == p.productoId);
        if (prod == null && p.productoId != null) {
          prod = await _repoCat.obtenerProducto(p.productoId!);
        }
        producto = prod;

        ramo = ramos.firstWhereOrNull((x) => x.id == p.ramoId);
        if (ramo == null && p.ramoId != null) {
          final sel = await _repoCat.obtenerRamo(p.ramoId!);
          if (sel != null) {
            ramos = [...ramos, sel]
              ..sort((a, b) => a.nombreRamo.compareTo(b.nombreRamo));
            ramo = ramos.firstWhereOrNull((x) => x.id == p.ramoId);
          }
        }

        if (p.asegId != null) {
          aseguradora = aseguradoras.firstWhereOrNull((a) => a.id == p.asegId);
          if (aseguradora == null) {
            final sel = await _repoCat.obtenerAseguradora(p.asegId!);
            if (sel != null) {
              aseguradoras = [...aseguradoras, sel]
                ..sort((a, b) => a.nombreAseg.compareTo(b.nombreAseg));
              aseguradora =
                  aseguradoras.firstWhereOrNull((a) => a.id == p.asegId);
            }
          }
        } else if (producto != null) {
          final asegId = producto!.aseguradoraId;
          aseguradora = aseguradoras.firstWhereOrNull((a) => a.id == asegId);
        }

        formaPago = formasPago.firstWhereOrNull((x) => x.id == p.formaPagoId);
        estadoPoliza =
            estadosPoliza.firstWhereOrNull((x) => x.id == p.estadoPolizaId);
      } else {
        estadoPoliza = estadosPoliza.firstWhereOrNull((e) => e.id == 'I');
        formaPago = formasPago.firstWhereOrNull(
          (f) => f.nombre.toUpperCase().contains('CONTADO'),
        );
        formaExp = formasExp.firstWhereOrNull(
          (f) => f.nombre.toUpperCase().contains('STELLA'),
        );

        final siguienteId = await _repoPol.obtenerSiguienteId();
        _idCtrl.text = siguienteId.toString();
      }

      if (!mounted) return;
      setState(() => _cargando = false);

      await _refrescarProductos();
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      _toast('Error cargando catálogos: $e');
    }
  }

  Future<void> _refrescarProductos() async {
    if (ramo == null || aseguradora == null) {
      if (!mounted) return;
      setState(() {
        productos = [];
        producto = null;
      });
      return;
    }

    try {
      final res = await _repoCat.listarProductos(
        ramoId: ramo!.id,
        aseguradoraId: aseguradora!.id,
        soloActivos: true,
      );

      if (!mounted) return;

      setState(() {
        productos = res;

        final currentId = producto?.id;
        if (currentId == null) {
          producto = null;
          return;
        }

        final match = productos.firstWhereOrNull((p) => p.id == currentId);
        if (match != null) {
          producto = match;
        } else {
          producto = null;
        }
      });
    } catch (e) {
      _toast('Error cargando productos: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Widget _campo(
    String l,
    TextEditingController c, {
    bool req = false,
    bool num = false,
    int maxDec = 2,
    int lines = 1,
    bool readOnly = false,
    String? helper,
    VoidCallback? onEditingComplete,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: c,
      maxLines: lines,
      readOnly: readOnly,
      keyboardType: num
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      inputFormatters: (num && !readOnly && lines == 1)
          ? [_ColMoneyInputFormatter(maxDec: maxDec)]
          : null,
      validator: req
          ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null
          : null,
      onEditingComplete: onEditingComplete,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: l,
        helperText: helper,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _fechaCampo(
    String label,
    TextEditingController ctrl,
    DateTime? fecha,
    void Function(DateTime?) setFecha, {
    bool autoFin = false,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      onChanged: (v) {
        final f = _soloFecha(v);
        ctrl.value = TextEditingValue(
          text: f,
          selection: TextSelection.collapsed(offset: f.length),
        );

        final parsed = _parseFecha(f);
        if (parsed != null) {
          setState(() {
            setFecha(parsed);
            if (autoFin) {
              final fin = _addOneYearSafe(parsed);
              fFin = fin;
              _fFinCtrl.text = _formatearFecha(fin);
            }
          });
        }
      },
      validator: (v) {
        final s = (v ?? '').trim();
        final esFin = label.contains('fin') || label.contains('Fin');

        if (s.isEmpty) return esFin ? 'Requerido' : null;

        final parsed = _parseFecha(s);
        if (parsed == null) return 'Fecha inválida';

        if (esFin && fIni != null && parsed.isBefore(fIni!)) {
          return 'Fin < Inicio';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: 'dd-mm-aaaa',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_month),
          onPressed: () async {
            final now = DateTime.now();
            final sel = await showDatePicker(
              context: context,
              initialDate: fecha ?? now,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (sel != null) {
              setState(() {
                ctrl.text = _formatearFecha(sel);
                setFecha(sel);
                if (autoFin) {
                  final fin = _addOneYearSafe(sel);
                  fFin = fin;
                  _fFinCtrl.text = _formatearFecha(fin);
                }
              });
            }
          },
        ),
      ),
    );
  }

  Future<void> _guardar() async {
    if (_guardando) return;

    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    // Campos obligatorios según la base de datos
    if (cliente == null) { _toast('El campo Cliente es obligatorio.'); return; }
    if (aseguradora == null) { _toast('El campo Aseguradora es obligatorio.'); return; }
    if (ramo == null) { _toast('El campo Ramo es obligatorio.'); return; }
    if (producto == null) { _toast('El campo Producto es obligatorio.'); return; }
    if (asesor1 == null) { _toast('El campo Asesor es obligatorio.'); return; }
    if (fFin == null) { _toast('La Fecha fin es obligatoria.'); return; }
    if (Sesion.usuarioId == null) { _toast('No hay un usuario activo en sesión.'); return; }

    if (fIni != null && fFin!.isBefore(fIni!)) {
      _toast('La fecha fin no puede ser anterior a la fecha inicio.');
      return;
    }

    // Validar que la suma de % de comisiones principales no supere 100%
    final porcAsesor1 = _parseNumero(_porcomAsesor1Ctrl.text) ?? 0;
    final porcAsesor2 = _parseNumero(_porcomAsesor2Ctrl.text) ?? 0;
    final porcAsesor3 = _parseNumero(_porcomAsesor3Ctrl.text) ?? 0;
    final porcAgencia = _parseNumero(_porcomAgenciaCtrl.text) ?? 0;
    final totalPorcPrincipal = porcAsesor1 + porcAsesor2 + porcAsesor3 + porcAgencia;
    if (totalPorcPrincipal > 100) {
      _toast('La suma de % de comisiones (Asesor 1 + 2 + 3 + Agencia) es ${totalPorcPrincipal.toStringAsFixed(2)}% y supera el 100%.');
      return;
    }

    // Validar que la suma de % adicionales no supere 100%
    final porcAsesorad = _parseNumero(_porcomAsesoradCtrl.text) ?? 0;
    final porcAgenciaad = _parseNumero(_porcomAgenciaadCtrl.text) ?? 0;
    final totalPorcAdic = porcAsesorad + porcAgenciaad;
    if (totalPorcAdic > 100) {
      _toast('La suma de % adicionales (Asesor adic. + Agencia adic.) es ${totalPorcAdic.toStringAsFixed(2)}% y supera el 100%.');
      return;
    }

    // Validar que Com a distrib no supere Vlr Com + Com Fija
    final vlrCom = _parseNumero(_vlrComCtrl.text) ?? 0;
    final comFija = _parseNumero(_vlrComFijaCtrl.text) ?? 0;
    final comDistrib = _parseNumero(_comDistribCtrl.text) ?? 0;
    final maxComDistrib = vlrCom + comFija;
    if (comDistrib > maxComDistrib && maxComDistrib > 0) {
      _toast('La Com. a distribuir ($comDistrib) no puede ser mayor a Vlr Com + Com Fija ($maxComDistrib).');
      return;
    }

    final id = int.tryParse(_idCtrl.text.trim());
    if (id == null || id <= 0) {
      _toast('El código debe ser un número válido mayor que 0.');
      return;
    }

    final prima = _parseNumero(_primaCtrl.text) ?? 0;
    final valorPoliza = _parseNumero(_valorPolizaCtrl.text) ?? 0;

    setState(() => _guardando = true);

    try {
      if (!esEdicion) {
        final existe = await _repoPol.existeId(id);
        if (existe) {
          _toast('Ya existe una póliza con ese código.');
          return;
        }
      }

      final porcomAsesor = _parseNumero(_porcomAsesor1Ctrl.text);

      final data = <String, dynamic>{
        'id': id,
        'nro_poliza':
            _nroCtrl.text.trim().isEmpty ? null : _nroCtrl.text.trim(),
        'cliente_id': _idValido(cliente?.id),
        'asesor_id': _idValido(asesor1?.id),
        'intermediario_id': _idValido(intermediario?.id),
        'ramo_id': _idValido(ramo?.id),
        'producto_id': _idValido(producto?.id),
        'fexp_poliza': fExp?.toIso8601String(),
        'fini_poliza': fIni?.toIso8601String(),
        'ffin_poliza': fFin?.toIso8601String(),
        'prima_poliza': prima,
        'valor_poliza': valorPoliza,
        'vlraseg_poliza': _parseNumero(_vlrAsegCtrl.text),
        'vlrbasecom_poliza': _parseNumero(_vlrBaseComCtrl.text),
        'porccom_poliza': _parseNumero(_porcComCtrl.text),
        'porcom_agencia': _parseNumero(_porcomAgenciaCtrl.text),
        'vlrcom_poliza': _parseNumero(_vlrComCtrl.text),
        'vlrcomfija_poliza': _parseNumero(_vlrComFijaCtrl.text),
        'porcomadic_poliza': _parseNumero(_porcomAdicCtrl.text),
        'vlrcomadic_poliza': _parseNumero(_vlrComAdicCtrl.text),
        'porcom_asesor1': porcomAsesor,
        'agencia_id': _idValido(agencia?.id),
        'forma_pago_id': _idValido(formaPago?.id),
        'estado_poliza_id': estadoPoliza?.id,
        'vlrprimapagada_poliza': _parseNumero(_vlrPrimaPagadaCtrl.text),
        'asesor2_id': _idValido(asesor2?.id),
        'porcom_asesor2': _parseNumero(_porcomAsesor2Ctrl.text),
        'asesor3_id': _idValido(asesor3?.id),
        'porcom_asesor3': _parseNumero(_porcomAsesor3Ctrl.text),
        'asesorad_id': _idValido(asesorAd?.id),
        'porcom_asesorad': _parseNumero(_porcomAsesoradCtrl.text),
        'agenciaad_id': _idValido(agenciaAd?.id),
        'porcom_agenciaad': _parseNumero(_porcomAgenciaadCtrl.text),
        'bien_asegurado':
            _bienCtrl.text.trim().isEmpty ? null : _bienCtrl.text.trim(),
        'obs_poliza':
            _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
        'formaexp_id': _idValido(formaExp?.id),
        'aseg_id': _idValido(aseguradora?.id),
        'usuario_id': Sesion.usuarioId,
      };

      if (esEdicion) {
        final originalId = widget.poliza!.id;
        // Al editar no se modifica quién la creó originalmente
        await _repoPol.actualizarPoliza(
          originalId,
          data..remove('id')..remove('usuario_id'),
        );
      } else {
        await _repoPol.crearPoliza(data);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _toast('Error guardando: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _filaAsesor(
    String label,
    Asesor? value,
    void Function(Asesor?) onChanged,
    TextEditingController? porcCtrl,
    TextEditingController baseCtrl, {
    bool req = false,
  }) {
    final vlr = porcCtrl != null ? _vlrParticipante(porcCtrl, baseCtrl) : 0;
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: BuscadorDropdown<Asesor>(
            label: req ? '$label *' : label,
            value: value,
            items: asesores,
            itemLabel: (a) => a.nombreAsesor,
            onChanged: onChanged,
            validator: req ? (x) => x == null ? 'Requerido' : null : (_) => null,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: porcCtrl != null
              ? _campo('% Comisión', porcCtrl, num: true, maxDec: 5,
                  onEditingComplete: () => _formatearNum(porcCtrl))
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 150,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Vlr comisión',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withOpacity(0.4),
            ),
            child: Text(
              porcCtrl != null ? _fmtMoney(vlr) : '—',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: vlr > 0 ? cs.primary : cs.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _selectorEstado() {
    if (estadosPoliza.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: estadosPoliza.map((e) {
        final selected = estadoPoliza?.id == e.id;
        return ChoiceChip(
          label: Text(e.nombre),
          selected: selected,
          onSelected: (_) => setState(() => estadoPoliza = e),
        );
      }).toList(),
    );
  }

  Widget _seccion(String titulo, List<Widget> campos) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 18),
            ...campos,
          ],
        ),
      ),
    );
  }


  Widget _fila3(Widget a, Widget b, Widget c) {
    final w = MediaQuery.of(context).size.width;
    if (w < 900) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          a,
          const SizedBox(height: 12),
          b,
          const SizedBox(height: 12),
          c,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 16),
        Expanded(child: b),
        const SizedBox(width: 16),
        Expanded(child: c),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? 'Editar póliza' : 'Nueva póliza'),
        actions: [
          if (_guardando)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton.icon(
              onPressed: _guardar,
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // ── Fila 1: Código · Nro Póliza · Fechas ─────────────────────
                _seccion('Identificación y vigencia', [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      width: 110,
                      child: _campo('Código *', _idCtrl,
                          req: true,
                          num: true,
                          readOnly: esEdicion,
                          helper: esEdicion ? null : 'Auto'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: _campo('Número de póliza', _nroCtrl),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _fechaCampo('F. inicio', _fIniCtrl, fIni,
                          (d) => fIni = d, autoFin: true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _fechaCampo(
                          'F. fin *', _fFinCtrl, fFin, (d) => fFin = d),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _fechaCampo('F. expedición', _fExpCtrl, fExp,
                          (d) => fExp = d),
                    ),
                  ]),
                ]),

                // ── Fila 2: Aseguradora · Ramo ────────────────────────────────
                _seccion('Aseguradora y ramo', [
                  // Aseguradora | Ramo | % Base Com (read-only)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      flex: 3,
                      child: BuscadorDropdown<Aseguradora>(
                        label: 'Aseguradora *',
                        value: aseguradora,
                        items: aseguradoras,
                        itemLabel: (a) => a.nombreAseg,
                        onChanged: (v) async {
                          setState(() { aseguradora = v; producto = null; });
                          await _refrescarProductos();
                        },
                        validator: (x) => x == null ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: BuscadorDropdown<Ramo>(
                        label: 'Ramo *',
                        value: ramo,
                        items: ramos,
                        itemLabel: (r) => r.nombreRamo,
                        onChanged: (v) async {
                          setState(() {
                            ramo = v;
                            producto = null;
                            if (ramo != null) _aplicarDefaultsDesdeRamo();
                          });
                          await _refrescarProductos();
                        },
                        validator: (x) => x == null ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 130,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: '% Base Com.',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                        child: Text(
                          ramo != null ? ramo!.porcomBaseRamo.toString() : '—',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  // Producto | Forma de pago | Forma Exp
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      flex: 3,
                      child: BuscadorDropdown<Producto>(
                        label: 'Producto *',
                        value: producto,
                        items: productos,
                        itemLabel: (p) => p.nombreProd,
                        onChanged: (v) {
                          setState(() {
                            producto = v;
                            if (producto != null) _aplicarDefaultsDesdeProducto();
                          });
                        },
                        validator: (x) => x == null ? 'Requerido' : null,
                        helperText: (ramo == null || aseguradora == null)
                            ? 'Selecciona Aseguradora y Ramo primero'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: BuscadorDropdown<FormaPagoLite>(
                        label: 'Forma de pago *',
                        value: formaPago,
                        items: formasPago,
                        itemLabel: (f) => f.nombre,
                        onChanged: (v) => setState(() => formaPago = v),
                        validator: (x) => x == null ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: BuscadorDropdown<FormaExpLite>(
                        label: 'Forma Exp.',
                        value: formaExp,
                        items: formasExp,
                        itemLabel: (f) => f.nombre,
                        onChanged: (v) => setState(() => formaExp = v),
                        validator: (_) => null,
                      ),
                    ),
                  ]),
                ]),

                // ── Cliente ───────────────────────────────────────────────────
                _seccion('Cliente', [
                  BuscadorDropdown<Cliente>(
                    label: 'Cliente *',
                    value: cliente,
                    items: cliente != null ? [cliente!] : [],
                    itemLabel: (c) => c.nombreCliente,
                    itemSubtitle: (c) {
                      final partes = [
                        if ((c.tipodocCliente ?? '').isNotEmpty) c.tipodocCliente!,
                        if ((c.docCliente ?? '').isNotEmpty) c.docCliente!,
                      ];
                      return partes.isEmpty ? null : partes.join(' ');
                    },
                    itemsLoader: (q) => _repoCat.buscarClientes(q),
                    onChanged: (v) => setState(() => cliente = v),
                    validator: (x) => x == null ? 'Requerido' : null,
                    onCrear: (ctx) async {
                      final nuevoId = await Navigator.of(ctx).push<int>(
                        MaterialPageRoute(builder: (_) => const FormCliente()),
                      );
                      if (nuevoId != null) return await _asegurarCliente(nuevoId);
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _fila3(
                    _campo('Bien asegurado / identificación *', _bienCtrl, req: true),
                    _campo('Vlr asegurado', _vlrAsegCtrl, num: true,
                        onEditingComplete: () => _formatearMoney(_vlrAsegCtrl)),
                    BuscadorDropdown<IntermediarioLite>(
                      label: 'Intermediario',
                      value: intermediario,
                      items: intermediarios,
                      itemLabel: (a) => a.nombre,
                      onChanged: (v) => setState(() => intermediario = v),
                      validator: (_) => null,
                    ),
                  ),
                ]),

                // ── Valores ───────────────────────────────────────────────────
                _seccion('Valores', [
                  _fila3(
                    _campo('Vlr Prima', _primaCtrl, num: true,
                        helper: 'Ej: 1.500.000,00',
                        onEditingComplete: () {
                          _formatearMoney(_primaCtrl);
                          _recalcularBaseCom();
                        },
                        onChanged: (_) => _recalcularBaseCom()),
                    _campo('Vlr Total', _valorPolizaCtrl, num: true,
                        onEditingComplete: () => _formatearMoney(_valorPolizaCtrl)),
                    _campo('Vlr Base Com.', _vlrBaseComCtrl, num: true,
                        helper: 'Automático, editable',
                        onEditingComplete: () {
                          _formatearMoney(_vlrBaseComCtrl);
                          _recalcularComision();
                        },
                        onChanged: (_) => _recalcularComision()),
                  ),
                ]),

                // ── Comisiones ────────────────────────────────────────────────
                _seccion('Comisiones', [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: _campo('% Com.', _porcComCtrl, num: true, maxDec: 5,
                          helper: 'Desde producto',
                          onEditingComplete: () {
                            _formatearNum(_porcComCtrl);
                            _recalcularComision();
                          },
                          onChanged: (_) => _recalcularComision()),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _campo('Vlr Com.', _vlrComCtrl, num: true,
                          helper: 'Automático, editable',
                          onEditingComplete: () => _formatearMoney(_vlrComCtrl)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _campo('+ Com. Fija', _vlrComFijaCtrl, num: true,
                          onEditingComplete: () => _formatearMoney(_vlrComFijaCtrl)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _campo('% Com. adicional', _porcomAdicCtrl, num: true, maxDec: 5,
                          onEditingComplete: () => _formatearNum(_porcomAdicCtrl)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _campo('Vlr Com. adicional', _vlrComAdicCtrl, num: true,
                          onEditingComplete: () => _formatearMoney(_vlrComAdicCtrl)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  // Com a distrib y Com Adic a distrib
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: _campo(
                        'Com. a distribuir',
                        _comDistribCtrl,
                        num: true,
                        helper: 'Base para repartir entre asesores',
                        onEditingComplete: () => _formatearMoney(_comDistribCtrl),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _campo(
                        'Com. adic. a distribuir',
                        _comAdicDistribCtrl,
                        num: true,
                        helper: 'Base para repartir com. adicional',
                        onEditingComplete: () => _formatearMoney(_comAdicDistribCtrl),
                      ),
                    ),
                  ]),
                ]),

                // ── Distribución de comisiones ────────────────────────────────
                _seccion('Distribución de comisiones', [
                  _filaAsesor('Asesor 1', asesor1,
                      (v) => setState(() => asesor1 = v), _porcomAsesor1Ctrl, _comDistribCtrl, req: true),
                  const SizedBox(height: 12),
                  _filaAsesor('Asesor 2', asesor2,
                      (v) => setState(() => asesor2 = v), _porcomAsesor2Ctrl, _comDistribCtrl),
                  const SizedBox(height: 12),
                  _filaAsesor('Asesor 3', asesor3,
                      (v) => setState(() => asesor3 = v), _porcomAsesor3Ctrl, _comDistribCtrl),
                  const SizedBox(height: 12),
                  _filaAsesor('Agencia', agencia,
                      (v) => setState(() => agencia = v), _porcomAgenciaCtrl, _comDistribCtrl),
                  const SizedBox(height: 8),
                  // Indicador total % principales
                  Builder(builder: (_) {
                    final total = (_parseNumero(_porcomAsesor1Ctrl.text) ?? 0)
                        + (_parseNumero(_porcomAsesor2Ctrl.text) ?? 0)
                        + (_parseNumero(_porcomAsesor3Ctrl.text) ?? 0)
                        + (_parseNumero(_porcomAgenciaCtrl.text) ?? 0);
                    final excede = total > 100;
                    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Icon(excede ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                          size: 16,
                          color: excede ? Colors.red : Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Total: ${total.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: excede ? Colors.red : Colors.green,
                        ),
                      ),
                    ]);
                  }),
                  const Divider(height: 24),
                  _filaAsesor('Asesor adicional', asesorAd,
                      (v) => setState(() => asesorAd = v), _porcomAsesoradCtrl, _comAdicDistribCtrl),
                  const SizedBox(height: 12),
                  _filaAsesor('Agencia adicional', agenciaAd,
                      (v) => setState(() => agenciaAd = v), _porcomAgenciaadCtrl, _comAdicDistribCtrl),
                  const SizedBox(height: 8),
                  // Indicador total % adicionales
                  Builder(builder: (_) {
                    final total = (_parseNumero(_porcomAsesoradCtrl.text) ?? 0)
                        + (_parseNumero(_porcomAgenciaadCtrl.text) ?? 0);
                    final excede = total > 100;
                    if (total == 0) return const SizedBox.shrink();
                    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Icon(excede ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                          size: 16,
                          color: excede ? Colors.red : Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Total adic.: ${total.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: excede ? Colors.red : Colors.green,
                        ),
                      ),
                    ]);
                  }),
                ]),

                // ── Estado + Vlr Prima Pagada ─────────────────────────────────
                _seccion('Estado y cierre', [
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(child: _selectorEstado()),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 200,
                      child: _campo('Vlr Prima Pagada', _vlrPrimaPagadaCtrl,
                          num: true,
                          onEditingComplete: () =>
                              _formatearMoney(_vlrPrimaPagadaCtrl)),
                    ),
                  ]),
                ]),

                // ── Observaciones ─────────────────────────────────────────────
                _seccion('Observaciones', [
                  _campo('Observación', _obsCtrl, lines: 4),
                ]),

                // ── Botón guardar ─────────────────────────────────────────────
                FilledButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(_guardando ? 'Guardando...' : 'Guardar póliza'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}