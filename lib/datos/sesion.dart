import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'catalogos.dart';

/// Singleton que mantiene el usuario activo durante la sesión de la app.
class Sesion {
  Sesion._();

  static Usuario? _usuario;

  static Usuario? get usuario => _usuario;
  static int? get usuarioId => _usuario?.id;
  static String get apodo => _usuario?.apodoUsuario ?? 'Anónimo';

  static void iniciar(Usuario u) => _usuario = u;

  /// Además de olvidar el usuario, vuelve el cliente de Supabase a la
  /// anon key — el login (RepositorioCatalogos.autenticar) lo deja
  /// autenticado con un JWT propio vía rest.setAuth(); sin este reset, ese
  /// token quedaría pegado y se reusaría (o fallaría al vencer) en la
  /// siguiente sesión.
  static void cerrar() {
    _usuario = null;
    Supabase.instance.client.rest.setAuth(dotenv.env['SUPABASE_ANON_KEY']);
  }
}
