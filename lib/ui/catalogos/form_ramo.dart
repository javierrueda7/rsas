import 'package:flutter/material.dart';
import '../../datos/catalogos.dart';
import '../../datos/repositorio_catalogos.dart';

class FormRamo extends StatefulWidget {
  final Ramo? ramo;
  const FormRamo({super.key, this.ramo});

  @override
  State<FormRamo> createState() => _FormRamoState();
}

class _FormRamoState extends State<FormRamo> {
  final _formKey = GlobalKey<FormState>();
  final repo = RepositorioCatalogos();

  bool guardando = false;
  bool cargandoId = true;

  late final TextEditingController idCtrl;
  late final TextEditingController nombreCtrl;
  late final TextEditingController obsCtrl;
  late final TextEditingController porcomCtrl;

  bool estadoRamo = true;

  bool get esEdicion => widget.ramo != null;

  @override
  void initState() {
    super.initState();

    idCtrl = TextEditingController(
      text: esEdicion ? widget.ramo!.id.toString() : '',
    );
    nombreCtrl = TextEditingController(text: widget.ramo?.nombreRamo ?? '');
    obsCtrl = TextEditingController(text: widget.ramo?.obsRamo ?? '');

    final por = widget.ramo?.porcomBaseRamo ?? 100;
    porcomCtrl = TextEditingController(text: por.toString());

    estadoRamo = widget.ramo?.estadoRamo ?? true;

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
    obsCtrl.dispose();
    porcomCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarSiguienteId() async {
    try {
      final nextId = await repo.obtenerSiguienteIdRamo();
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

  num _parseNumConDefault100(String s) {
    final t = s.trim();
    if (t.isEmpty) return 100;
    final limpio = t
        .replaceAll(RegExp(r'[^0-9,.\-]'), '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    return num.tryParse(limpio) ?? 100;
  }

  String? _validarPorcom(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final limpio = t
        .replaceAll(RegExp(r'[^0-9,.\-]'), '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    final n = num.tryParse(limpio);
    if (n == null) return 'Valor inválido';
    if (n < 0) return 'No puede ser negativo';
    return null;
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

    final nombre = _limpiarObligatorio(nombreCtrl.text);
    if (nombre.isEmpty) {
      _toast('El nombre es requerido.');
      return;
    }

    final porcom = _parseNumConDefault100(porcomCtrl.text);

    setState(() => guardando = true);
    try {
      if (!esEdicion) {
        final existe = await repo.existeRamoId(idNum);
        if (existe) {
          _toast('Ya existe un ramo con ese ID.');
          return;
        }
      }

      final r = Ramo(
        id: esEdicion ? widget.ramo!.id : idNum,
        nombreRamo: nombre,
        estadoRamo: estadoRamo,
        obsRamo: _limpiarONull(obsCtrl.text),
        porcomBaseRamo: porcom,
      );

      if (esEdicion) {
        await repo.actualizarRamo(widget.ramo!.id, r);
      } else {
        await repo.crearRamo(r);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? 'Editar ramo' : 'Nuevo ramo'),
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
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── 1. Identificación ────────────────────────────────────────
                _seccion('Identificación', [
                  _fila2(
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
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                      validator: _validarId,
                    ),
                    TextFormField(
                      controller: nombreCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del ramo *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final nombre = _limpiarObligatorio(v ?? '');
                        return nombre.isEmpty ? 'Requerido' : null;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: porcomCtrl,
                    textInputAction: TextInputAction.next,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '% Base comisión',
                      helperText: 'Si lo dejas vacío, se guarda como 100',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validarPorcom,
                  ),
                ]),

                // ── 2. Observaciones ─────────────────────────────────────────
                _seccion('Observaciones', [
                  TextFormField(
                    controller: obsCtrl,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: estadoRamo,
                    onChanged: (v) => setState(() => estadoRamo = v),
                    title: const Text('Activo'),
                    subtitle: Text(estadoRamo ? 'Activo' : 'Inactivo'),
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
                    child: Text(guardando ? 'Guardando...' : 'Guardar ramo'),
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
