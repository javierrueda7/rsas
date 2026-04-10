import 'catalogos.dart';

/// Singleton que mantiene el usuario activo durante la sesión de la app.
class Sesion {
  Sesion._();

  static Usuario? _usuario;

  static Usuario? get usuario => _usuario;
  static int? get usuarioId => _usuario?.id;
  static String get apodo => _usuario?.apodoUsuario ?? 'Anónimo';

  static void iniciar(Usuario u) => _usuario = u;
  static void cerrar() => _usuario = null;
}
