import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth_services/auth_service.dart';
import '../constants/api_constants.dart';
import '../../models/incidente_model.dart';

class IncidenteService {
  // ==========================================
  // CU7: REGISTRAR EMERGENCIA (CLIENTE)
  // ==========================================
  static Future<IncidenteModel> registrarEmergencia({
    required int vehiculoId,
    required double latitud,
    required double longitud,
    required String descripcion,
    required List<Map<String, String>> evidencias,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConstants.incidentesEndpoint),
      headers: await AuthService.authHeaders(),
      body: jsonEncode({
        'vehiculo_id': vehiculoId,
        'latitud_emergencia': latitud,
        'longitud_emergencia': longitud,
        'descripcion_texto': descripcion,
        'evidencias': evidencias,
      }),
    );

    if (response.statusCode == 201) {
      return IncidenteModel.fromJson(jsonDecode(response.body));
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? 'Error al registrar emergencia');
  }

  // ==========================================
  // CU9: MONITOREAR EMERGENCIA (CLIENTE)
  // ==========================================
  static Future<Map<String, dynamic>> monitorearEmergencia(
    int idIncidente,
  ) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.incidentesEndpoint}$idIncidente/monitoreo'),
      headers: await AuthService.authHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error al obtener estado del servicio');
  }

  // ==========================================
  // CU12: OBTENER ASIGNADOS (TÉCNICO)
  // ==========================================
  static Future<List<dynamic>> obtenerAsignados() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.incidentesEndpoint}en-proceso'),
      headers: await AuthService.authHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Error al cargar órdenes asignadas');
  }

  // ==========================================
  // CU12: FINALIZAR SERVICIO (TÉCNICO)
  // ==========================================
  static Future<void> actualizarEstado(
    int idIncidente,
    String nuevoEstado, {
    double? costoFinal,
  }) async {
    final Map<String, dynamic> bodyData = {
      'estado_enum': nuevoEstado,
      'comentario': 'Servicio completado por el técnico.',
    };
    if (costoFinal != null) {
      bodyData['costo_final'] = costoFinal;
    }
    final response = await http.put(
      Uri.parse('${ApiConstants.incidentesEndpoint}$idIncidente/estado'),
      headers: await AuthService.authHeaders(),
      body: jsonEncode(bodyData),
    );

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Error al actualizar estado');
    }
  }

  // ==========================================
  // CU12: ENVIAR UBICACIÓN (TÉCNICO)
  // ==========================================
  static Future<void> reportarUbicacionTecnico(
    int idIncidente,
    double lat,
    double lng,
  ) async {
    await http.put(
      Uri.parse(
        '${ApiConstants.incidentesEndpoint}$idIncidente/ubicacion-tecnico',
      ),
      headers: await AuthService.authHeaders(),
      body: jsonEncode({'latitud': lat, 'longitud': lng}),
    );
  }

  // ==========================================
  // RECUPERAR EMERGENCIA TRAS CERRAR SESIÓN
  // ==========================================
  static Future<int?> obtenerEmergenciaActiva() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.incidentesEndpoint}cliente/activo'),
      headers: await AuthService.authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['id_incidente'];
    }
    return null;
  }
}
