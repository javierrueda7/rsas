import 'package:flutter/material.dart';
import '../datos/repositorio_catalogos.dart';

/// Flujo de 3 pasos:
///  1. Ingresa tu usuario (apodo)
///  2. Verifica tu correo electrónico registrado
///  3. Escribe y confirma la nueva contraseña
class PaginaRecuperarClave extends StatefulWidget {
  const PaginaRecuperarClave({super.key});

  @override
  State<PaginaRecuperarClave> createState() => _PaginaRecuperarClaveState();
}

class _PaginaRecuperarClaveState extends State<PaginaRecuperarClave> {
  final _repo = RepositorioCatalogos();

  // Paso actual: 1, 2 ó 3
  int _paso = 1;
  bool _cargando = false;
  String? _error;

  // Datos verificados
  String _apodoVerificado = '';

  // Controladores paso 1
  final _apodoCtrl = TextEditingController();

  // Controladores paso 2
  final _correoCtrl = TextEditingController();

  // Controladores paso 3
  final _claveCtrl = TextEditingController();
  final _claveConfCtrl = TextEditingController();
  bool _ocultarClave = true;
  bool _ocultarClaveConf = true;

  // Form keys
  final _fk1 = GlobalKey<FormState>();
  final _fk2 = GlobalKey<FormState>();
  final _fk3 = GlobalKey<FormState>();

  @override
  void dispose() {
    _apodoCtrl.dispose();
    _correoCtrl.dispose();
    _claveCtrl.dispose();
    _claveConfCtrl.dispose();
    super.dispose();
  }

  void _setError(String? msg) => setState(() => _error = msg);

  // ─── Paso 1: verificar que el apodo exista ────────────────────────────────

  Future<void> _verificarApodo() async {
    if (!(_fk1.currentState?.validate() ?? false)) return;
    setState(() { _cargando = true; _error = null; });
    try {
      final apodo = _apodoCtrl.text.trim();
      final existe = await _repo.existeApodoUsuario(apodo);
      if (!mounted) return;
      if (!existe) {
        _setError('No se encontró ningún usuario con ese nombre.');
      } else {
        setState(() { _paso = 2; _apodoVerificado = apodo; });
      }
    } catch (e) {
      _setError('Error al verificar: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ─── Paso 2: verificar correo registrado ─────────────────────────────────

  Future<void> _verificarCorreo() async {
    if (!(_fk2.currentState?.validate() ?? false)) return;
    setState(() { _cargando = true; _error = null; });
    try {
      final correo = _correoCtrl.text.trim().toLowerCase();
      final apodoOk = await _repo.verificarRecuperacion(_apodoVerificado, correo);
      if (!mounted) return;
      if (apodoOk == null) {
        _setError('El correo no coincide con el registrado para este usuario.');
      } else {
        setState(() => _paso = 3);
      }
    } catch (e) {
      _setError('Error al verificar: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ─── Paso 3: guardar nueva contraseña ────────────────────────────────────

  Future<void> _cambiarClave() async {
    if (!(_fk3.currentState?.validate() ?? false)) return;
    setState(() { _cargando = true; _error = null; });
    try {
      await _repo.cambiarClave(_apodoVerificado, _claveCtrl.text);
      if (!mounted) return;
      _mostrarExito();
    } catch (e) {
      _setError('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarExito() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
        title: const Text('¡Contraseña actualizada!'),
        content: const Text(
          'Tu contraseña se cambió correctamente. Ahora puedes iniciar sesión con la nueva contraseña.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // cierra diálogo
              Navigator.of(context).pop(); // vuelve al login
            },
            child: const Text('Ir al login'),
          ),
        ],
      ),
    );
  }

  // ─── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar contraseña'),
        leading: BackButton(
          onPressed: () {
            if (_paso > 1) {
              setState(() { _paso--; _error = null; });
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Stepper(pasoActual: _paso),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _paso == 1
                      ? _buildPaso1()
                      : _paso == 2
                          ? _buildPaso2()
                          : _buildPaso3(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Paso 1 ────────────────────────────────────────────────────────────────

  Widget _buildPaso1() {
    return _PasoCard(
      key: const ValueKey(1),
      icono: Icons.person_search_outlined,
      titulo: 'Ingresa tu usuario',
      descripcion: 'Escribe el nombre de usuario (apodo) con el que inicias sesión.',
      error: _error,
      child: Form(
        key: _fk1,
        child: Column(
          children: [
            TextFormField(
              controller: _apodoCtrl,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _cargando ? null : _verificarApodo(),
              decoration: const InputDecoration(
                labelText: 'Usuario *',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 20),
            _BtnSiguiente(
              label: 'Continuar',
              cargando: _cargando,
              onPressed: _verificarApodo,
            ),
          ],
        ),
      ),
    );
  }

  // ── Paso 2 ────────────────────────────────────────────────────────────────

  Widget _buildPaso2() {
    return _PasoCard(
      key: const ValueKey(2),
      icono: Icons.email_outlined,
      titulo: 'Verifica tu correo',
      descripcion:
          'Ingresa el correo electrónico registrado para el usuario "$_apodoVerificado".',
      error: _error,
      child: Form(
        key: _fk2,
        child: Column(
          children: [
            TextFormField(
              controller: _correoCtrl,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _cargando ? null : _verificarCorreo(),
              decoration: const InputDecoration(
                labelText: 'Correo electrónico *',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Requerido';
                if (!s.contains('@')) return 'Correo no válido';
                return null;
              },
            ),
            const SizedBox(height: 20),
            _BtnSiguiente(
              label: 'Verificar',
              cargando: _cargando,
              onPressed: _verificarCorreo,
            ),
          ],
        ),
      ),
    );
  }

  // ── Paso 3 ────────────────────────────────────────────────────────────────

  Widget _buildPaso3() {
    return _PasoCard(
      key: const ValueKey(3),
      icono: Icons.lock_reset_outlined,
      titulo: 'Nueva contraseña',
      descripcion: 'Elige una nueva contraseña para "$_apodoVerificado".',
      error: _error,
      child: Form(
        key: _fk3,
        child: Column(
          children: [
            TextFormField(
              controller: _claveCtrl,
              autofocus: true,
              obscureText: _ocultarClave,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Nueva contraseña *',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_ocultarClave
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _ocultarClave = !_ocultarClave),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Requerido';
                if (v.length < 4) return 'Mínimo 4 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _claveConfCtrl,
              obscureText: _ocultarClaveConf,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _cargando ? null : _cambiarClave(),
              decoration: InputDecoration(
                labelText: 'Confirmar contraseña *',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_ocultarClaveConf
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _ocultarClaveConf = !_ocultarClaveConf),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Requerido';
                if (v != _claveCtrl.text) return 'Las contraseñas no coinciden';
                return null;
              },
            ),
            const SizedBox(height: 20),
            _BtnSiguiente(
              label: 'Guardar nueva contraseña',
              cargando: _cargando,
              onPressed: _cambiarClave,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _Stepper extends StatelessWidget {
  final int pasoActual;
  const _Stepper({required this.pasoActual});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pasos = ['Usuario', 'Correo', 'Contraseña'];
    return Row(
      children: List.generate(pasos.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Línea conectora
          final completado = (i ~/ 2) < pasoActual - 1;
          return Expanded(
            child: Container(
              height: 2,
              color: completado ? cs.primary : cs.outlineVariant,
            ),
          );
        }
        final idx = i ~/ 2 + 1;
        final activo = idx == pasoActual;
        final completado = idx < pasoActual;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: completado || activo ? cs.primary : cs.surfaceContainerHighest,
              child: completado
                  ? Icon(Icons.check, size: 16, color: cs.onPrimary)
                  : Text(
                      '$idx',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: activo ? cs.onPrimary : cs.onSurfaceVariant,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              pasos[idx - 1],
              style: TextStyle(
                fontSize: 11,
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                color: activo ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _PasoCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final String? error;
  final Widget child;

  const _PasoCard({
    super.key,
    required this.icono,
    required this.titulo,
    required this.descripcion,
    this.error,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(icono, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(titulo,
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(descripcion,
                style:
                    tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const Divider(height: 24),
            if (error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 16, color: cs.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(error!,
                          style: TextStyle(
                              fontSize: 13, color: cs.onErrorContainer)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _BtnSiguiente extends StatelessWidget {
  final String label;
  final bool cargando;
  final VoidCallback onPressed;

  const _BtnSiguiente({
    required this.label,
    required this.cargando,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: cargando ? null : onPressed,
      icon: cargando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.arrow_forward),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(cargando ? 'Verificando...' : label,
            style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}
