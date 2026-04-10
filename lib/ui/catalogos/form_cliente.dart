import 'package:flutter/material.dart';
import '../../datos/catalogos.dart';
import '../../datos/repositorio_catalogos.dart';

class FormCliente extends StatefulWidget {
  final Cliente? cliente;
  const FormCliente({super.key, this.cliente});

  @override
  State<FormCliente> createState() => _FormClienteState();
}

class _FormClienteState extends State<FormCliente> {
  final _formKey = GlobalKey<FormState>();
  final repo = RepositorioCatalogos();

  bool guardando = false;
  bool cargandoMunicipios = true;
  bool cargandoId = true;
  bool cargandoAsesores = true;

  late final TextEditingController idCtrl;
  late final TextEditingController nombreCtrl;
  late final TextEditingController docCtrl;
  late final TextEditingController telCtrl;
  late final TextEditingController correoCtrl;
  late final TextEditingController dirCtrl;
  late final TextEditingController notasCtrl;
  late final TextEditingController contactoCtrl;
  late final TextEditingController cargocontCtrl;

  static const List<String> tiposDocNormalizados = ['CC', 'CE', 'NIT', 'PAS', 'OTRO'];

  String? tipoDocSel;
  String tipopersSel = 'N';

  List<Municipio> municipios = [];
  int? municIdSel;

  List<Asesor> asesores = [];
  int? asesorIdSel;

  bool estadoCliente = true;
  bool recordarCliente = false;

  bool get esEdicion => widget.cliente != null;

  @override
  void initState() {
    super.initState();

    idCtrl = TextEditingController(
      text: esEdicion ? widget.cliente!.id.toString() : '',
    );
    nombreCtrl = TextEditingController(text: widget.cliente?.nombreCliente ?? '');
    docCtrl = TextEditingController(text: widget.cliente?.docCliente ?? '');
    telCtrl = TextEditingController(text: widget.cliente?.telCliente ?? '');
    correoCtrl = TextEditingController(text: widget.cliente?.correoCliente ?? '');
    dirCtrl = TextEditingController(text: widget.cliente?.dirCliente ?? '');
    notasCtrl = TextEditingController(text: widget.cliente?.notasCliente ?? '');
    contactoCtrl = TextEditingController(text: widget.cliente?.contactoCliente ?? '');
    cargocontCtrl = TextEditingController(text: widget.cliente?.cargocontCliente ?? '');

    tipoDocSel = widget.cliente?.tipodocCliente;
    tipopersSel = widget.cliente?.tipopersCliente ?? 'N';
    municIdSel = widget.cliente?.municId;
    asesorIdSel = widget.cliente?.asesorId;
    estadoCliente = widget.cliente?.estadoCliente ?? true;
    recordarCliente = widget.cliente?.recordarCliente ?? false;

    _cargarMunicipios();
    _cargarAsesores();

    if (!esEdicion) {
      _cargarSiguienteId();
    } else {
      cargandoId = false;
    }
  }

  Future<void> _cargarMunicipios() async {
    try {
      final res = await repo.listarMunicipios();
      if (!mounted) return;
      setState(() {
        municipios = res;
        cargandoMunicipios = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => cargandoMunicipios = false);
      _toast('Error cargando municipios: $e');
    }
  }

  Future<void> _cargarAsesores() async {
    try {
      final res = await repo.listarAsesores(soloActivos: true);
      if (!mounted) return;
      setState(() {
        asesores = res;
        cargandoAsesores = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => cargandoAsesores = false);
    }
  }

  Future<void> _cargarSiguienteId() async {
    try {
      final nextId = await repo.obtenerSiguienteIdCliente();
      if (!mounted) return;
      idCtrl.text = nextId.toString();
      setState(() => cargandoId = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => cargandoId = false);
      _toast('No se pudo cargar el siguiente ID: $e');
    }
  }

  @override
  void dispose() {
    idCtrl.dispose();
    nombreCtrl.dispose();
    docCtrl.dispose();
    telCtrl.dispose();
    correoCtrl.dispose();
    dirCtrl.dispose();
    notasCtrl.dispose();
    contactoCtrl.dispose();
    cargocontCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String? _validarCorreo(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s);
    return ok ? null : 'Correo inválido';
  }

  String? _validarId(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Requerido';
    final n = int.tryParse(s);
    if (n == null) return 'Debe ser numérico';
    if (n <= 0) return 'Debe ser mayor que 0';
    return null;
  }

  String? _limpiarONull(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _guardar() async {
    if (guardando) return;

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final doc = _limpiarONull(docCtrl.text);
    if (doc != null && (tipoDocSel == null || tipoDocSel!.trim().isEmpty)) {
      _toast('Selecciona el tipo de documento.');
      return;
    }

    final idNum = int.tryParse(idCtrl.text.trim());
    if (idNum == null || idNum <= 0) {
      _toast('El ID debe ser un número válido mayor que 0.');
      return;
    }

    setState(() => guardando = true);

    try {
      if (esEdicion) {
        final c = Cliente(
          id: widget.cliente!.id,
          nombreCliente: nombreCtrl.text.trim(),
          tipopersCliente: tipopersSel,
          tipodocCliente: (tipoDocSel?.trim().isEmpty ?? true) ? null : tipoDocSel!.trim(),
          docCliente: doc,
          telCliente: _limpiarONull(telCtrl.text),
          correoCliente: _limpiarONull(correoCtrl.text),
          dirCliente: _limpiarONull(dirCtrl.text),
          municId: municIdSel,
          notasCliente: _limpiarONull(notasCtrl.text),
          contactoCliente: _limpiarONull(contactoCtrl.text),
          cargocontCliente: _limpiarONull(cargocontCtrl.text),
          asesorId: asesorIdSel,
          estadoCliente: estadoCliente,
          recordarCliente: recordarCliente,
        );
        await repo.actualizarCliente(widget.cliente!.id, c);
        if (!mounted) return;
        Navigator.pop(context, widget.cliente!.id);
      } else {
        final existe = await repo.existeClienteId(idNum);
        if (existe) {
          if (!mounted) return;
          setState(() => guardando = false);
          _toast('Ya existe un cliente con ese ID. Cambia el ID e intenta de nuevo.');
          return;
        }
        final cNuevo = Cliente(
          id: idNum,
          nombreCliente: nombreCtrl.text.trim(),
          tipopersCliente: tipopersSel,
          tipodocCliente: (tipoDocSel?.trim().isEmpty ?? true) ? null : tipoDocSel!.trim(),
          docCliente: doc,
          telCliente: _limpiarONull(telCtrl.text),
          correoCliente: _limpiarONull(correoCtrl.text),
          dirCliente: _limpiarONull(dirCtrl.text),
          municId: municIdSel,
          notasCliente: _limpiarONull(notasCtrl.text),
          contactoCliente: _limpiarONull(contactoCtrl.text),
          cargocontCliente: _limpiarONull(cargocontCtrl.text),
          asesorId: asesorIdSel,
          estadoCliente: estadoCliente,
          recordarCliente: recordarCliente,
        );
        await repo.crearCliente(cNuevo);
        if (!mounted) return;
        Navigator.pop(context, idNum);
      }
    } catch (e) {
      _toast('Error guardando: $e');
    } finally {
      if (mounted) setState(() => guardando = false);
    }
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

  Widget _fila2(Widget a, Widget b) {
    final w = MediaQuery.of(context).size.width;
    if (w < 700) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [a, const SizedBox(height: 12), b],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 16),
        Expanded(child: b),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final municipioInicial = widget.cliente?.nombreMunicipio ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? 'Editar cliente' : 'Nuevo cliente'),
        actions: [
          if (guardando)
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
              onPressed: cargandoId ? null : _guardar,
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── 1. Datos principales ─────────────────────────────────────
                _seccion('Datos principales', [
                  _fila2(
                    TextFormField(
                      controller: idCtrl,
                      enabled: !esEdicion,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: esEdicion ? 'ID' : 'ID sugerido',
                        border: const OutlineInputBorder(),
                        helperText: esEdicion ? null : 'Puedes cambiarlo si es necesario',
                        suffixIcon: cargandoId
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                      validator: _validarId,
                    ),
                    TextFormField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Tipo persona + Tipo doc + Documento
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: DropdownButtonFormField<String>(
                          value: tipopersSel,
                          decoration: const InputDecoration(
                            labelText: 'Tipo persona',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'N', child: Text('Natural')),
                            DropdownMenuItem(value: 'J', child: Text('Jurídica')),
                          ],
                          onChanged: (v) => setState(() => tipopersSel = v ?? 'N'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: tiposDocNormalizados.contains(tipoDocSel) ? tipoDocSel : null,
                          decoration: const InputDecoration(
                            labelText: 'Tipo documento',
                            border: OutlineInputBorder(),
                          ),
                          items: tiposDocNormalizados
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) => setState(() => tipoDocSel = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: docCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Documento',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Autocomplete<Municipio>(
                    initialValue: TextEditingValue(text: municipioInicial),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      final query = textEditingValue.text.trim().toLowerCase();
                      if (query.isEmpty) return municipios.take(20);
                      return municipios
                          .where((m) => m.nombreMunic.toLowerCase().contains(query))
                          .take(20);
                    },
                    displayStringForOption: (Municipio m) => m.nombreMunic,
                    onSelected: (Municipio m) => setState(() => municIdSel = m.id),
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      if (municipioInicial.isNotEmpty && textEditingController.text.isEmpty) {
                        textEditingController.text = municipioInicial;
                      }
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Municipio',
                          border: const OutlineInputBorder(),
                          suffixIcon: cargandoMunicipios
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : const Icon(Icons.search),
                        ),
                        validator: (_) {
                          final texto = textEditingController.text.trim();
                          if (texto.isEmpty) return null;
                          if (municIdSel == null) return 'Selecciona un municipio válido';
                          return null;
                        },
                        onChanged: (value) {
                          final query = value.trim().toLowerCase();
                          Municipio? exacto;
                          for (final m in municipios) {
                            if (m.nombreMunic.toLowerCase() == query) {
                              exacto = m;
                              break;
                            }
                          }
                          setState(() => municIdSel = exacto?.id);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: asesores.any((a) => a.id == asesorIdSel) ? asesorIdSel : null,
                    decoration: InputDecoration(
                      labelText: 'Asesor asignado',
                      border: const OutlineInputBorder(),
                      suffixIcon: cargandoAsesores
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— Sin asesor —')),
                      ...asesores.map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.nombreAsesor, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setState(() => asesorIdSel = v),
                  ),
                ]),

                // ── 2. Contacto ──────────────────────────────────────────────
                _seccion('Contacto', [
                  _fila2(
                    TextFormField(
                      controller: telCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    TextFormField(
                      controller: correoCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validarCorreo,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dirCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dirección',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _fila2(
                    TextFormField(
                      controller: contactoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Persona de contacto',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    TextFormField(
                      controller: cargocontCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Cargo del contacto',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ]),

                // ── 3. Notas y estado ────────────────────────────────────────
                _seccion('Notas y estado', [
                  TextFormField(
                    controller: notasCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notas / Observaciones',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: estadoCliente,
                    onChanged: (v) => setState(() => estadoCliente = v),
                    title: const Text('Cliente activo'),
                    subtitle: Text(estadoCliente ? 'Activo' : 'Inactivo'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: recordarCliente,
                    onChanged: (v) => setState(() => recordarCliente = v),
                    title: const Text('Recordar cliente'),
                    subtitle: const Text('Marcar para seguimiento especial'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ]),

                FilledButton.icon(
                  onPressed: (guardando || cargandoId) ? null : _guardar,
                  icon: guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(guardando ? 'Guardando...' : 'Guardar cliente'),
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
