import 'package:flutter/material.dart';

import '../datos/sesion.dart';
import 'catalogos/lista_clientes.dart';
import 'catalogos/lista_asesores.dart';
import 'catalogos/lista_aseguradoras.dart';
import 'catalogos/lista_ramos.dart';
import 'catalogos/lista_productos.dart';
import 'catalogos/lista_usuarios.dart';
import 'catalogos/lista_formas_expedicion.dart';
import 'catalogos/lista_formas_pago.dart';

class PaginaCatalogos extends StatelessWidget {
  const PaginaCatalogos({super.key});

  @override
  Widget build(BuildContext context) {
    final rol = Sesion.usuario?.rol.toUpperCase() ?? '';
    final esAdmin = rol == 'A' || rol.isEmpty; // sin sesión = acceso completo en prod

    return Scaffold(
      appBar: AppBar(title: const Text('Catálogos')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _CatalogoTile(
                icon: Icons.people_outline,
                title: 'Clientes',
                subtitle: 'Personas y empresas aseguradas',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ListaClientes())),
              ),
              if (esAdmin) ...[
                _CatalogoTile(
                  icon: Icons.badge_outlined,
                  title: 'Asesores',
                  subtitle: 'Corredores, agentes y agencias',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ListaAsesores())),
                ),
                _CatalogoTile(
                  icon: Icons.account_balance_outlined,
                  title: 'Aseguradoras',
                  subtitle: 'Compañías de seguros',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ListaAseguradoras())),
                ),
                _CatalogoTile(
                  icon: Icons.category_outlined,
                  title: 'Ramos',
                  subtitle: 'Líneas de negocio',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ListaRamos())),
                ),
                _CatalogoTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Productos',
                  subtitle: 'Planes y coberturas por ramo',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ListaProductos())),
                ),
                _CatalogoTile(
                  icon: Icons.payment_outlined,
                  title: 'Formas de Pago',
                  subtitle: 'Cuotas y modalidades de pago',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ListaFormasPago())),
                ),
                _CatalogoTile(
                  icon: Icons.description_outlined,
                  title: 'Formas de Expedición',
                  subtitle: 'Tipos de expedición de pólizas',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ListaFormasExpedicion())),
                ),
                _CatalogoTile(
                  icon: Icons.manage_accounts_outlined,
                  title: 'Usuarios',
                  subtitle: 'Cuentas de acceso y roles',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ListaUsuarios())),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CatalogoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(icon, color: cs.onPrimaryContainer, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
