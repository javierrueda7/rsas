import 'package:flutter/material.dart';

import 'pagina_polizas.dart';
import 'pagina_catalogos.dart';

class PaginaInicio extends StatelessWidget {
  const PaginaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento de Pólizas'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Resumen (placeholder - luego lo conectamos a la BD)
          Visibility(
            visible: false,
            child: Column(
              children: [
                Row(
                  children: const [
                    Expanded(child: _TarjetaResumen(titulo: 'Vigentes', valor: '—')),
                    SizedBox(width: 12),
                    Expanded(child: _TarjetaResumen(titulo: 'Vencidas', valor: '—')),
                    SizedBox(width: 12),
                    Expanded(child: _TarjetaResumen(titulo: 'Por vencer', valor: '—')),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Accesos principales
          _BotonGrande(
            icono: Icons.receipt_long,
            titulo: 'Pólizas',
            subtitulo: 'Crear, editar, buscar y ver vencimientos',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaginaPolizas()),
            ),
          ),
          const SizedBox(height: 12),
          _BotonGrande(
            icono: Icons.folder_open,
            titulo: 'Catálogos',
            subtitulo: 'Clientes, asesores, aseguradoras, ramos y productos',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaginaCatalogos()),
            ),
          ),
          const SizedBox(height: 12),
          _BotonGrande(
            icono: Icons.analytics,
            titulo: 'Reportes / Exportar',
            subtitulo: 'Preparar datos para Excel / Power BI (próximamente)',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Módulo en construcción')),
              );
            },
          ),

          Visibility(
            visible: false,
            child: Column(
              children: [
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                
                // Alertas (placeholder - luego las conectamos)
                const Text(
                  'Alertas rápidas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                
                _TarjetaAlerta(
                  titulo: 'Pólizas que vencen pronto',
                  descripcion: 'Ver pólizas que vencen en los próximos 30 días',
                  icono: Icons.warning_amber,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaginaPolizas()),
                  ),
                ),
                const SizedBox(height: 10),
                _TarjetaAlerta(
                  titulo: 'Pólizas vencidas',
                  descripcion: 'Ver pólizas que ya vencieron para seguimiento',
                  icono: Icons.event_busy,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaginaPolizas()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaResumen extends StatelessWidget {
  final String titulo;
  final String valor;

  const _TarjetaResumen({required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(valor, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _BotonGrande extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const _BotonGrande({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icono, size: 32),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _TarjetaAlerta extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final IconData icono;
  final VoidCallback onTap;

  const _TarjetaAlerta({
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icono),
        title: Text(titulo),
        subtitle: Text(descripcion),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
