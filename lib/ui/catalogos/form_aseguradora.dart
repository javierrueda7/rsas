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
  bool cargandoId = true;

  late final TextEditingController idCtrl;
  late final TextEditingController nombreCtrl;
  late final TextEditingController nitCtrl;
  late final TextEditingController claveCtrl;

  bool estadoAseg = true;

  bool get esEdicion => widget.aseguradora != null;

  @override
  void initState() {
    super.initState();

    idCtrl = TextEditingController(
      text: esEdicion ? widget.aseguradora!.id.toString() : '',
    );
    nombreCtrl = TextEditingController(
      text: widget.aseguradora?.nombreAseg ?? '',
    );
    nitCtrl = TextEditingController(
      text: widget.aseguradora?.nitAseg ?? '',
    );
    claveCtrl = TextEditingController(
      text: widget.aseguradora?.clave ?? '',
    );

    estadoAseg = widget.aseguradora?.estadoAseg ?? true;

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
    nitCtrl.dispose();
    claveCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarSiguienteId() async {
    try {
      final nextId = await repo.obtenerSiguienteIdAseguradora();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String? _limpiarONull(String v) {
    final limpio = v.replaceAll(RegExp(r'\s+'), ' ').trim();
    return limpio.isEmpty ? null : limpio;
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

  String? _nitLimpioONull(String v) {
    final t = v.replaceAll(RegExp(r'\s+'), ' ').trim();
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

  String? _claveLimpiaONull(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  String? _validarClave(String? v) {
    final c = _claveLimpiaONull(v ?? '');
    if (c == null) return null;
    final ok = RegExp(r'^[a-zA-Z0-9]+$').hasMatch(c);
    if (!ok) return 'Clave inválida (solo letras y números)';
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

    setState(() => guardando = true);

    try {
      if (!esEdicion) {
        final existe = await repo.existeAseguradoraId(idNum);
        if (existe) {
          _toast('Ya existe una aseguradora con ese ID.');
          return;
        }
      }

      final a = Aseguradora(
        id: esEdicion ? widget.aseguradora!.id : idNum,
        nombreAseg: _limpiarObligatorio(nombreCtrl.text),
        nitAseg: _nitLimpioONull(nitCtrl.text),
        clave: _claveLimpiaONull(claveCtrl.text),
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
                                        strokeWidth: 2,
                                      ),
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
                          validator: (v) {
                            final limpio = _limpiarONull(v ?? '');
                            return limpio == null ? 'Requerido' : null;
                          },
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
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