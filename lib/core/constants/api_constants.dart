// #Ciclo5 - API Constants completo con todos los endpoints del nuevo flujo
class ApiConstants {
  static const String baseUrl = 'http://192.168.1.11:8000';

  // Auth
  static const String loginEndpoint = '$baseUrl/auth/login';
  static const String logoutEndpoint = '$baseUrl/auth/logout';
  static const String registerEndpoint = '$baseUrl/usuarios/registro';

  // Recursos base
  static const String vehiculosEndpoint = '$baseUrl/vehiculos/';
  static const String incidentesEndpoint = '$baseUrl/incidentes/';
  static const String notificacionesEndpoint =
      '$baseUrl/notificaciones/mis-notificaciones';

  // #Ciclo5 CU18 - Cotizaciones (flujo principal nuevo)
  static String cotizaciones(int incidenteId) =>
      '$baseUrl/cotizaciones/$incidenteId';
  static String aceptarCotizacion(int id) =>
      '$baseUrl/cotizaciones/$id/aceptar';
  static String rechazarCotizacion(int id) =>
      '$baseUrl/cotizaciones/$id/rechazar';

  // #Ciclo5 CU23 - Calificaciones
  static const String calificacionesEndpoint = '$baseUrl/calificaciones/';
  static const String misCalificacionesEndpoint =
      '$baseUrl/calificaciones/mis-calificaciones';
  static String promedioTallerEndpoint(int id) =>
      '$baseUrl/calificaciones/promedio/$id';

  // #Ciclo5 CU25 - Consejos Viales
  static String consejosParaIncidenteEndpoint(int id) =>
      '$baseUrl/consejos-viales/para-incidente/$id';
  static String generarConsejosIAEndpoint(int id) =>
      '$baseUrl/consejos-viales/generar-ia/$id';
  static String consejosPorCategoriaEndpoint(String cat) =>
      '$baseUrl/consejos-viales/por-categoria/$cat';

  // #Ciclo5 CU19 - WebSocket dinámico
  static String get wsBaseUrl => baseUrl.replaceFirst('http', 'ws');
  static String wsIncidenteUrl(int id) => '$wsBaseUrl/ws/incidente/$id';
}
 