// lib/core/services/notificacion_service.dart
// CU15 — GET   /notificaciones/mis-notificaciones
//         GET   /notificaciones/no-leidas
//         PATCH /notificaciones/{id}/leer

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth_services/auth_service.dart';
import '../constants/api_constants.dart';
import '../../models/notificacion_model.dart';

class NotificacionService {
  static Future<List<NotificacionModel>> misNotificaciones() async {
    final response = await http.get(
      Uri.parse(ApiConstants.notificacionesEndpoint),
      headers: await AuthService.authHeaders(),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => NotificacionModel.fromJson(e)).toList();
    }
    throw Exception('Error al cargar notificaciones');
  }

  static Future<int> contarNoLeidas() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/notificaciones/no-leidas'),
      headers: await AuthService.authHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['total_no_leidas'] as int;
    }
    return 0;
  }

  static Future<void> marcarLeida(int idNotificacion) async {
    await http.patch(
      Uri.parse('${ApiConstants.baseUrl}/notificaciones/$idNotificacion/leer'),
      headers: await AuthService.authHeaders(),
    );
  }
}
