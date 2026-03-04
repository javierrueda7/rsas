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

  late final TextEditingController nombreCtrl;

  // existentes
  late final TextEditingController comisionCtrl;
  late final TextEditingController porcomCtrl;

  // ✅ nuevos
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

    nombreCtrl = TextEditingController(text: p?.nombreProd ?? '');
    estadoProd = p?.estadoProd ?? true;

    comisionCtrl = TextEditingController(text: _numToText(p?.comisionProd));
    porcomCtrl = TextEditingController(text: _numToText(p?.porcomProd));

    // ✅ nuevos
    descCtrl = TextEditingController(text: p?.descProd ?? '');
    porcadCtrl = TextEditingController(text: _numToText(p?.porcadProd));
    obsCtrl = TextEditingController(text: p?.obsProd ?? '');

    _cargar();
  }

  @override
  void dispose() {
    nombreCtrl.dispose();
    comisionCtrl.dispose();
    porcomCtrl.dispose();
    descCtrl.dispose();
    porcadCtrl.dispose();
    obsCtrl.dispose();
    super.dispose();
  }

  String _numToText(num? n) => n == null ? '' : n.toString();

  num? _parseNumeroONull(String v) {
    final t = v.trim();
    if (t.isEmpty) return null;

    final limpio = t
        .replaceAll(RegExp(r'[^0-9,.\-]'), '')
        .replaceAll('.', '')
        .replaceAll(',', '.');

    return num.tryParse(limpio);
  }

  String? _textToNull(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _cargar() async {
    try {
      final res = await Future.wait([
        repo.listarRamos(),
        repo.listarAseguradoras(),
      ]);

      ramos = res[0] as List<Ramo>;
      aseguradoras = res[1] as List<Aseguradora>;

      if (esEdicion) {
        final p = widget.producto!;

        final rOk = ramos.any((r) => r.id == p.ramoId);
        ramoSel = rOk ? ramos.firstWhere((r) => r.id == p.ramoId) : null;

        final aOk = aseguradoras.any((a) => a.id == p.aseguradoraId);
        asegSel = aOk ? aseguradoras.firstWhere((a) => a.id == p.aseguradoraId) : null;
      }

      if (!mounted) return;
      setState(() => cargando = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => cargando = false);
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
      _toast('Selecciona un ramo.');
      return;
    }
    if (asegSel == null) {
      _toast('Selecciona una aseguradora.');
      return;
    }

    final comision = _parseNumeroONull(comisionCtrl.text);
    final porcom = _parseNumeroONull(porcomCtrl.text);

    // ✅ nuevos
    final porcad = _parseNumeroONull(porcadCtrl.text);
    final desc = _textToNull(descCtrl.text);
    final obs = _textToNull(obsCtrl.text);

    setState(() => guardando = true);

    try {
      final p = Producto(
        id: esEdicion ? widget.producto!.id : 0,
        nombreProd: nombreCtrl.text.trim(),
        ramoId: ramoSel!.id,
        aseguradoraId: asegSel!.id,
        estadoProd: estadoProd,

        comisionProd: comision,
        porcomProd: porcom,

        // ✅ nuevos
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
                            controller: nombreCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del producto *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          ),
                          const SizedBox(height: 12),

                          DropdownButtonFormField<Ramo>(
                            value: ramoSel,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Ramo *',
                              border: OutlineInputBorder(),
                            ),
                            items: ramos
                                .map((r) => DropdownMenuItem(
                                      value: r,
                                      child: Text(r.nombreRamo, overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => ramoSel = v),
                            validator: (v) => v == null ? 'Requerido' : null,
                          ),
                          const SizedBox(height: 12),

                          DropdownButtonFormField<Aseguradora>(
                            value: asegSel,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Aseguradora *',
                              border: OutlineInputBorder(),
                            ),
                            items: aseguradoras
                                .map((a) => DropdownMenuItem(
                                      value: a,
                                      child: Text(a.nombreAseg, overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => asegSel = v),
                            validator: (v) => v == null ? 'Requerido' : null,
                          ),

                          const SizedBox(height: 12),

                          // existentes
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: comisionCtrl,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Comisión fija',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: porcomCtrl,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: '% Comisión',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: porcadCtrl,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: '% Comisión adicional',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          // ✅ nuevos
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
                            subtitle: const Text('Si está inactivo, puedes ocultarlo en los dropdowns.'),
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