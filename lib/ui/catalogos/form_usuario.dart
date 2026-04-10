import 'package:flutter/material.dart';
import '../../datos/catalogos.dart';
import '../../datos/repositorio_catalogos.dart';

class FormUsuario extends StatefulWidget {
  final Usuario? usuario;
  const FormUsuario({super.key, this.usuario});

  @override
  State<FormUsuario> createState() => _FormUsuarioState();
}

class _FormUsuarioState extends State<FormUsuario> {
  final _formKey = GlobalKey<FormState>();
  final repo = RepositorioCatalogos();

  bool guardando = false;
  bool cargandoId = true;

  late final TextEditingController idCtrl;
  late final TextEditingController apodoCtrl;
  late final TextEditingController nombreCtrl;
  late final TextEditingController claveCtrl;

  String _rol = 'D';
  bool _estadoUsuario = true;

  // Roles disponibles: A=Administrador, D=Digitador
  static const _roles = [
    ('A', 'Administrador'),
    ('D', 'Digitador'),
  ];

  bool get esEdicion => widget.usuario != null;

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    idCtrl = TextEditingController(text: esEdicion ? u!.id.toString() : '');
    apodoCtrl = TextEditingController(text: u?.apodoUsuario ?? '');
    nombreCtrl = TextEditingController(text: u?.nombreUsuario ?? '');
    claveCtrl = TextEditingController();

    _rol = u?.rol.toUpperCase() ?? 'D';
    if (!_roles.any((r) => r.$1 == _rol)) _rol = 'D';
    _estadoUsuario = u?.estadoUsuario ?? true;

    if (!esEdicion) {
      _cargarSiguienteId();
    } else {
      cargandoId = false;
    }
  }

  @override
  void dispose() {
    idCtrl.dispose();
    apodoCtrl.dispose();
    nombreCtrl.dispose();
    claveCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarSiguienteId() async {
    try {
      final nextId = await repo.obtenerSiguienteIdUsuario();
      if (!mounted) return;
      idCtrl.text = nextId.toString();
    } catch (e) {
      _toast('No se pudo cargar el siguiente ID: $e');
    } finally {
      if (mounted) setState(() => cargandoId = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String? _validarId(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Requerido';
    final n = int.tryParse(s);
    if (n == null) return 'Debe ser numérico';
    if (n <= 0) return 'Debe ser mayor que 0';
    return null;
  }

  Future<void> _guardar() async {
    if (guardando) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final idNum = int.tryParse(idCtrl.text.trim());
    if (idNum == null || idNum <= 0) {
      _toast('El ID debe ser un número válido mayor que 0.');
      return;
    }

    final apodo = apodoCtrl.text.trim();
    final nombre = nombreCtrl.text.trim();
    final clave = claveCtrl.text;

    if (!esEdicion && clave.isEmpty) {
      _toast('La contraseña es requerida para usuarios nuevos.');
      return;
    }

    setState(() => guardando = true);
    try {
      if (!esEdicion) {
        if (await repo.existeUsuarioId(idNum)) {
          _toast('Ya existe un usuario con ese ID.');
          return;
        }
        if (await repo.existeApodoUsuario(apodo)) {
          _toast('Ya existe un usuario con ese apodo.');
          return;
        }
      } else {
        if (await repo.existeApodoUsuario(apodo, excludeId: widget.usuario!.id)) {
          _toast('Ya existe otro usuario con ese apodo.');
          return;
        }
      }

      final u = Usuario(
        id: esEdicion ? widget.usuario!.id : idNum,
        apodoUsuario: apodo,
        nombreUsuario: nombre,
        rol: _rol,
        claveUsuario: clave.isEmpty ? widget.usuario?.claveUsuario : clave,
        estadoUsuario: _estadoUsuario,
        asesorId: widget.usuario?.asesorId,
      );

      if (esEdicion) {
        await repo.actualizarUsuario(widget.usuario!.id, u);
      } else {
        await repo.crearUsuario(u);
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
            Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [a, const SizedBox(height: 12), b]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: a),
      const SizedBox(width: 16),
      Expanded(child: b),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? 'Editar usuario' : 'Nuevo usuario'),
        actions: [
          if (guardando)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
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
          constraints: const BoxConstraints(maxWidth: 700),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : null,
                      ),
                      validator: _validarId,
                    ),
                    TextFormField(
                      controller: apodoCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Usuario (apodo) *',
                        border: OutlineInputBorder(),
                        helperText: 'Nombre corto para iniciar sesión',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nombreCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                ]),

                _seccion('Acceso', [
                  TextFormField(
                    controller: claveCtrl,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: esEdicion ? 'Nueva contraseña (dejar vacío para no cambiar)' : 'Contraseña *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _rol,
                    decoration: const InputDecoration(
                      labelText: 'Rol *',
                      border: OutlineInputBorder(),
                    ),
                    items: _roles
                        .map((r) => DropdownMenuItem(value: r.$1, child: Text('${r.$1} — ${r.$2}')))
                        .toList(),
                    onChanged: (v) { if (v != null) setState(() => _rol = v); },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _estadoUsuario,
                    onChanged: (v) => setState(() => _estadoUsuario = v),
                    title: const Text('Usuario activo'),
                    subtitle: Text(_estadoUsuario ? 'Activo' : 'Inactivo'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ]),

                FilledButton.icon(
                  onPressed: (guardando || cargandoId) ? null : _guardar,
                  icon: guardando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(guardando ? 'Guardando...' : 'Guardar usuario'),
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
