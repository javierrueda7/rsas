import 'package:flutter/material.dart';
import '../../datos/catalogos.dart';
import '../../datos/repositorio_catalogos.dart';
import '../../utils/formatters.dart';

class FormAsesor extends StatefulWidget {
  final Asesor? asesor;
  const FormAsesor({super.key, this.asesor});

  @override
  State<FormAsesor> createState() => _FormAsesorState();
}

class _FormAsesorState extends State<FormAsesor> {
  final _formKey = GlobalKey<FormState>();
  final repo = RepositorioCatalogos();

  bool guardando = false;
  bool cargandoId = true;

  late final TextEditingController idCtrl;
  late final TextEditingController nombreCtrl;
  late final TextEditingController docCtrl;
  late final TextEditingController telCtrl;
  late final TextEditingController correoCtrl;
  late final TextEditingController porccomCtrl;

  final List<String> tiposDoc = const ['CC', 'CE', 'NIT', 'PAS', 'OTRO'];
  String? tipoDocSel;

  List<String> get tiposDocNormalizados =>
      tiposDoc.map((e) => e.trim().toUpperCase()).toSet().toList();

  bool estadoAsesor = true;

  bool get esEdicion => widget.asesor != null;

  @override
  void initState() {
    super.initState();

    idCtrl = TextEditingController(
      text: esEdicion ? widget.asesor!.id.toString() : '',
    );
    nombreCtrl = TextEditingController(text: widget.asesor?.nombreAsesor ?? '');
    docCtrl = TextEditingController(text: widget.asesor?.docAsesor ?? '');
    telCtrl = TextEditingController(text: widget.asesor?.telAsesor ?? '');
    correoCtrl = TextEditingController(text: widget.asesor?.correoAsesor ?? '');
    porccomCtrl = TextEditingController(
      text: widget.asesor?.porccomAsesor == null
          ? ''
          : Fmt.numCO(widget.asesor!.porccomAsesor, dec: 2),
    );

    final td = widget.asesor?.tipodocAsesor?.trim().toUpperCase();
    tipoDocSel = (td != null && tiposDocNormalizados.contains(td)) ? td : null;

    estadoAsesor = widget.asesor?.estadoAsesor ?? true;

    if (docCtrl.text.trim().isEmpty) {
      tipoDocSel = null;
    }

    docCtrl.addListener(() {
      final doc = docCtrl.text.trim();
      if (doc.isEmpty && tipoDocSel != null) {
        setState(() => tipoDocSel = null);
      }
    });

    if (!esEdicion) {
      _cargarSiguienteId();
    } else {
      cargandoId = false;
    }
  }

  @override
  void dispose() {
    idCtrl.dispose();
    nombreCtrl.dispose();
    docCtrl.dispose();
    telCtrl.dispose();
    correoCtrl.dispose();
    porccomCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarSiguienteId() async {
    try {
      final nextId = await repo.obtenerSiguienteIdAsesor();
      if (!mounted) return;
      idCtrl.text = nextId.toString();
      setState(() => cargandoId = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => cargandoId = false);
      _toast('No se pudo cargar el siguiente ID: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

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

  void _formatearPorcentaje() {
    final n = _parseNumeroONull(porccomCtrl.text);
    if (n == null) return;
    porccomCtrl.text = Fmt.numCO(n, dec: 2);
  }

  String? _validarCorreo(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s);
    return ok ? null : 'Correo inválido';
  }

  Future<void> _guardar() async {
    if (guardando) return;

    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final idTexto = idCtrl.text.trim();
    final idNum = int.tryParse(idTexto);

    if (idNum == null || idNum <= 0) {
      _toast('El ID debe ser un número válido mayor que 0.');
      return;
    }

    final doc = _limpiarONull(docCtrl.text);
    final tipo = (tipoDocSel?.trim().isEmpty ?? true) ? null : tipoDocSel!.trim();

    if (doc != null && tipo == null) {
      _toast('Selecciona el tipo de documento.');
      return;
    }

    setState(() => guardando = true);
    try {
      if (!esEdicion) {
        final existe = await repo.existeAsesorId(idNum);
        if (existe) {
          _toast('Ya existe un asesor con ese ID.');
          return;
        }
      }

      final a = Asesor(
        id: esEdicion ? widget.asesor!.id : idNum,
        nombreAsesor: _limpiarObligatorio(nombreCtrl.text),
        tipodocAsesor: doc == null ? null : tipo,
        docAsesor: doc,
        telAsesor: _limpiarONull(telCtrl.text),
        correoAsesor: _limpiarONull(correoCtrl.text),
        porccomAsesor: _parseNumeroONull(porccomCtrl.text),
        estadoAsesor: estadoAsesor,
      );

      if (esEdicion) {
        await repo.actualizarAsesor(widget.asesor!.id, a);
      } else {
        await repo.crearAsesor(a);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? 'Editar asesor' : 'Nuevo asesor'),
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
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                labelText: 'Nombre *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                final limpio = _limpiarONull(v ?? '');
                                return limpio == null ? 'Requerido' : null;
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    value: tiposDocNormalizados.contains(tipoDocSel)
                                        ? tipoDocSel
                                        : null,
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
                                    onChanged: (v) {
                                      setState(() => tipoDocSel = v);
                                      if ((v ?? '').trim().isEmpty) {
                                        docCtrl.text = '';
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: docCtrl,
                                    textInputAction: TextInputAction.next,
                                    keyboardType: TextInputType.text,
                                    decoration: const InputDecoration(
                                      labelText: 'Documento',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: porccomCtrl,
                              textInputAction: TextInputAction.next,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: '% comisión',
                                helperText: 'Ej: 70 o 70,5',
                                border: OutlineInputBorder(),
                              ),
                              onEditingComplete: () {
                                _formatearPorcentaje();
                                FocusScope.of(context).nextFocus();
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
                                    textInputAction: TextInputAction.next,
                                    keyboardType: TextInputType.phone,
                                    autofillHints: const [AutofillHints.telephoneNumber],
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
                                    textInputAction: TextInputAction.done,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.email],
                                    decoration: const InputDecoration(
                                      labelText: 'Correo',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: _validarCorreo,
                                    onFieldSubmitted: (_) => guardando ? null : _guardar(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              value: estadoAsesor,
                              onChanged: (v) => setState(() => estadoAsesor = v),
                              title: const Text('Asesor activo'),
                              subtitle: Text(estadoAsesor ? 'Activo' : 'Inactivo'),
                              contentPadding: EdgeInsets.zero,
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