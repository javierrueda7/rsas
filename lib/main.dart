import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:seguimiento_polizas/ui/pagina_inicio.dart';
import 'package:seguimiento_polizas/ui/pagina_login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Valor recibido por compilación:
  // flutter run --dart-define=APP_ENV=dev
  // flutter run --dart-define=APP_ENV=prod
  const appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  final envFile = appEnv == 'prod' ? '.env.prod' : '.env.dev';

  await dotenv.load(fileName: envFile);

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(AppPolizas(appEnv: appEnv));
}

class AppPolizas extends StatelessWidget {
  final String appEnv;

  const AppPolizas({super.key, required this.appEnv});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SegurApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          scrolledUnderElevation: 1,
        ),
      ),
      home: appEnv == 'prod'
          ? PaginaInicio(appEnv: appEnv)
          : PaginaLogin(appEnv: appEnv),
    );
  }
}