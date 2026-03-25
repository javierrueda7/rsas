import 'package:flutter/material.dart';
import '../../datos/catalogos.dart';
import '../../datos/repositorio_catalogos.dart';

class FormProducto extends StatefulWidget {
  final Producto? producto;
  const FormProducto({super.key, this.producto});

  @override
  State<FormProducto> createState() => _FormProductoState();
}

class _FormProductoState extends State<FormProducto> {
  final _formKey = GlobalKey<FormState>();
  final repo = RepositorioCatalogos();

  bool cargando = true;
  bool guardando = false;
  bool cargandoId = true;

  late final TextEditingController idCtrl;
  late final TextEditingController nombreCtrl;
  late final TextEditingController comisionCtrl;
  late final TextEditingController porcomCtrl;
  late final TextEditingController descCtrl;
  late final TextEditingController porcadCtrl;
  late final TextEditingController obsCtrl;

  List<Ramo> ramos = [];
  List<Aseguradora> aseguradoras = [];

  Ramo? ramoSel;
  Aseguradora? asegSel;

  bool estadoProd = true;

  bool get esEdicion => widget.producto != null;

  @override
  void initState() {
    super.initState();

    final p = widget.producto;

    idCtrl = TextEditingController(
      text: esEdicion ? widget.producto!.id.toString() : '',
    );
    nombreCtrl = TextEditingController(text: p?.nombreProd ?? '');
    estadoProd = p?.estadoProd ?? true;

    comisionCtrl = TextEditingController(text: _numToText(p?.comisionProd));
    porcomCtrl = TextEditingController(text: _numToText(p?.porcomProd));
    descCtrl = TextEditingController(text: p?.descProd ?? '');
    porcadCtrl = TextEditingController(text: _numToText(p?.porcadProd));
    obsCtrl = TextEditingController(text: p?.obsProd ?? '');

    _cargar();
  }

  @override
  void dispose() {
    idCtrl.dispose();
    nombreCtrl.dispose();
    comisionCtrl.dispose();
    porcomCtrl.dispose();
    descCtrl.dispose();
    porcadCtrl.dispose();
    obsCtrl.dispose();
    super.dispose();
  }

  String _numToText(num? n) => n == null ? '' : n.toString();

  String? _limpiarONull(String v) {
    final t = v.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.isEmpty ? null : t;
  }

  String _limpiarObligatorio(String v) {
    return v.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _validarId(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Requerido';
    final n = int.tryParse(s);
    if (n == null) return 'Debe ser numérico';
    if (n <= 0) return 'Debe ser mayor que 0';
    return null;
  }

  num? _parseNumeroONull(String v) {
    final t = v.trim();
    if (t.isEmpty) return null;

    final limpio = t
        .replaceAll(RegExp(r'[^0-9,.\-]'), '')
        .replaceAll('.', '')
        .replaceAll(',', '.');

    return num.tryParse(limpio);
  }

  String? _validarNumeroOpcional(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;

    final limpio = t
        .replaceAll(RegExp(r'[^0-9,.\-]'), '')
        .replaceAll('.', '')
        .replaceAll(',', '.');

    final n = num.tryParse(limpio);
    if (n == null) return 'Valor inválido';
    return null;
  }

  Future<void> _cargar() async {
    try {
      final resultados = await Future.wait([
        repo.listarRamos(),
        repo.listarAseguradoras(),
        if (!esEdicion) repo.obtenerSiguienteIdProducto(),
      ]);

      ramos = resultados[0] as List<Ramo>;
      aseguradoras = resultados[1] as List<Aseguradora>;

      if (esEdicion) {
        final p = widget.producto!;

        final rOk = ramos.any((r) => r.id == p.ramoId);
        ramoSel = rOk ? ramos.firstWhere((r) => r.id == p.ramoId) : null;

        final aOk = aseguradoras.any((a) => a.id == p.aseguradoraId);
        asegSel = aOk ? aseguradoras.firstWhere((a) => a.id == p.aseguradoraId) : null;

        cargandoId = false;
      } else {
        final nextId = resultados[2] as int;
        idCtrl.text = nextId.toString();
        cargandoId = false;
      }

      if (!mounted) return;
      setState(() => cargando = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        cargando = false;
        cargandoId = false;
      });
      _toast('Error cargando catálogos: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _guardar() async {
    if (guardando) return;

    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (ramoSel == null) {
      _toast('Selecciona un ramo válido.');
      return;
    }
    if (asegSel == null) {
      _toast('Selecciona una aseguradora válida.');
      return;
    }

    final idTexto = idCtrl.text.trim();
    final idNum = int.tryParse(idTexto);

    if (idNum == null || idNum <= 0) {
      _toast('El ID debe ser un número válido mayor que 0.');
      return;
    }

    final nombre = _limpiarObligatorio(nombreCtrl.text);
    if (nombre.isEmpty) {
      _toast('El nombre es requerido.');
      return;
    }

    final comision = _parseNumeroONull(comisionCtrl.text);
    final porcom = _parseNumeroONull(porcomCtrl.text);
    final porcad = _parseNumeroONull(porcadCtrl.text);
    final desc = _limpiarONull(descCtrl.text);
    final obs = _limpiarONull(obsCtrl.text);

    setState(() => guardando = true);

    try {
      if (!esEdicion) {
        final existe = await repo.existeProductoId(idNum);
        if (existe) {
          _toast('Ya existe un producto con ese ID.');
          return;
        }
      }

      final p = Producto(
        id: esEdicion ? widget.producto!.id : idNum,
        nombreProd: nombre,
        ramoId: ramoSel!.id,
        aseguradoraId: asegSel!.id,
        estadoProd: estadoProd,
        comisionProd: comision,
        porcomProd: porcom,
        descProd: desc,
        porcadProd: porcad,
        obsProd: obs,
      );

      if (esEdicion) {
        await repo.actualizarProducto(widget.producto!.id, p);
      } else {
        await repo.crearProducto(p);
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
    if (cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final titulo = esEdicion ? 'Editar producto' : 'Nuevo producto';
    final ramoInicial = ramoSel?.nombreRamo ?? '';
    final asegInicial = asegSel?.nombreAseg ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
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
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AbsorbPointer(
                    absorbing: guardando,
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Datos del producto',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del producto *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final limpio = _limpiarONull(v ?? '');
                              return limpio == null ? 'Requerido' : null;
                            },
                          ),
                          const SizedBox(height: 12),

                          Autocomplete<Ramo>(
                            initialValue: TextEditingValue(text: ramoInicial),
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              final query = textEditingValue.text.trim().toLowerCase();
                              if (query.isEmpty) return ramos.take(20);
                              return ramos.where((r) {
                                return r.nombreRamo.toLowerCase().contains(query) ||
                                    r.id.toString().contains(query);
                              }).take(20);
                            },
                            displayStringForOption: (Ramo r) => r.nombreRamo,
                            onSelected: (Ramo r) {
                              setState(() => ramoSel = r);
                            },
                            fieldViewBuilder: (
                              context,
                              textEditingController,
                              focusNode,
                              onFieldSubmitted,
                            ) {
                              if (ramoInicial.isNotEmpty && textEditingController.text.isEmpty) {
                                textEditingController.text = ramoInicial;
                              }

                              return TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Ramo *',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.search),
                                ),
                                validator: (_) {
                                  final texto = textEditingController.text.trim();
                                  if (texto.isEmpty) return 'Requerido';
                                  if (ramoSel == null) return 'Selecciona un ramo válido';
                                  return null;
                                },
                                onChanged: (value) {
                                  final query = value.trim().toLowerCase();

                                  Ramo? exacto;
                                  for (final r in ramos) {
                                    if (r.nombreRamo.toLowerCase() == query ||
                                        r.id.toString() == query) {
                                      exacto = r;
                                      break;
                                    }
                                  }

                                  setState(() => ramoSel = exacto);
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          Autocomplete<Aseguradora>(
                            initialValue: TextEditingValue(text: asegInicial),
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              final query = textEditingValue.text.trim().toLowerCase();
                              if (query.isEmpty) return aseguradoras.take(20);
                              return aseguradoras.where((a) {
                                return a.nombreAseg.toLowerCase().contains(query) ||
                                    a.id.toString().contains(query);
                              }).take(20);
                            },
                            displayStringForOption: (Aseguradora a) => a.nombreAseg,
                            onSelected: (Aseguradora a) {
                              setState(() => asegSel = a);
                            },
                            fieldViewBuilder: (
                              context,
                              textEditingController,
                              focusNode,
                              onFieldSubmitted,
                            ) {
                              if (asegInicial.isNotEmpty && textEditingController.text.isEmpty) {
                                textEditingController.text = asegInicial;
                              }

                              return TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Aseguradora *',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.search),
                                ),
                                validator: (_) {
                                  final texto = textEditingController.text.trim();
                                  if (texto.isEmpty) return 'Requerido';
                                  if (asegSel == null) return 'Selecciona una aseguradora válida';
                                  return null;
                                },
                                onChanged: (value) {
                                  final query = value.trim().toLowerCase();

                                  Aseguradora? exacto;
                                  for (final a in aseguradoras) {
                                    if (a.nombreAseg.toLowerCase() == query ||
                                        a.id.toString() == query) {
                                      exacto = a;
                                      break;
                                    }
                                  }

                                  setState(() => asegSel = exacto);
                                },
                              );
                            },
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: comisionCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Comisión fija',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: _validarNumeroOpcional,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: porcomCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: '% Comisión',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: _validarNumeroOpcional,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: porcadCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: '% Comisión adicional',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: _validarNumeroOpcional,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          TextFormField(
                            controller: descCtrl,
                            maxLines: 2,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Descripción',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: obsCtrl,
                            maxLines: 2,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Observaciones',
                              border: OutlineInputBorder(),
                            ),
                            onFieldSubmitted: (_) => guardando ? null : _guardar(),
                          ),

                          const SizedBox(height: 12),

                          SwitchListTile.adaptive(
                            value: estadoProd,
                            onChanged: (v) => setState(() => estadoProd = v),
                            title: const Text('Activo'),
                            subtitle: const Text(
                              'Si está inactivo, puedes ocultarlo en los dropdowns.',
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
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
      ),
    );
  }
}