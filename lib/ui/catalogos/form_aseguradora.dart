import 'package:flutter/material.dart';
import '../../datos/catalogos.dart';
import '../../datos/repositorio_catalogos.dart';

class FormAseguradora extends StatefulWidget {
  final Aseguradora? aseguradora;
  const FormAseguradora({super.key, this.aseguradora});

  @override
  State<FormAseguradora> createState() => _FormAseguradoraState();
}

class _FormAseguradoraState extends State<FormAseguradora> {
  final _formKey = GlobalKey<FormState>();
  final repo = RepositorioCatalogos();

  bool guardando = false;

  late final TextEditingController nombreCtrl;
  late final TextEditingController nitCtrl;
  late final TextEditingController claveCtrl; // ✅ nuevo

  bool estadoAseg = true;

  bool get esEdicion => widget.aseguradora != null;

  @override
  void initState() {
    super.initState();
    nombreCtrl = TextEditingController(text: widget.aseguradora?.nombreAseg ?? '');
    nitCtrl = TextEditingController(text: widget.aseguradora?.nitAseg ?? '');
    claveCtrl = TextEditingController(text: widget.aseguradora?.clave ?? ''); // ✅ carga al editar
    estadoAseg = widget.aseguradora?.estadoAseg ?? true;
  }

  @override
  void dispose() {
    nombreCtrl.dispose();
    nitCtrl.dispose();
    claveCtrl.dispose(); // ✅ nuevo
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String? _nitLimpioONull(String v) {
    final t = v.trim();
    if (t.isEmpty) return null;
    final limpio = t.replaceAll(RegExp(r'[\s\.\-]'), '');
    return limpio.isEmpty ? null : limpio;
  }

  String? _validarNit(String? v) {
    final nit = _nitLimpioONull(v ?? '');
    if (nit == null) return null;
    if (nit.length < 6) return 'NIT inválido';
    return null;
  }

  // ✅ clave opcional: si hay valor, debe ser alfanumérico (sin espacios ni símbolos)
  String? _claveLimpiaONull(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  String? _validarClave(String? v) {
    final c = _claveLimpiaONull(v ?? '');
    if (c == null) return null; // opcional

    final ok = RegExp(r'^[a-zA-Z0-9]+$').hasMatch(c);
    if (!ok) return 'Clave inválida (solo letras y números)';
    return null;
  }

  Future<void> _guardar() async {
    if (guardando) return;

    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => guardando = true);
    try {
      final a = Aseguradora(
        id: esEdicion ? widget.aseguradora!.id : 0,
        nombreAseg: nombreCtrl.text.trim(),
        nitAseg: _nitLimpioONull(nitCtrl.text),
        clave: _claveLimpiaONull(claveCtrl.text), // ✅ nuevo
        estadoAseg: estadoAseg,
      );

      if (esEdicion) {
        await repo.actualizarAseguradora(widget.aseguradora!.id, a);
      } else {
        await repo.crearAseguradora(a);
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
        title: Text(esEdicion ? 'Editar aseguradora' : 'Nueva aseguradora'),
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
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: nombreCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: nitCtrl,
                          decoration: const InputDecoration(
                            labelText: 'NIT (opcional)',
                            border: OutlineInputBorder(),
                          ),
                          validator: _validarNit,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),

                        // ✅ NUEVO: clave
                        TextFormField(
                          controller: claveCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Clave (opcional)',
                            border: OutlineInputBorder(),
                            helperText: 'Solo letras y números (sin espacios)',
                          ),
                          validator: _validarClave,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => guardando ? null : _guardar(),
                        ),
                        const SizedBox(height: 12),

                        SwitchListTile(
                          value: estadoAseg,
                          onChanged: (v) => setState(() => estadoAseg = v),
                          title: const Text('Activa'),
                          subtitle: const Text(
                            'Si está inactiva, puedes ocultarla en dropdowns (si luego filtras por estado).',
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 8),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
