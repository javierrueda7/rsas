import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:seguimiento_polizas/ui/pagina_inicio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 👇 Cargar variables del .env
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const AppPolizas());
}


class AppPolizas extends StatelessWidget {
  const AppPolizas({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seguimiento de Pólizas',
      theme: ThemeData(useMaterial3: true),
      home: const PaginaInicio(),
    );
  }
}
