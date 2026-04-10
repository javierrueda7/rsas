import 'package:flutter/material.dart';

import '../datos/sesion.dart';
import 'pagina_login.dart';
import 'pagina_polizas.dart';
import 'pagina_catalogos.dart';
import 'catalogos/lista_clientes.dart'; // para digitadores
import 'pagina_reportes.dart';

class PaginaInicio extends StatefulWidget {
  final String appEnv;

  const PaginaInicio({super.key, required this.appEnv});

  @override
  State<PaginaInicio> createState() => _PaginaInicioState();
}

class _PaginaInicioState extends State<PaginaInicio> {
  void _cerrarSesion() {
    Sesion.cerrar();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaginaLogin(appEnv: widget.appEnv),
      ),
    );
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
                      IconButton(
                        tooltip: 'Cerrar sesión',
                        icon: const Icon(Icons.logout, size: 18),
                        onPressed: _cerrarSesion,
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

              // ── Reportes ──────────────────────────────────────────────────
              _NavCard(
                icon: Icons.analytics_outlined,
                iconColor: cs.secondary,
                title: 'Reportes',
                subtitle: 'Dashboards y exportar a Excel',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PaginaReportes()),
                ),
              ),
            ],
          ),
        ),
      ),
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

  const _NavCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
