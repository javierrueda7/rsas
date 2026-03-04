// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import '../datos/repositorio_catalogos.dart';
import '../datos/repositorio_polizas.dart';
import '../datos/catalogos.dart';
import '../datos/poliza.dart';

extension FirstWhereOrNullExt<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
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

  bool _cargando = true;
  bool _guardando = false;

  // ================= CONTROLLERS =================
  final _idCtrl = TextEditingController(); // SOLO LECTURA (en edición)
  final _nroCtrl = TextEditingController();
  final _primaCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  final _bienCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  final _fExpCtrl = TextEditingController();
  final _fIniCtrl = TextEditingController();
  final _fFinCtrl = TextEditingController();

  // ================= VARIABLES =================
  Cliente? cliente;
  Asesor? asesor;
  Aseguradora? aseguradora;
  Ramo? ramo;
  Producto? producto;

  DateTime? fExp;
  DateTime? fIni;
  DateTime? fFin;

  List<Cliente> clientes = [];
  List<Asesor> asesores = [];
  List<Aseguradora> aseguradoras = [];
  List<Ramo> ramos = [];
  List<Producto> productos = [];

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
    _primaCtrl.dispose();
    _valorCtrl.dispose();
    _bienCtrl.dispose();
    _obsCtrl.dispose();
    _fExpCtrl.dispose();
    _fIniCtrl.dispose();
    _fFinCtrl.dispose();
    super.dispose();
  }

  // ==================== FECHAS ====================

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

  // ==================== CARGA (ACTIVOS + SELECCIONADO SI INACTIVO) ====================

  Future<void> _cargar() async {
    try {
      // ✅ En creación, solo activos.
      // ✅ En edición, también cargamos solo activos, pero luego agregamos el seleccionado si está inactivo.
      final results = await Future.wait([
        _repoCat.listarClientes(), // clientes no tiene estado
        _repoCat.listarAsesores(soloActivos: true),
        _repoCat.listarAseguradoras(soloActivas: true),
        _repoCat.listarRamos(soloActivos: true),
        _repoCat.listarProductos(soloActivos: true),
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
        _primaCtrl.text = p.primaPoliza.toString();
        _valorCtrl.text = p.valorPoliza.toString();
        _bienCtrl.text = p.bienAsegurado ?? '';
        _obsCtrl.text = p.obsPoliza ?? '';

        fExp = p.fexpPoliza;
        fIni = p.finiPoliza;
        fFin = p.ffinPoliza;

        _fExpCtrl.text = _formatearFecha(fExp!);
        _fIniCtrl.text = _formatearFecha(fIni!);
        _fFinCtrl.text = _formatearFecha(fFin!);

        // ===== Cliente =====
        cliente = clientes.firstWhereOrNull((x) => x.id == p.clienteId);

        // ===== Asesor: activos + seleccionado si inactivo =====
        asesor = asesores.firstWhereOrNull((x) => x.id == p.asesorId);
        if (asesor == null) {
          final sel = await _repoCat.obtenerAsesor(p.asesorId); // puede estar inactivo
          if (sel != null) {
            asesores = [...asesores, sel]..sort((a, b) => a.nombreAsesor.compareTo(b.nombreAsesor));
            asesor = asesores.firstWhereOrNull((x) => x.id == p.asesorId);
          }
        }

        // ===== Producto: activos + seleccionado si inactivo =====
        Producto? prod = allProductosActivos.firstWhereOrNull((x) => x.id == p.productoId);
        prod ??= await _repoCat.obtenerProducto(p.productoId); // puede estar inactivo
        producto = prod;

        // ===== Ramo: activos + seleccionado si inactivo =====
        ramo = ramos.firstWhereOrNull((x) => x.id == p.ramoId);
        if (ramo == null) {
          final sel = await _repoCat.obtenerRamo(p.ramoId); // puede estar inactivo
          if (sel != null) {
            ramos = [...ramos, sel]..sort((a, b) => a.nombreRamo.compareTo(b.nombreRamo));
            ramo = ramos.firstWhereOrNull((x) => x.id == p.ramoId);
          }
        }

        // ===== Aseguradora: se saca del producto (o del match), activos + seleccionada si inactiva =====
        if (producto != null) {
          final asegId = producto!.aseguradoraId;
          aseguradora = aseguradoras.firstWhereOrNull((a) => a.id == asegId);
          if (aseguradora == null) {
            final sel = await _repoCat.obtenerAseguradora(asegId); // puede estar inactiva
            if (sel != null) {
              aseguradoras = [...aseguradoras, sel]..sort((a, b) => a.nombreAseg.compareTo(b.nombreAseg));
              aseguradora = aseguradoras.firstWhereOrNull((a) => a.id == asegId);
            }
          }
        }
      } else {
        final now = DateTime.now();
        fExp = now;
        _fExpCtrl.text = _formatearFecha(now);
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
      // ✅ Solo activos
      final res = await _repoCat.listarProductos(
        ramoId: ramo!.id,
        aseguradoraId: aseguradora!.id,
        soloActivos: true,
      );

      if (!mounted) return;

      // Primero set activos
      setState(() {
        productos = res;

        final currentId = producto?.id;
        if (currentId == null) {
          producto = null;
          return;
        }

        // Si el seleccionado está en activos, usamos la instancia correcta
        final match = productos.firstWhereOrNull((p) => p.id == currentId);
        if (match != null) {
          producto = match; // ✅ instancia del dropdown
        }
      });

      // Si estamos editando y el seleccionado era inactivo, lo agregamos SOLO a él
      final currentId = producto?.id;
      if (esEdicion && currentId != null && !productos.any((p) => p.id == currentId)) {
        final sel = await _repoCat.obtenerProducto(currentId); // puede venir inactivo
        if (sel != null && mounted) {
          setState(() {
            productos = [...productos, sel]..sort((a, b) => a.nombreProd.compareTo(b.nombreProd));
            producto = productos.firstWhereOrNull((p) => p.id == currentId); // ✅ instancia
          });
        }
      }

      // Si por alguna razón quedó null (ej cambiaste ramo/aseg), limpio
      if (mounted && producto != null) {
        final ok = productos.any((p) => p.id == producto!.id);
        if (!ok) setState(() => producto = null);
      }
    } catch (e) {
      _toast('Error cargando productos: $e');
    }
  }

  // ==================== WIDGETS CAMPOS ====================

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  num? _parseNumero(String s) {
    final limpio = s
        .replaceAll(RegExp(r'[^0-9,.\-]'), '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    return num.tryParse(limpio);
  }

  Widget _campo(
    String l,
    TextEditingController c, {
    bool req = false,
    bool num = false,
    int lines = 1,
    bool readOnly = false,
    String? helper,
  }) {
    return TextFormField(
      controller: c,
      maxLines: lines,
      readOnly: readOnly,
      keyboardType: num ? TextInputType.number : null,
      validator: req ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null : null,
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
  }) {
    return DropdownButtonFormField<T>(
      value: v,
      isExpanded: true,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(lab(e), overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (x) async => ch(x),
      validator: (x) => x == null ? 'Requerido' : null,
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

        if (label.contains('Fin') && fIni != null && parsed.isBefore(fIni!)) return 'Fin < Inicio';
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

  // ==================== GUARDAR ====================

  Future<void> _guardar() async {
    if (_guardando) return;

    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (cliente == null || asesor == null || ramo == null || aseguradora == null || producto == null) {
      _toast('Completa los dropdowns obligatorios.');
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
    final valor = _parseNumero(_valorCtrl.text);
    if (prima == null || valor == null) {
      _toast('Revisa prima y valor.');
      return;
    }

    setState(() => _guardando = true);
    try {
      final data = <String, dynamic>{
        'nro_poliza': _nroCtrl.text.trim(),
        'cliente_id': cliente!.id,
        'asesor_id': asesor!.id,
        'ramo_id': ramo!.id,
        'producto_id': producto!.id,
        'fexp_poliza': fExp!.toIso8601String(),
        'fini_poliza': fIni!.toIso8601String(),
        'ffin_poliza': fFin!.toIso8601String(),
        'prima_poliza': prima,
        'valor_poliza': valor,
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

  // ==================== LAYOUT HELPERS ====================

  Widget fila2(Widget a, Widget b) {
    final w = MediaQuery.of(context).size.width;
    if (w < 780) return Column(children: [a, const SizedBox(height: 12), b]);
    return Row(children: [
      Expanded(child: a),
      const SizedBox(width: 16),
      Expanded(child: b),
    ]);
  }

  Widget fila3(Widget a, Widget b, Widget c) {
    final w = MediaQuery.of(context).size.width;
    if (w < 980) {
      return Column(children: [
        a,
        const SizedBox(height: 12),
        b,
        const SizedBox(height: 12),
        c,
      ]);
    }
    return Row(children: [
      Expanded(child: a),
      const SizedBox(width: 16),
      Expanded(child: b),
      const SizedBox(width: 16),
      Expanded(child: c),
    ]);
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
          constraints: const BoxConstraints(maxWidth: 950),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const Text("Datos principales", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),

                  if (esEdicion) ...[
                    _campo('ID (Primary Key)', _idCtrl, readOnly: true, helper: 'Generado por el sistema'),
                    const SizedBox(height: 12),
                  ],

                  fila2(
                    _campo('Nro póliza *', _nroCtrl, req: true),
                    _campo('Bien asegurado', _bienCtrl),
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
                    _dd<Asesor>(
                      'Asesor *',
                      asesor,
                      asesores,
                      (a) => a.nombreAsesor,
                      (v) async => setState(() => asesor = v),
                    ),
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
                        });
                        await _refrescarProductos();
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  _dd<Producto>(
                    'Producto *',
                    producto,
                    productos,
                    (p) => p.nombreProd,
                    (v) async => setState(() => producto = v),
                    helper: (ramo == null || aseguradora == null) ? 'Selecciona Aseguradora y Ramo' : null,
                  ),

                  const SizedBox(height: 24),

                  const Text("Fechas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),

                  fila3(
                    _fechaCampo('Expedición *', _fExpCtrl, fExp, (d) => fExp = d),
                    _fechaCampo('Inicio *', _fIniCtrl, fIni, (d) => fIni = d, autoFin: true),
                    _fechaCampo('Fin *', _fFinCtrl, fFin, (d) => fFin = d),
                  ),

                  const SizedBox(height: 24),

                  const Text("Valores", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),

                  fila2(
                    _campo('Prima *', _primaCtrl, req: true, num: true),
                    _campo('Valor *', _valorCtrl, req: true, num: true),
                  ),

                  const SizedBox(height: 24),

                  _campo('Observaciones', _obsCtrl, lines: 3),

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
