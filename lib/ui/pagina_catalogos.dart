import 'package:flutter/material.dart';

import 'catalogos/lista_clientes.dart';
import 'catalogos/lista_asesores.dart';
import 'catalogos/lista_aseguradoras.dart';
import 'catalogos/lista_ramos.dart';
import 'catalogos/lista_productos.dart';

class PaginaCatalogos extends StatelessWidget {
  const PaginaCatalogos({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogos')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Clientes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ListaClientes())),
          ),
          ListTile(
            title: const Text('Asesores'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ListaAsesores())),
          ),
          ListTile(
            title: const Text('Aseguradoras'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ListaAseguradoras())),
          ),
          ListTile(
            title: const Text('Ramos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ListaRamos())),
          ),
          ListTile(
            title: const Text('Productos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ListaProductos())),
          ),
        ],
      ),
    );
  }
}
