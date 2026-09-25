import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:seguimiento_polizas/datos/sesion.dart';
import 'package:seguimiento_polizas/ui/pagina_login.dart';
import 'package:seguimiento_polizas/ui/theme/app_theme.dart';
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

  // El token de sesión dura 12 horas: al vencer, vuelve al login en vez de
  // dejar que cada pantalla falle con "JWT expired".
  Sesion.alVencer = () {
    Sesion.navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => PaginaLogin(
          appEnv: appEnv,
          mensajeInicial: 'Su sesión venció. Inicie sesión de nuevo.',
        ),
      ),
      (_) => false,
    );
  };

  runApp(AppPolizas(appEnv: appEnv));
}

class AppPolizas extends StatelessWidget {
  final String appEnv;

  const AppPolizas({super.key, required this.appEnv});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SegurApp',
      navigatorKey: Sesion.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'CO'), Locale('en')],
      locale: const Locale('es', 'CO'),
      // Todo texto de la app se puede seleccionar y copiar (números de
      // póliza, documentos, valores) sin tener que abrir el formulario.
      builder: (context, child) => _SeleccionGlobal(child: child!),
      home: PaginaLogin(appEnv: appEnv),
    );
  }
}

/// SelectionArea para toda la app. Va por encima del Navigator, donde
/// todavía no hay un Overlay (lo necesita para el menú de copiar), así que
/// se le da uno propio. La entrada se reconstruye cuando cambia [child].
class _SeleccionGlobal extends StatefulWidget {
  final Widget child;
  const _SeleccionGlobal({required this.child});

  @override
  State<_SeleccionGlobal> createState() => _SeleccionGlobalState();
}

class _SeleccionGlobalState extends State<_SeleccionGlobal> {
  late final OverlayEntry _entrada =
      OverlayEntry(builder: (_) => SelectionArea(child: widget.child));

  @override
  void didUpdateWidget(covariant _SeleccionGlobal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entrada.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entrada]);
}
