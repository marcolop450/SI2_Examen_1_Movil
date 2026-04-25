import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _keyToken = 'auth_token';
  static const _keyRol = 'auth_rol';
  static const _keyNombre = 'auth_nombre';
  static const _keyIdUser = 'auth_id_usuario';
  static const _keyIdTaller = 'auth_id_taller';

  static Future<void> saveSession({
    required String token,
    required String rol,
    required String nombre,
    int? idUsuario,
    int? idTaller,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyRol, rol);
    await prefs.setString(_keyNombre, nombre);
    if (idUsuario != null) await prefs.setInt(_keyIdUser, idUsuario);
    if (idTaller != null) await prefs.setInt(_keyIdTaller, idTaller);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<String?> getRol() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRol);
  }

  static Future<String?> getNombre() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNombre);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
