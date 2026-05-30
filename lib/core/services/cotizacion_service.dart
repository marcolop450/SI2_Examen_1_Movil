import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../auth_services/auth_service.dart';

class CotizacionService {
  static Future<List<dynamic>> getCotizaciones(int incidenteId) async {
    final headers = await AuthService.authHeaders();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/cotizaciones/$incidenteId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al cargar cotizaciones');
    }
  }

  static Future<void> aceptarCotizacion(int cotizacionId) async {
    final headers = await AuthService.authHeaders();
    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/cotizaciones/$cotizacionId/aceptar'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Error al aceptar la cotización');
    }
  }
}
