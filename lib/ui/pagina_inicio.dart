import 'package:flutter/material.dart';

import '../datos/catalogos.dart';
import '../datos/repositorio_catalogos.dart';
import '../datos/sesion.dart';
import 'pagina_login.dart';
import 'pagina_polizas.dart';
import 'pagina_catalogos.dart';
import 'catalogos/lista_clientes.dart'; // para digitadores

class PaginaInicio extends StatefulWidget {
  final String appEnv;

  const PaginaInicio({super.key, required this.appEnv});

  @override
  State<PaginaInicio> createState() => _PaginaInicioState();
}

class _PaginaInicioState extends State<PaginaInicio> {
  final _repo = RepositorioCatalogos();
  List<Usuario> _usuarios = [];

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    try {
      final res = await _repo.listarUsuarios(soloActivos: true);
      if (!mounted) return;
      setState(() => _usuarios = res);
    } catch (_) {
      // Si falla la carga de usuarios, la app sigue funcionando sin sesión
    }
  }

  Future<void> _seleccionarUsuario() async {
    if (_usuarios.isEmpty) await _cargarUsuarios();

    if (!mounted) return;

    final seleccionado = await showDialog<Usuario>(
      context: context,
      builder: (_) => _DialogoUsuario(usuarios: _usuarios),
    );

    if (seleccionado != null) {
      Sesion.iniciar(seleccionado);
      setState(() {});
    }
  }

  void _cerrarSesion() {
    Sesion.cerrar();
    if (widget.appEnv != 'prod') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaginaLogin(appEnv: widget.appEnv),
        ),
      );
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final usuarioActivo = Sesion.usuario;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.appEnv == 'prod'
              ? ''
              : 'PRUEBAS',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              // ── Encabezado ─────────────────────────────────────────────────
              Card(
                elevation: 0,
                color: cs.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/LogoRuedaSerranoFondoTransparente2.png',
                        height: 60,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SegurApp',
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Rueda Serrano Asesores de Seguros',
                              style: tt.bodySmall?.copyWith(
                                color: const Color(0xFF2E7D32),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Sesión activa ──────────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: usuarioActivo != null
                            ? cs.secondaryContainer
                            : cs.surfaceContainerHighest,
                        child: Icon(
                          Icons.person_outline,
                          size: 18,
                          color: usuarioActivo != null
                              ? cs.onSecondaryContainer
                              : cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              usuarioActivo != null
                                  ? usuarioActivo.apodoUsuario
                                  : 'Sin sesión (Anónimo)',
                              style: tt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (usuarioActivo != null)
                              Text(
                                usuarioActivo.nombreUsuario,
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (usuarioActivo != null)
                        IconButton(
                          tooltip: 'Cerrar sesión',
                          icon: const Icon(Icons.logout, size: 18),
                          onPressed: _cerrarSesion,
                        ),
                      // En dev el cambio de usuario requiere re-autenticación
                      if (widget.appEnv == 'prod')
                        TextButton.icon(
                          icon: const Icon(Icons.swap_horiz, size: 16),
                          label: Text(
                            usuarioActivo != null ? 'Cambiar' : 'Iniciar',
                          ),
                          onPressed: _seleccionarUsuario,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Pólizas ────────────────────────────────────────────────────
              _NavCard(
                icon: Icons.receipt_long_outlined,
                iconColor: cs.primary,
                title: 'Pólizas',
                subtitle: 'Crear, editar, buscar y controlar vencimientos',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PaginaPolizas()),
                ),
              ),
              const SizedBox(height: 10),

              // ── Catálogos (Admin: todos / Digitador: solo Clientes) ────────
              if (usuarioActivo?.rol.toUpperCase() == 'D')
                _NavCard(
                  icon: Icons.people_outline,
                  iconColor: cs.tertiary,
                  title: 'Clientes',
                  subtitle: 'Personas y empresas aseguradas',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ListaClientes()),
                  ),
                )
              else
                _NavCard(
                  icon: Icons.folder_open_outlined,
                  iconColor: cs.tertiary,
                  title: 'Catálogos',
                  subtitle: 'Clientes, asesores, aseguradoras, ramos, productos y más',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaginaCatalogos()),
                  ),
                ),
              const SizedBox(height: 10),

              // ── Reportes (próximamente) ────────────────────────────────────
              _NavCard(
                icon: Icons.analytics_outlined,
                iconColor: cs.secondary,
                title: 'Reportes',
                subtitle: 'Exportar a Excel / Power BI (próximamente)',
                disabled: true,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Módulo en construcción')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Diálogo de selección de usuario ──────────────────────────────────────────

class _DialogoUsuario extends StatefulWidget {
  final List<Usuario> usuarios;

  const _DialogoUsuario({required this.usuarios});

  @override
  State<_DialogoUsuario> createState() => _DialogoUsuarioState();
}

class _DialogoUsuarioState extends State<_DialogoUsuario> {
  String _filtro = '';

  List<Usuario> get _filtrados {
    if (_filtro.isEmpty) return widget.usuarios;
    final q = _filtro.toLowerCase();
    return widget.usuarios.where((u) {
      return u.apodoUsuario.toLowerCase().contains(q) ||
          u.nombreUsuario.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;

    return AlertDialog(
      title: const Text('Seleccionar usuario'),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: 380,
        height: 440,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _filtro = v),
                decoration: const InputDecoration(
                  hintText: 'Buscar...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            if (widget.usuarios.isEmpty)
              const Expanded(
                child: Center(child: Text('No hay usuarios activos')),
              )
            else if (filtrados.isEmpty)
              const Expanded(
                child: Center(child: Text('Sin resultados')),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: filtrados.length,
                  itemBuilder: (_, i) {
                    final u = filtrados[i];
                    final esActual = Sesion.usuarioId == u.id;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          u.apodoUsuario.isNotEmpty
                              ? u.apodoUsuario[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(u.apodoUsuario),
                      subtitle: Text(u.nombreUsuario),
                      trailing: esActual
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      selected: esActual,
                      onTap: () => Navigator.pop(context, u),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

// ── NavCard ───────────────────────────────────────────────────────────────────

class _NavCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool disabled;

  const _NavCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final effectiveColor =
        disabled ? iconColor.withOpacity(0.35) : iconColor;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: effectiveColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: effectiveColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: disabled
                            ? cs.onSurface.withOpacity(0.38)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: tt.bodySmall?.copyWith(
                        color: disabled
                            ? cs.onSurface.withOpacity(0.26)
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: disabled
                    ? cs.onSurface.withOpacity(0.2)
                    : cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
