// #Ciclo5 CU23 - Servicio de calificación post-servicio
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth_services/auth_service.dart';
import '../constants/api_constants.dart';
import '../../models/calificacion_model.dart';

class CalificacionService {
  // ==========================================
  // CU23: ENVIAR CALIFICACIÓN POST-SERVICIO
  // ==========================================
  static Future<CalificacionModel> enviarCalificacion({
    required int incidenteId,
    required int puntuacion,
    String? comentario,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/calificaciones/'),
      headers: await AuthService.authHeaders(),
      body: jsonEncode({
        'incidente_id': incidenteId,
        'puntuacion': puntuacion,
        if (comentario != null && comentario.isNotEmpty)
          'comentario': comentario,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return CalificacionModel.fromJson(jsonDecode(response.body));
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? 'Error al enviar calificación');
  }

  // ==========================================
  // CU23: OBTENER MIS CALIFICACIONES
  // ==========================================
  static Future<List<CalificacionModel>> obtenerMisCalificaciones() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/calificaciones/mis-calificaciones'),
      headers: await AuthService.authHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => CalificacionModel.fromJson(j)).toList();
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? 'Error al obtener calificaciones');
  }

  // ==========================================
  // CU23: OBTENER PROMEDIO DEL TALLER
  // ==========================================
  static Future<Map<String, dynamic>> obtenerPromedioTaller(
    int tallerId,
  ) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/calificaciones/promedio/$tallerId'),
      headers: await AuthService.authHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? 'Error al obtener promedio del taller');
  }
}
