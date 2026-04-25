import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/auth_response_model.dart';
import '../constants/api_constants.dart';
import '../storage/storage_service.dart';

class AuthService {
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConstants.loginEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final authResponse = AuthResponse.fromJson(data);

      await StorageService.saveSession(
        token: authResponse.accessToken,
        rol: authResponse.rol,
        nombre: authResponse.nombre,
        idUsuario: authResponse.idUsuario,
        idTaller: authResponse.idTaller,
      );
      return authResponse;
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Error al iniciar sesión');
    }
  }

  // ─────────────────────────────────────────────
  // CU2 - Registro de Cliente
  // ─────────────────────────────────────────────
  static Future<bool> registrarCliente({
    required String nombre,
    required String email,
    required String password,
    String? telefono,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConstants.registerEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombre': nombre,
        'email': email,
        'password': password,
        'rol': 'cliente',
        if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
      }),
    );

    if (response.statusCode == 201) return true;

    final body = jsonDecode(response.body);
    throw Exception(body['detail'] ?? 'Error al registrar usuario');
  }

  static Future<void> logout() async {
    final token = await StorageService.getToken();
    if (token != null) {
      try {
        await http.post(
          Uri.parse(ApiConstants.logoutEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      } catch (_) {}
    }
    await StorageService.clearSession();
  }

  static Future<Map<String, String>> authHeaders() async {
    final token = await StorageService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
}
