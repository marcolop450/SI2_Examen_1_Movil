// #Ciclo5 - Constantes de API actualizadas con endpoints de CU23, CU25, CU19
class ApiConstants {
  // ANTES (Para el emulador):
  // static const String baseUrl = 'http://10.0.2.2:8000';

  // AHORA (Para tu teléfono físico en la red local):
  static const String baseUrl = 'http://192.168.1.11:8000'; // emulador Android
  static const String loginEndpoint = '$baseUrl/auth/login';
  static const String logoutEndpoint = '$baseUrl/auth/logout';
  static const String registerEndpoint = '$baseUrl/usuarios/registro';
  static const String vehiculosEndpoint = '$baseUrl/vehiculos/';
  static const String incidentesEndpoint = '$baseUrl/incidentes/';
  static const String notificacionesEndpoint =
      '$baseUrl/notificaciones/mis-notificaciones';

  // #Ciclo5 CU23 - Calificaciones
  static const String calificacionesEndpoint = '$baseUrl/calificaciones/';
  static const String misCalificacionesEndpoint =
      '$baseUrl/calificaciones/mis-calificaciones';
  static String promedioTallerEndpoint(int id) =>
      '$baseUrl/calificaciones/promedio/$id';
  static String calificacionesTallerEndpoint(int id) =>
      '$baseUrl/calificaciones/taller/$id';

  // #Ciclo5 CU25 - Consejos Viales
  static String consejosParaIncidenteEndpoint(int id) =>
      '$baseUrl/consejos-viales/para-incidente/$id';
  static String generarConsejosIAEndpoint(int id) =>
      '$baseUrl/consejos-viales/generar-ia/$id';
  static String consejosPorCategoriaEndpoint(String cat) =>
      '$baseUrl/consejos-viales/por-categoria/$cat';

  // #Ciclo5 CU19 - WebSocket dinámico (corrige inconsistencia con URL hardcodeada)
  static String get wsBaseUrl => baseUrl.replaceFirst('http', 'ws');
  static String wsIncidenteUrl(int id) => '$wsBaseUrl/ws/incidente/$id';
}
