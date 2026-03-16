// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../datos/repositorio_catalogos.dart';
import '../datos/repositorio_polizas.dart';
import '../datos/catalogos.dart';
import '../datos/poliza.dart';
import '../utils/formatters.dart';

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

class PaginaFormularioPolizas extends StatefulWidget {
  final Poliza? poliza;
  const PaginaFormularioPolizas({super.key, this.poliza});

  @override
  State<PaginaFormularioPolizas> createState() => _PaginaFormularioPolizasState();
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

  final _porcomBaseCtrl = TextEditingController();
  final _bienCtrl = TextEditingController();
  final _vlrAsegCtrl = TextEditingController();
  final _primaCtrl = TextEditingController();
  final _vlrTotalCtrl = TextEditingController();
  final _vlrBaseComCtrl = TextEditingController();
  final _porcomCtrl = TextEditingController();
  final _vlrComCtrl = TextEditingController();
  final _comFijaCtrl = TextEditingController();
  final _porcomAdicCtrl = TextEditingController();
  final _vlrComAdicCtrl = TextEditingController();
  final _porcomAsesor1Ctrl = TextEditingController();
  final _vlrPrimaPagadaCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  Cliente? cliente;
  Aseguradora? aseguradora;
  Ramo? ramo;
  Producto? producto;

  Asesor? intermediario;
  Asesor? asesor1;
  Asesor? agencia;

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

    _porcomBaseCtrl.dispose();
    _bienCtrl.dispose();
    _vlrAsegCtrl.dispose();
    _primaCtrl.dispose();
    _vlrTotalCtrl.dispose();
    _vlrBaseComCtrl.dispose();
    _porcomCtrl.dispose();
    _vlrComCtrl.dispose();
    _comFijaCtrl.dispose();
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
    if (digits.length <= 4) return '${digits.substring(0, 2)}-${digits.substring(2)}';
    return '${digits.substring(0, 2)}-${digits.substring(2, 4)}-${digits.substring(4, 8)}';
  }

  DateTime? _parseFecha(String v) {
    try {
      final p = v.split('-');
      if (p.length != 3) return null;

      final d = int.parse(p[0]);
      final m = int.parse(p[1]);
      final y = int.parse(p[2]);

      if (y < 2000 || y > 2100) return null;

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
    _porcomBaseCtrl.text = _fmtNum(ramo!.porcomBaseRamo);
    _recalcularBaseCom();
  }

  void _aplicarDefaultsDesdeProducto() {
    if (producto == null) return;

    if (producto!.porcomProd != null) {
      _porcomCtrl.text = _fmtNum(producto!.porcomProd);
    }

    if (producto!.comisionProd != null) {
      _comFijaCtrl.text = _fmtMoney(producto!.comisionProd);
    }

    if (producto!.porcadProd != null) {
      _porcomAdicCtrl.text = _fmtNum(producto!.porcadProd);
    }

    _recalcularComision();
  }

  void _recalcularBaseCom() {
    final prima = _parseNumero(_primaCtrl.text) ?? 0;
    final base = _parseNumero(_porcomBaseCtrl.text) ?? 0;

    final vlrBase = prima * (base / 100);
    _vlrBaseComCtrl.text = _fmtMoney(vlrBase);

    _recalcularComision();
  }

  void _recalcularComision() {
    final vlrBase = _parseNumero(_vlrBaseComCtrl.text) ?? 0;
    final porcom = _parseNumero(_porcomCtrl.text) ?? 0;
    final comFija = _parseNumero(_comFijaCtrl.text);

    final calculado = vlrBase * (porcom / 100);

    if (comFija != null && comFija > 0) {
      _vlrComCtrl.text = _fmtMoney(comFija);
    } else {
      _vlrComCtrl.text = _fmtMoney(calculado);
    }
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

    formasPago = (resFormas as List)
        .cast<Map<String, dynamic>>()
        .map(FormaPagoLite.fromMap)
        .toList();

    estadosPoliza = (resEstados as List)
        .cast<Map<String, dynamic>>()
        .map(EstadoPolizaLite.fromMap)
        .toList();
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
        final p = widget.poliza!;

        _idCtrl.text = p.id.toString();
        _nroCtrl.text = p.nroPoliza;

        _porcomBaseCtrl.text = _fmtNum(p.porcombasePoliza);
        _bienCtrl.text = p.bienAsegurado ?? '';
        _vlrAsegCtrl.text = _fmtMoney(p.vlrasegPoliza);
        _primaCtrl.text = _fmtMoney(p.primaPoliza);
        _vlrTotalCtrl.text = _fmtMoney(p.vlrtotalPoliza ?? p.valorPoliza);
        _vlrBaseComCtrl.text = _fmtMoney(p.vlrbasecomPoliza);
        _porcomCtrl.text = _fmtNum(p.porcomPoliza);
        _vlrComCtrl.text = _fmtMoney(p.vlrcomPoliza);
        _comFijaCtrl.text = _fmtMoney(p.comfijaPoliza);
        _porcomAdicCtrl.text = _fmtNum(p.porcomadicPoliza);
        _vlrComAdicCtrl.text = _fmtMoney(p.vlrcomadicPoliza);
        _porcomAsesor1Ctrl.text = _fmtNum(p.porcomAsesor1);
        _vlrPrimaPagadaCtrl.text = _fmtMoney(p.vlrprimapagadaPoliza);
        _obsCtrl.text = p.obsPoliza ?? '';

        fExp = p.fexpPoliza;
        fIni = p.finiPoliza;
        fFin = p.ffinPoliza;

        _fExpCtrl.text = _formatearFecha(fExp!);
        _fIniCtrl.text = _formatearFecha(fIni!);
        _fFinCtrl.text = _formatearFecha(fFin!);

        cliente = clientes.firstWhereOrNull((x) => x.id == p.clienteId);

        intermediario = asesores.firstWhereOrNull((x) => x.id == p.intermediarioId || x.id == p.asesorId);
        if (intermediario == null && (p.intermediarioId ?? p.asesorId) > 0) {
          final sel = await _repoCat.obtenerAsesor(p.intermediarioId ?? p.asesorId);
          if (sel != null) {
            asesores = [...asesores, sel]..sort((a, b) => a.nombreAsesor.compareTo(b.nombreAsesor));
            intermediario = asesores.firstWhereOrNull((x) => x.id == sel.id);
          }
        }

        asesor1 = asesores.firstWhereOrNull((x) => x.id == p.asesor1Id);
        if (asesor1 == null && p.asesor1Id != null) {
          final sel = await _repoCat.obtenerAsesor(p.asesor1Id!);
          if (sel != null) {
            asesores = [...asesores, sel]..sort((a, b) => a.nombreAsesor.compareTo(b.nombreAsesor));
            asesor1 = asesores.firstWhereOrNull((x) => x.id == sel.id);
          }
        }

        agencia = asesores.firstWhereOrNull((x) => x.id == p.agenciaId);
        if (agencia == null && p.agenciaId != null) {
          final sel = await _repoCat.obtenerAsesor(p.agenciaId!);
          if (sel != null) {
            asesores = [...asesores, sel]..sort((a, b) => a.nombreAsesor.compareTo(b.nombreAsesor));
            agencia = asesores.firstWhereOrNull((x) => x.id == sel.id);
          }
        }

        Producto? prod = allProductosActivos.firstWhereOrNull((x) => x.id == p.productoId);
        prod ??= await _repoCat.obtenerProducto(p.productoId);
        producto = prod;

        ramo = ramos.firstWhereOrNull((x) => x.id == p.ramoId);
        if (ramo == null) {
          final sel = await _repoCat.obtenerRamo(p.ramoId);
          if (sel != null) {
            ramos = [...ramos, sel]..sort((a, b) => a.nombreRamo.compareTo(b.nombreRamo));
            ramo = ramos.firstWhereOrNull((x) => x.id == p.ramoId);
          }
        }

        if (producto != null) {
          final asegId = producto!.aseguradoraId;
          aseguradora = aseguradoras.firstWhereOrNull((a) => a.id == asegId);
          if (aseguradora == null) {
            final sel = await _repoCat.obtenerAseguradora(asegId);
            if (sel != null) {
              aseguradoras = [...aseguradoras, sel]..sort((a, b) => a.nombreAseg.compareTo(b.nombreAseg));
              aseguradora = aseguradoras.firstWhereOrNull((a) => a.id == asegId);
            }
          }
        }

        formaPago = formasPago.firstWhereOrNull((x) => x.id == p.formaPagoId);
        estadoPoliza = estadosPoliza.firstWhereOrNull((x) => x.id == p.estadoPolizaId);
      } else {
        final now = DateTime.now();
        fExp = now;
        _fExpCtrl.text = _formatearFecha(now);
        estadoPoliza = estadosPoliza.firstWhereOrNull((e) => e.id == 'I');
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
        }
      });

      final currentId = producto?.id;
      if (esEdicion && currentId != null && !productos.any((p) => p.id == currentId)) {
        final sel = await _repoCat.obtenerProducto(currentId);
        if (sel != null && mounted) {
          setState(() {
            productos = [...productos, sel]..sort((a, b) => a.nombreProd.compareTo(b.nombreProd));
            producto = productos.firstWhereOrNull((p) => p.id == currentId);
          });
        }
      }

      if (mounted && producto != null) {
        final ok = productos.any((p) => p.id == producto!.id);
        if (!ok) setState(() => producto = null);
      }
    } catch (e) {
      _toast('Error cargando productos: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
      keyboardType: num ? const TextInputType.numberWithOptions(decimal: true) : null,
      validator: req ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null : null,
      onEditingComplete: onEditingComplete,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: l,
        helperText: helper,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _dd<T>(
    String l,
    T? v,
    List<T> items,
    String Function(T) lab,
    Future<void> Function(T?) ch, {
    String? helper,
    bool req = true,
  }) {
    return DropdownButtonFormField<T>(
      value: v,
      isExpanded: true,
      items: items
          .map((e) => DropdownMenuItem(
                value: e,
                child: Text(lab(e), overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (x) async => ch(x),
      validator: req ? (x) => x == null ? 'Requerido' : null : null,
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
        intermediario == null ||
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

    final prima = _parseNumero(_primaCtrl.text);
    final vlrTotal = _parseNumero(_vlrTotalCtrl.text);

    if (prima == null || vlrTotal == null) {
      _toast('Revisa Vlr prima y Vlr total.');
      return;
    }

    setState(() => _guardando = true);
    try {
      final data = <String, dynamic>{
        'nro_poliza': _nroCtrl.text.trim(),
        'cliente_id': cliente!.id,
        'asesor_id': intermediario!.id,
        'intermediario_id': intermediario!.id,
        'ramo_id': ramo!.id,
        'producto_id': producto!.id,
        'fexp_poliza': fExp!.toIso8601String(),
        'fini_poliza': fIni!.toIso8601String(),
        'ffin_poliza': fFin!.toIso8601String(),
        'prima_poliza': prima,
        'valor_poliza': vlrTotal,
        'vlrtotal_poliza': vlrTotal,
        'vlraseg_poliza': _parseNumero(_vlrAsegCtrl.text),
        'porcombase_poliza': _parseNumero(_porcomBaseCtrl.text),
        'vlrbasecom_poliza': _parseNumero(_vlrBaseComCtrl.text),
        'porcom_poliza': _parseNumero(_porcomCtrl.text),
        'vlrcom_poliza': _parseNumero(_vlrComCtrl.text),
        'comfija_poliza': _parseNumero(_comFijaCtrl.text),
        'porcomadic_poliza': _parseNumero(_porcomAdicCtrl.text),
        'vlrcomadic_poliza': _parseNumero(_vlrComAdicCtrl.text),
        'asesor1_id': asesor1?.id,
        'porcom_asesor1': _parseNumero(_porcomAsesor1Ctrl.text),
        'agencia_id': agencia?.id,
        'forma_pago_id': formaPago!.id,
        'estado_poliza_id': estadoPoliza!.id,
        'vlrprimapagada_poliza': _parseNumero(_vlrPrimaPagadaCtrl.text),
        'bien_asegurado': _bienCtrl.text.trim().isEmpty ? null : _bienCtrl.text.trim(),
        'obs_poliza': _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      };

      if (esEdicion) {
        final id = int.tryParse(_idCtrl.text.trim());
        if (id == null) {
          _toast('ID inválido.');
          return;
        }
        await _repoPol.actualizarPoliza(id, data);
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
    if (w < 780) return Column(children: [a, const SizedBox(height: 12), b]);
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
                      'Código',
                      _idCtrl,
                      readOnly: true,
                      helper: esEdicion ? 'Mismo ID de la póliza' : 'Se genera al guardar',
                    ),
                    _campo('Num póliza *', _nroCtrl, req: true),
                  ),
                  const SizedBox(height: 12),

                  fila3(
                    _fechaCampo('F. expedición *', _fExpCtrl, fExp, (d) => fExp = d),
                    _fechaCampo('F. inicio *', _fIniCtrl, fIni, (d) => fIni = d, autoFin: true),
                    _fechaCampo('F. fin *', _fFinCtrl, fFin, (d) => fFin = d),
                  ),
                  const SizedBox(height: 12),

                  fila2(
                    _dd<Cliente>(
                      'Cliente *',
                      cliente,
                      clientes,
                      (c) => c.nombreCliente,
                      (v) async => setState(() => cliente = v),
                    ),
                    _campo('Ident bien aseg', _bienCtrl),
                  ),
                  const SizedBox(height: 12),

                  fila2(
                    _dd<Aseguradora>(
                      'Aseguradora *',
                      aseguradora,
                      aseguradoras,
                      (a) => a.nombreAseg,
                      (v) async {
                        setState(() {
                          aseguradora = v;
                          producto = null;
                        });
                        await _refrescarProductos();
                      },
                    ),
                    _dd<Ramo>(
                      'Ramo *',
                      ramo,
                      ramos,
                      (r) => r.nombreRamo,
                      (v) async {
                        setState(() {
                          ramo = v;
                          producto = null;
                          if (ramo != null) _aplicarDefaultsDesdeRamo();
                        });
                        await _refrescarProductos();
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  fila2(
                    _campo(
                      '% base com',
                      _porcomBaseCtrl,
                      num: true,
                      helper: 'Se llena desde ramo, editable',
                      onEditingComplete: () {
                        _formatearNum(_porcomBaseCtrl);
                        _recalcularBaseCom();
                      },
                      onChanged: (_) => _recalcularBaseCom(),
                    ),
                    _dd<Producto>(
                      'Producto *',
                      producto,
                      productos,
                      (p) => p.nombreProd,
                      (v) async {
                        setState(() {
                          producto = v;
                          if (producto != null) _aplicarDefaultsDesdeProducto();
                        });
                      },
                      helper: (ramo == null || aseguradora == null)
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
                    _dd<FormaPagoLite>(
                      'Forma pago *',
                      formaPago,
                      formasPago,
                      (f) => f.nombre,
                      (v) async => setState(() => formaPago = v),
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
                      'Vlr total *',
                      _vlrTotalCtrl,
                      req: true,
                      num: true,
                      helper: 'Se guarda también en valor_poliza',
                      onEditingComplete: () => _formatearMoney(_vlrTotalCtrl),
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
                    _dd<Asesor>(
                      'Intermediario *',
                      intermediario,
                      asesores,
                      (a) => a.nombreAsesor,
                      (v) async => setState(() => intermediario = v),
                    ),
                  ),
                  const SizedBox(height: 12),

                  fila3(
                    _campo(
                      '% com',
                      _porcomCtrl,
                      num: true,
                      helper: 'Se llena desde producto, editable',
                      onEditingComplete: () {
                        _formatearNum(_porcomCtrl);
                        _recalcularComision();
                      },
                      onChanged: (_) => _recalcularComision(),
                    ),
                    _campo(
                      'Vlr com',
                      _vlrComCtrl,
                      num: true,
                      helper: 'Automático editable',
                      onEditingComplete: () => _formatearMoney(_vlrComCtrl),
                    ),
                    _campo(
                      'Com fija',
                      _comFijaCtrl,
                      num: true,
                      onEditingComplete: () {
                        _formatearMoney(_comFijaCtrl);
                        _recalcularComision();
                      },
                      onChanged: (_) => _recalcularComision(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  fila2(
                    _campo(
                      '% com adic',
                      _porcomAdicCtrl,
                      num: true,
                      onEditingComplete: () => _formatearNum(_porcomAdicCtrl),
                    ),
                    _campo(
                      'Vlr com adic',
                      _vlrComAdicCtrl,
                      num: true,
                      onEditingComplete: () => _formatearMoney(_vlrComAdicCtrl),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    "Distribución / control",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),

                  fila2(
                    _dd<Asesor>(
                      'Asesor 1',
                      asesor1,
                      asesores,
                      (a) => a.nombreAsesor,
                      (v) async => setState(() => asesor1 = v),
                      req: false,
                    ),
                    _campo(
                      '% comisión asesor 1',
                      _porcomAsesor1Ctrl,
                      num: true,
                      onEditingComplete: () => _formatearNum(_porcomAsesor1Ctrl),
                    ),
                  ),
                  const SizedBox(height: 12),

                  fila3(
                    _dd<Asesor>(
                      'Agencia',
                      agencia,
                      asesores,
                      (a) => a.nombreAsesor,
                      (v) async => setState(() => agencia = v),
                      req: false,
                    ),
                    _dd<EstadoPolizaLite>(
                      'Estado de póliza *',
                      estadoPoliza,
                      estadosPoliza,
                      (e) => '${e.id} - ${e.nombre}',
                      (v) async => setState(() => estadoPoliza = v),
                    ),
                    _campo(
                      'Vlr prima pagada',
                      _vlrPrimaPagadaCtrl,
                      num: true,
                      onEditingComplete: () => _formatearMoney(_vlrPrimaPagadaCtrl),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _campo('Observación', _obsCtrl, lines: 3),

                  const SizedBox(height: 30),

                  FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(_guardando ? "Guardando..." : "Guardar póliza"),
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