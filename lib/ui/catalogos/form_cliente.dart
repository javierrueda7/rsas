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

  late final TextEditingController idCtrl;
  late final TextEditingController nombreCtrl;
  late final TextEditingController docCtrl;
  late final TextEditingController telCtrl;
  late final TextEditingController correoCtrl;
  late final TextEditingController dirCtrl;
  late final TextEditingController notasCtrl;

  final List<String> tiposDoc = const ['CC', 'CE', 'NIT', 'PAS', 'OTRO'];
  String? tipoDocSel;

  List<String> get tiposDocNormalizados =>
      tiposDoc.map((e) => e.trim().toUpperCase()).toSet().toList();

  List<Municipio> municipios = [];
  int? municIdSel;

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

    tipoDocSel = widget.cliente?.tipodocCliente;
    municIdSel = widget.cliente?.municId;

    _cargarMunicipios();

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

    final idTexto = idCtrl.text.trim();
    final idNum = int.tryParse(idTexto);

    if (idNum == null || idNum <= 0) {
      _toast('El ID debe ser un número válido mayor que 0.');
      return;
    }

    setState(() => guardando = true);

    try {
      if (!esEdicion) {
        final existe = await repo.existeClienteId(idNum);
        if (existe) {
          _toast('Ya existe un cliente con ese ID.');
          return;
        }
      }

      if (esEdicion) {
        final c = Cliente(
          id: widget.cliente!.id,
          nombreCliente: nombreCtrl.text.trim(),
          tipopersCliente: widget.cliente?.tipopersCliente ?? 'N',
          tipodocCliente: (tipoDocSel?.trim().isEmpty ?? true) ? null : tipoDocSel!.trim(),
          docCliente: doc,
          telCliente: _limpiarONull(telCtrl.text),
          correoCliente: _limpiarONull(correoCtrl.text),
          dirCliente: _limpiarONull(dirCtrl.text),
          municId: municIdSel,
          notasCliente: _limpiarONull(notasCtrl.text),
          contactoCliente: widget.cliente?.contactoCliente,
          cargocontCliente: widget.cliente?.cargocontCliente,
          asesorId: widget.cliente?.asesorId,
          estadoCliente: widget.cliente?.estadoCliente ?? true,
          recordarCliente: widget.cliente?.recordarCliente ?? false,
        );
        await repo.actualizarCliente(widget.cliente!.id, c);
      } else {
        final cNuevo = Cliente(
          id: idNum,
          nombreCliente: nombreCtrl.text.trim(),
          tipopersCliente: 'N',
          tipodocCliente: (tipoDocSel?.trim().isEmpty ?? true) ? null : tipoDocSel!.trim(),
          docCliente: doc,
          telCliente: _limpiarONull(telCtrl.text),
          correoCliente: _limpiarONull(correoCtrl.text),
          dirCliente: _limpiarONull(dirCtrl.text),
          municId: municIdSel,
          notasCliente: _limpiarONull(notasCtrl.text),
        );
        await repo.crearCliente(cNuevo);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _toast('Error guardando: $e');
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final municipioInicial = widget.cliente?.nombreMunicipio ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? 'Editar cliente' : 'Nuevo cliente'),
        actions: [
          TextButton.icon(
            onPressed: guardando ? null : _guardar,
            icon: const Icon(Icons.save),
            label: Text(guardando ? 'Guardando...' : 'Guardar'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Datos principales',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: idCtrl,
                              enabled: !esEdicion,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: esEdicion ? 'ID' : 'ID sugerido',
                                border: const OutlineInputBorder(),
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
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: nombreCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nombre *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    value: tiposDocNormalizados.contains(tipoDocSel) ? tipoDocSel : null,
                                    decoration: const InputDecoration(
                                      labelText: 'Tipo de documento',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: tiposDocNormalizados
                                        .map(
                                          (t) => DropdownMenuItem<String>(
                                            value: t,
                                            child: Text(t),
                                          ),
                                        )
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

                                if (query.isEmpty) {
                                  return municipios.take(20);
                                }

                                return municipios.where((m) {
                                  return m.nombreMunic.toLowerCase().contains(query);
                                }).take(20);
                              },
                              displayStringForOption: (Municipio m) => m.nombreMunic,
                              onSelected: (Municipio m) {
                                setState(() {
                                  municIdSel = m.id;
                                });
                              },
                              fieldViewBuilder: (
                                context,
                                textEditingController,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                if (municipioInicial.isNotEmpty &&
                                    textEditingController.text.isEmpty) {
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
                                    if (municIdSel == null) {
                                      return 'Selecciona un municipio válido';
                                    }
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

                                    setState(() {
                                      municIdSel = exacto?.id;
                                    });
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Contacto',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: telCtrl,
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(
                                      labelText: 'Teléfono',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: correoCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      labelText: 'Correo',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: _validarCorreo,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: dirCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Dirección',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Notas',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: notasCtrl,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Notas / Observaciones',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: guardando ? null : _guardar,
                        icon: guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: Text(guardando ? 'Guardando...' : 'Guardar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}