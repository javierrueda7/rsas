import 'package:flutter/material.dart';

import '../datos/repositorio_catalogos.dart';
import '../datos/sesion.dart';
import 'pagina_inicio.dart';

class PaginaLogin extends StatefulWidget {
  final String appEnv;

  const PaginaLogin({super.key, required this.appEnv});

  @override
  State<PaginaLogin> createState() => _PaginaLoginState();
}

class _PaginaLoginState extends State<PaginaLogin> {
  final _formKey = GlobalKey<FormState>();
  final _apodoCtrl = TextEditingController();
  final _claveCtrl = TextEditingController();
  final _repo = RepositorioCatalogos();

  bool _cargando = false;
  bool _ocultarClave = true;
  String? _error;

  bool get _esDev => widget.appEnv != 'prod';

  @override
  void dispose() {
    _apodoCtrl.dispose();
    _claveCtrl.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (_cargando) return;

    setState(() => _error = null);

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _cargando = true);

    try {
      final usuario = await _repo.autenticar(
        _apodoCtrl.text.trim(),
        _claveCtrl.text,
      );

      if (!mounted) return;

      if (usuario == null) {
        setState(() {
          _error = 'Usuario o contraseña incorrectos.';
          _cargando = false;
        });
        return;
      }

      Sesion.iniciar(usuario);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaginaInicio(appEnv: widget.appEnv),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al conectar. Verifica tu conexión.';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Logo / encabezado ──────────────────────────────────────
                    Image.asset(
                      'assets/images/LogoRuedaSerranoFondoTransparente2.png',
                      height: 140,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'SegurApp',
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.primary,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'RUEDA SERRANO ASESORES DE SEGUROS',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2E7D32),
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // ── Formulario ─────────────────────────────────────────────
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Iniciar sesión',
                                style: tt.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Apodo
                              TextFormField(
                                controller: _apodoCtrl,
                                autofocus: true,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Usuario',
                                  prefixIcon: Icon(Icons.person_outline),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Ingresa tu usuario'
                                        : null,
                              ),
                              const SizedBox(height: 16),

                              // Clave
                              TextFormField(
                                controller: _claveCtrl,
                                obscureText: _ocultarClave,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _ingresar(),
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    tooltip: _ocultarClave
                                        ? 'Mostrar contraseña'
                                        : 'Ocultar contraseña',
                                    icon: Icon(
                                      _ocultarClave
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () => setState(
                                      () => _ocultarClave = !_ocultarClave,
                                    ),
                                  ),
                                ),
                                validator: (v) =>
                                    (v == null || v.isEmpty)
                                        ? 'Ingresa tu contraseña'
                                        : null,
                              ),

                              // Mensaje de error
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.errorContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        size: 16,
                                        color: cs.onErrorContainer,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: cs.onErrorContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 20),

                              // Botón ingresar
                              FilledButton.icon(
                                onPressed: _cargando ? null : _ingresar,
                                icon: _cargando
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.login),
                                label: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  child: Text(
                                    _cargando ? 'Ingresando...' : 'Ingresar',
                                    style: const TextStyle(fontSize: 15),
                                  ),
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
          ),

          // Badge PRUEBAS — solo visible en entorno dev
          if (_esDev)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    border: Border.all(color: Colors.orange.shade400),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.science_outlined,
                          size: 16, color: Colors.orange.shade800),
                      const SizedBox(width: 6),
                      Text(
                        'ENTORNO DE PRUEBAS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange.shade800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
