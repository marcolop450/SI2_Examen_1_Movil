// lib/models/auth_response_model.dart

/// Modelo que representa la respuesta del endpoint POST /auth/login
/// El backend FastAPI devuelve exactamente estos campos.
class AuthResponse {
  final String accessToken;
  final String rol; // "cliente" | "tecnico" | "admin"
  final String nombre;
  final int? idUsuario; // presente si rol == "cliente"
  final int? idTaller; // presente si rol == "tecnico"

  AuthResponse({
    required this.accessToken,
    required this.rol,
    required this.nombre,
    this.idUsuario,
    this.idTaller,
  });

  /// Factory: convierte el Map del JSON en un objeto AuthResponse.
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String,
      rol: json['rol'] as String,
      nombre: json['nombre'] as String,
      idUsuario: json['id_usuario'] as int?,
      idTaller: json['id_taller'] as int?,
    );
  }
}
