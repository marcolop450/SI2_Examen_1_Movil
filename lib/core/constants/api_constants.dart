class ApiConstants {
  // ANTES (Para el emulador):
  // static const String baseUrl = 'http://10.0.2.2:8000';

  // AHORA (Para tu teléfono físico en la red local):
  static const String baseUrl = 'https://backend-ixkv.onrender.com';
  static const String loginEndpoint = '$baseUrl/auth/login';
  static const String logoutEndpoint = '$baseUrl/auth/logout';
  static const String registerEndpoint = '$baseUrl/usuarios/registro';
  static const String vehiculosEndpoint = '$baseUrl/vehiculos/';
  static const String incidentesEndpoint = '$baseUrl/incidentes/';
  static const String notificacionesEndpoint =
      '$baseUrl/notificaciones/mis-notificaciones';
}
