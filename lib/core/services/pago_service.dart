import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth_services/auth_service.dart';
import '../constants/api_constants.dart';

class PagoService {
  static Future<void> registrarPago({
    required int incidenteId,
    required double monto,
    required String metodo,
  }) async {
    final response = await http.post(
      // Asumimos que tu base url es algo como 'http://10.0.2.2:8000' + '/pagos/'
      Uri.parse('${ApiConstants.baseUrl}/pagos/'),
      headers: await AuthService.authHeaders(),
      body: jsonEncode({
        'incidente_id': incidenteId,
        'monto_total_decimal': monto,
        'metodo_enum': metodo,
      }),
    );

    if (response.statusCode != 201) {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Error al procesar el pago');
    }
  }
}
