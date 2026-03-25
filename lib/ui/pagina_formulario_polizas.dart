// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../datos/repositorio_catalogos.dart';
import '../datos/repositorio_polizas.dart';
import '../datos/catalogos.dart';
import '../datos/poliza.dart';
import '../utils/formatters.dart';
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
  final _porcomAdicCtrl = TextEditingController();
  final _vlrComAdicCtrl = TextEditingController();
  final _porcomAsesor1Ctrl = TextEditingController();
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

  bool get esEdicion => widget.poliza != null;

  @override
  void initState() {
    super.initState();
    _cargar();
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
    _porcomAdicCtrl.dispose();
    _vlrComAdicCtrl.dispose();
    _porcomAsesor1Ctrl.dispose();
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
  }

  int? _idValido(int? v) {
    if (v == null || v <= 0) return null;
    return v;
  }

  Future<void> _cargarCatalogosExtra() async {
    final resFormas = await _db
        .from('formas_pago')
        .select()
        .eq('estado_forma_pago', true)
        .order('nombre_forma_pago', ascending: true);

    final resEstados = await _db
        .from('estados_poliza')
        .select()
        .eq('estado_activo', true)
        .order('nombre_estado', ascending: true);

    final resIntermediarios = await _db
        .from('intermediarios')
        .select()
        .eq('estado_interm', true)
        .order('nombre_interm', ascending: true);

    formasPago = (resFormas as List)
        .cast<Map<String, dynamic>>()
        .map(FormaPagoLite.fromMap)
        .toList();

    estadosPoliza = (resEstados as List)
        .cast<Map<String, dynamic>>()
        .map(EstadoPolizaLite.fromMap)
        .toList();

    intermediarios = (resIntermediarios as List)
        .cast<Map<String, dynamic>>()
        .map(IntermediarioLite.fromMap)
        .toList();
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
        _repoCat.listarClientes(),
        _repoCat.listarAsesores(soloActivos: true),
        _repoCat.listarAseguradoras(soloActivas: true),
        _repoCat.listarRamos(soloActivos: true),
        _repoCat.listarProductos(soloActivos: true),
        _cargarCatalogosExtra(),
      ]);

      clientes = results[0] as List<Cliente>;
      asesores = results[1] as List<Asesor>;
      aseguradoras = results[2] as List<Aseguradora>;
      ramos = results[3] as List<Ramo>;
      final allProductosActivos = results[4] as List<Producto>;

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
        _porcomAdicCtrl.text = _fmtNum(p.porcomadicPoliza);
        _vlrComAdicCtrl.text = _fmtMoney(p.vlrcomadicPoliza);
        _porcomAsesor1Ctrl.text = _fmtNum(p.porcomAsesor1);
        _vlrPrimaPagadaCtrl.text = _fmtMoney(p.vlrprimapagadaPoliza);
        _obsCtrl.text = p.obsPoliza ?? '';

        fExp = p.fexpPoliza;
        fIni = p.finiPoliza;
        fFin = p.ffinPoliza;

        _fExpCtrl.text = fExp == null ? '' : _formatearFecha(fExp!);
        _fIniCtrl.text = fIni == null ? '' : _formatearFecha(fIni!);
        _fFinCtrl.text = fFin == null ? '' : _formatearFecha(fFin!);

        cliente = await _asegurarCliente(p.clienteId);
        intermediario =
            intermediarios.firstWhereOrNull((x) => x.id == p.intermediarioId);

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
        final now = DateTime.now();
        fExp = now;
        _fExpCtrl.text = _formatearFecha(now);
        estadoPoliza = estadosPoliza.firstWhereOrNull((e) => e.id == 'I');

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
        if (s.isEmpty) return 'Requerido';

        final parsed = _parseFecha(s);
        if (parsed == null) return 'Fecha inválida';

        if (label.contains('Fin') && fIni != null && parsed.isBefore(fIni!)) {
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

    if (cliente == null ||
        ramo == null ||
        aseguradora == null ||
        producto == null ||
        formaPago == null ||
        estadoPoliza == null) {
      _toast('Completa los campos obligatorios.');
      return;
    }

    if (fExp == null || fIni == null || fFin == null) {
      _toast('Completa las fechas.');
      return;
    }

    if (fFin!.isBefore(fIni!)) {
      _toast('La fecha fin no puede ser anterior a la fecha inicio.');
      return;
    }

    final id = int.tryParse(_idCtrl.text.trim());
    if (id == null || id <= 0) {
      _toast('El código debe ser un número válido mayor que 0.');
      return;
    }

    final prima = _parseNumero(_primaCtrl.text);
    final valorPoliza = _parseNumero(_valorPolizaCtrl.text);

    if (prima == null || valorPoliza == null) {
      _toast('Revisa Vlr prima y Valor póliza.');
      return;
    }

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
        'vlrcomfija_poliza': null,
        'porcomadic_poliza': _parseNumero(_porcomAdicCtrl.text),
        'vlrcomadic_poliza': _parseNumero(_vlrComAdicCtrl.text),
        'porcom_asesor1': porcomAsesor,
        'agencia_id': _idValido(agencia?.id),
        'forma_pago_id': _idValido(formaPago?.id),
        'estado_poliza_id': estadoPoliza?.id,
        'vlrprimapagada_poliza': _parseNumero(_vlrPrimaPagadaCtrl.text),
        'asesor2_id': _idValido(asesor2?.id),
        'porcom_asesor2': asesor2 == null ? null : porcomAsesor,
        'asesor3_id': _idValido(asesor3?.id),
        'porcom_asesor3': null,
        'asesorad_id': _idValido(asesorAd?.id),
        'porcom_asesorad': null,
        'agenciaad_id': _idValido(agenciaAd?.id),
        'porcom_agenciaad': null,
        'bien_asegurado':
            _bienCtrl.text.trim().isEmpty ? null : _bienCtrl.text.trim(),
        'obs_poliza':
            _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
        'formaexp_id': null,
        'aseg_id': _idValido(aseguradora?.id),
        'usuario_id': null,
      };

      if (esEdicion) {
        final originalId = widget.poliza!.id;
        await _repoPol.actualizarPoliza(originalId, data..remove('id'));
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

  Widget fila2(Widget a, Widget b) {
    final w = MediaQuery.of(context).size.width;
    if (w < 780) {
      return Column(
        children: [a, const SizedBox(height: 12), b],
      );
    }
    return Row(
      children: [
        Expanded(child: a),
        const SizedBox(width: 16),
        Expanded(child: b),
      ],
    );
  }

  Widget fila3(Widget a, Widget b, Widget c) {
    final w = MediaQuery.of(context).size.width;
    if (w < 980) {
      return Column(
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
        title: Text(esEdicion ? 'Editar póliza' : 'Crear póliza'),
        actions: [
          TextButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: const Icon(Icons.save),
            label: Text(_guardando ? 'Guardando...' : 'Guardar'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const Text(
                    "Datos principales",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),

                  fila2(
                    _campo(
                      'Código *',
                      _idCtrl,
                      req: true,
                      num: true,
                      readOnly: esEdicion,
                      helper: esEdicion
                          ? 'Mismo ID de la póliza'
                          : 'Se sugiere automáticamente, pero puedes cambiarlo',
                    ),
                    _campo('Num póliza', _nroCtrl),
                  ),
                  const SizedBox(height: 12),

                  fila3(
                    _fechaCampo(
                      'F. expedición *',
                      _fExpCtrl,
                      fExp,
                      (d) => fExp = d,
                    ),
                    _fechaCampo(
                      'F. inicio *',
                      _fIniCtrl,
                      fIni,
                      (d) => fIni = d,
                      autoFin: true,
                    ),
                    _fechaCampo(
                      'F. fin *',
                      _fFinCtrl,
                      fFin,
                      (d) => fFin = d,
                    ),
                  ),
                  const SizedBox(height: 12),

                  fila2(
                    BuscadorDropdown<Cliente>(
                      label: 'Cliente *',
                      value: cliente,
                      items: clientes,
                      itemLabel: (c) => c.nombreCliente,
                      onChanged: (v) => setState(() => cliente = v),
                      validator: (x) => x == null ? 'Requerido' : null,
                    ),
                    _campo('Ident bien aseg', _bienCtrl),
                  ),
                  const SizedBox(height: 12),

                  fila2(
                    BuscadorDropdown<Aseguradora>(
                      label: 'Aseguradora *',
                      value: aseguradora,
                      items: aseguradoras,
                      itemLabel: (a) => a.nombreAseg,
                      onChanged: (v) async {
                        setState(() {
                          aseguradora = v;
                          producto = null;
                        });
                        await _refrescarProductos();
                      },
                      validator: (x) => x == null ? 'Requerido' : null,
                    ),
                    BuscadorDropdown<Ramo>(
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
                  const SizedBox(height: 12),

                  fila2(
                    _campo(
                      'Vlr base com',
                      _vlrBaseComCtrl,
                      num: true,
                      helper: 'Automático editable',
                      onEditingComplete: () {
                        _formatearMoney(_vlrBaseComCtrl);
                        _recalcularComision();
                      },
                      onChanged: (_) => _recalcularComision(),
                    ),
                    BuscadorDropdown<Producto>(
                      label: 'Producto *',
                      value: producto,
                      items: productos,
                      itemLabel: (p) => p.nombreProd,
                      onChanged: (v) async {
                        setState(() {
                          producto = v;
                          if (producto != null) _aplicarDefaultsDesdeProducto();
                        });
                      },
                      validator: (x) => x == null ? 'Requerido' : null,
                      helperText: (ramo == null || aseguradora == null)
                          ? 'Selecciona Aseguradora y Ramo'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    "Valores",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),

                  fila2(
                    _campo(
                      'Vlr aseg',
                      _vlrAsegCtrl,
                      num: true,
                      onEditingComplete: () => _formatearMoney(_vlrAsegCtrl),
                    ),
                    BuscadorDropdown<FormaPagoLite>(
                      label: 'Forma pago *',
                      value: formaPago,
                      items: formasPago,
                      itemLabel: (f) => f.nombre,
                      onChanged: (v) => setState(() => formaPago = v),
                      validator: (x) => x == null ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  fila2(
                    _campo(
                      'Vlr prima *',
                      _primaCtrl,
                      req: true,
                      num: true,
                      helper: 'Ej: 1.500.000,00',
                      onEditingComplete: () {
                        _formatearMoney(_primaCtrl);
                        _recalcularBaseCom();
                      },
                      onChanged: (_) => _recalcularBaseCom(),
                    ),
                    _campo(
                      'Valor póliza *',
                      _valorPolizaCtrl,
                      req: true,
                      num: true,
                      onEditingComplete: () =>
                          _formatearMoney(_valorPolizaCtrl),
                    ),
                  ),
                  const SizedBox(height: 12),

                  fila2(
                    BuscadorDropdown<IntermediarioLite>(
                      label: 'Intermediario',
                      value: intermediario,
                      items: intermediarios,
                      itemLabel: (a) => a.nombre,
                      onChanged: (v) => setState(() => intermediario = v),
                      validator: (_) => null,
                    ),
                    _campo(
                      '% comisión',
                      _porcComCtrl,
                      num: true,
                      helper: 'Se llena desde producto, editable',
                      onEditingComplete: () {
                        _formatearNum(_porcComCtrl);
                        _recalcularComision();
                      },
                      onChanged: (_) => _recalcularComision(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  fila3(
                    _campo(
                      '% com agencia',
                      _porcomAgenciaCtrl,
                      num: true,
                      onEditingComplete: () =>
                          _formatearNum(_porcomAgenciaCtrl),
                    ),
                    _campo(
                      'Vlr com',
                      _vlrComCtrl,
                      num: true,
                      helper: 'Automático editable',
                      onEditingComplete: () => _formatearMoney(_vlrComCtrl),
                    ),
                    _campo(
                      '% com adic',
                      _porcomAdicCtrl,
                      num: true,
                      onEditingComplete: () => _formatearNum(_porcomAdicCtrl),
                    ),
                  ),
                  const SizedBox(height: 12),

                  fila2(
                    _campo(
                      'Vlr com adic',
                      _vlrComAdicCtrl,
                      num: true,
                      onEditingComplete: () =>
                          _formatearMoney(_vlrComAdicCtrl),
                    ),
                    _campo(
                      'Vlr prima pagada',
                      _vlrPrimaPagadaCtrl,
                      num: true,
                      onEditingComplete: () =>
                          _formatearMoney(_vlrPrimaPagadaCtrl),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    "Distribución / control",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),

                  fila2(
                    BuscadorDropdown<Asesor>(
                      label: 'Asesor 1',
                      value: asesor1,
                      items: asesores,
                      itemLabel: (a) => a.nombreAsesor,
                      onChanged: (v) => setState(() => asesor1 = v),
                      validator: (_) => null,
                    ),
                    _campo(
                      '% comisión asesor 1',
                      _porcomAsesor1Ctrl,
                      num: true,
                      onEditingComplete: () =>
                          _formatearNum(_porcomAsesor1Ctrl),
                    ),
                  ),
                  const SizedBox(height: 12),

                  fila2(
                    BuscadorDropdown<Asesor>(
                      label: 'Agencia',
                      value: agencia,
                      items: asesores,
                      itemLabel: (a) => a.nombreAsesor,
                      onChanged: (v) => setState(() => agencia = v),
                      validator: (_) => null,
                    ),
                    BuscadorDropdown<EstadoPolizaLite>(
                      label: 'Estado de póliza *',
                      value: estadoPoliza,
                      items: estadosPoliza,
                      itemLabel: (e) => '${e.id} - ${e.nombre}',
                      onChanged: (v) => setState(() => estadoPoliza = v),
                      validator: (x) => x == null ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  fila3(
                    BuscadorDropdown<Asesor>(
                      label: 'Asesor 2',
                      value: asesor2,
                      items: asesores,
                      itemLabel: (a) => a.nombreAsesor,
                      onChanged: (v) => setState(() => asesor2 = v),
                      validator: (_) => null,
                    ),
                    BuscadorDropdown<Asesor>(
                      label: 'Asesor 3',
                      value: asesor3,
                      items: asesores,
                      itemLabel: (a) => a.nombreAsesor,
                      onChanged: (v) => setState(() => asesor3 = v),
                      validator: (_) => null,
                    ),
                    const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),

                  fila2(
                    BuscadorDropdown<Asesor>(
                      label: 'Asesor adicional',
                      value: asesorAd,
                      items: asesores,
                      itemLabel: (a) => a.nombreAsesor,
                      onChanged: (v) => setState(() => asesorAd = v),
                      validator: (_) => null,
                    ),
                    BuscadorDropdown<Asesor>(
                      label: 'Agencia adicional',
                      value: agenciaAd,
                      items: asesores,
                      itemLabel: (a) => a.nombreAsesor,
                      onChanged: (v) => setState(() => agenciaAd = v),
                      validator: (_) => null,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _campo('Observación', _obsCtrl, lines: 3),

                  const SizedBox(height: 30),

                  FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child:
                          Text(_guardando ? "Guardando..." : "Guardar póliza"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}