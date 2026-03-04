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

  late final TextEditingController nombreCtrl;
  late final TextEditingController docCtrl;
  late final TextEditingController telCtrl;
  late final TextEditingController correoCtrl;
  late final TextEditingController dirCtrl;
  late final TextEditingController ciudadCtrl;
  late final TextEditingController notasCtrl;

  final List<String> tiposDoc = const ['CC', 'CE', 'NIT', 'PAS', 'OTRO'];
  String? tipoDocSel;

  bool get esEdicion => widget.cliente != null;

  @override
  void initState() {
    super.initState();
    nombreCtrl = TextEditingController(text: widget.cliente?.nombreCliente ?? '');
    docCtrl = TextEditingController(text: widget.cliente?.docCliente ?? '');
    telCtrl = TextEditingController(text: widget.cliente?.telCliente ?? '');
    correoCtrl = TextEditingController(text: widget.cliente?.correoCliente ?? '');
    dirCtrl = TextEditingController(text: widget.cliente?.dirCliente ?? '');
    ciudadCtrl = TextEditingController(text: widget.cliente?.ciudadCliente ?? '');
    notasCtrl = TextEditingController(text: widget.cliente?.notasCliente ?? '');
    tipoDocSel = widget.cliente?.tipodocCliente;
  }

  @override
  void dispose() {
    nombreCtrl.dispose();
    docCtrl.dispose();
    telCtrl.dispose();
    correoCtrl.dispose();
    dirCtrl.dispose();
    ciudadCtrl.dispose();
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

    setState(() => guardando = true);

    try {
      if (esEdicion) {
        final c = Cliente(
          id: widget.cliente!.id,
          nombreCliente: nombreCtrl.text.trim(),
          tipodocCliente: (tipoDocSel?.trim().isEmpty ?? true) ? null : tipoDocSel!.trim(),
          docCliente: doc,
          telCliente: _limpiarONull(telCtrl.text),
          correoCliente: _limpiarONull(correoCtrl.text),
          dirCliente: _limpiarONull(dirCtrl.text),
          ciudadCliente: _limpiarONull(ciudadCtrl.text),
          notasCliente: _limpiarONull(notasCtrl.text),
        );
        await repo.actualizarCliente(widget.cliente!.id, c);
      } else {
        // 👇 id lo genera la base de datos
        final cNuevo = Cliente(
          id: 0, // valor dummy (no se usa en insert)
          nombreCliente: nombreCtrl.text.trim(),
          tipodocCliente: (tipoDocSel?.trim().isEmpty ?? true) ? null : tipoDocSel!.trim(),
          docCliente: doc,
          telCliente: _limpiarONull(telCtrl.text),
          correoCliente: _limpiarONull(correoCtrl.text),
          dirCliente: _limpiarONull(dirCtrl.text),
          ciudadCliente: _limpiarONull(ciudadCtrl.text),
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
                                    value: tipoDocSel,
                                    decoration: const InputDecoration(
                                      labelText: 'Tipo de documento',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: tiposDoc.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
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
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: ciudadCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Ciudad',
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
