// #Ciclo5 CU18 - Servicio de cotizaciones actualizado con nuevo flujo del backend
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../auth_services/auth_service.dart';

class CotizacionService {
  // GET /cotizaciones/{incidenteId} — Lista ordenada por precio ASC
  static Future<List<dynamic>> getCotizaciones(int incidenteId) async {
    final headers = await AuthService.authHeaders();
    final response = await http.get(
      Uri.parse(ApiConstants.cotizaciones(incidenteId)),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Error al cargar cotizaciones');
  }

  // PUT /cotizaciones/{id}/aceptar — Cliente acepta una cotización
  static Future<Map<String, dynamic>> aceptarCotizacion(
      int cotizacionId) async {
    final headers = await AuthService.authHeaders();
    final response = await http.put(
      Uri.parse(ApiConstants.aceptarCotizacion(cotizacionId)),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? 'Error al aceptar la cotización');
  }

  // PUT /cotizaciones/{id}/rechazar — Cliente rechaza una cotización
  static Future<void> rechazarCotizacion(int cotizacionId) async {
    final headers = await AuthService.authHeaders();
    await http.put(
      Uri.parse(ApiConstants.rechazarCotizacion(cotizacionId)),
      headers: headers,
    );
  }
}
