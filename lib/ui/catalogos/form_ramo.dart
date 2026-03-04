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

  late final TextEditingController nombreCtrl;
  late final TextEditingController obsCtrl;     // ✅ NUEVO
  late final TextEditingController porcomCtrl;  // ✅ NUEVO

  bool estadoRamo = true;

  bool get esEdicion => widget.ramo != null;

  @override
  void initState() {
    super.initState();
    nombreCtrl = TextEditingController(text: widget.ramo?.nombreRamo ?? '');
    obsCtrl = TextEditingController(text: widget.ramo?.obsRamo ?? '');

    // ✅ default 100 si es nuevo
    final por = widget.ramo?.porcomBaseRamo ?? 100;
    porcomCtrl = TextEditingController(text: por.toString());

    estadoRamo = widget.ramo?.estadoRamo ?? true;
  }

  @override
  void dispose() {
    nombreCtrl.dispose();
    obsCtrl.dispose();
    porcomCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Normaliza espacios: "  Seguro   Vida " -> "Seguro Vida"
  String _normalizarNombre(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

  num _parseNumConDefault100(String s) {
    final t = s.trim();
    if (t.isEmpty) return 100;

    // permite "10", "10.5", "10,5"
    final limpio = t.replaceAll('.', '').replaceAll(',', '.');
    return num.tryParse(limpio) ?? 100;
  }

  Future<void> _guardar() async {
    if (guardando) return;

    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final nombre = _normalizarNombre(nombreCtrl.text);
    if (nombre.isEmpty) {
      _toast('El nombre es requerido.');
      return;
    }

    final porcom = _parseNumConDefault100(porcomCtrl.text);

    setState(() => guardando = true);
    try {
      final r = Ramo(
        id: esEdicion ? widget.ramo!.id : 0,
        nombreRamo: nombre,
        estadoRamo: estadoRamo,

        // ✅ NUEVO
        obsRamo: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
        porcomBaseRamo: porcom, // default 100 si quedó vacío o inválido
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? 'Editar ramo' : 'Nuevo ramo'),
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
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del ramo *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final nombre = _normalizarNombre(v ?? '');
                            return nombre.isEmpty ? 'Requerido' : null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // ✅ NUEVO: % base comisión
                        TextFormField(
                          controller: porcomCtrl,
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '% base comisión',
                            helperText: 'Si lo dejas vacío, se guarda como 100',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ✅ NUEVO: observaciones
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
                          subtitle: const Text(
                            'Si está inactivo, no debería aparecer en dropdowns (si lo filtras).',
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