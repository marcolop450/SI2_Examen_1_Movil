// #Ciclo5 CU25 - Servicio de consejos viales

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth_services/auth_service.dart';
import '../constants/api_constants.dart';
import '../../models/consejo_vial_model.dart';

class ConsejoVialService {
  // ==========================================
  // Obtener consejos para un incidente específico
  // ==========================================
  static Future<List<ConsejoVialModel>> obtenerConsejosParaIncidente(
    int incidenteId,
  ) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConstants.baseUrl}/consejos-viales/para-incidente/$incidenteId',
      ),
      headers: await AuthService.authHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => ConsejoVialModel.fromJson(j)).toList();
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? 'Error al obtener consejos viales');
  }

  // ==========================================
  // Generar consejos con IA para un incidente
  // ==========================================
  static Future<List<Map<String, dynamic>>> generarConsejosIA(
    int incidenteId,
  ) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConstants.baseUrl}/consejos-viales/generar-ia/$incidenteId',
      ),
      headers: await AuthService.authHeaders(),
      body: jsonEncode({}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> consejos = data['consejos_generados'] ?? [];
      return consejos.cast<Map<String, dynamic>>();
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? 'Error al generar consejos con IA');
  }

  // ==========================================
  // Obtener consejos por categoría (público)
  // ==========================================
  static Future<List<ConsejoVialModel>> obtenerConsejosPorCategoria(
    String categoria,
  ) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConstants.baseUrl}/consejos-viales/por-categoria/$categoria',
      ),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => ConsejoVialModel.fromJson(j)).toList();
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? 'Error al obtener consejos por categoría');
  }
}
