// lib/core/services/notificacion_service.dart
// CU15 — GET   /notificaciones/mis-notificaciones
//         GET   /notificaciones/no-leidas
//         PATCH /notificaciones/{id}/leer
//         PATCH /notificaciones/leer-todas   ← NUEVO
//         DELETE /notificaciones/{id}        ← NUEVO

import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import '../auth_services/auth_service.dart';
import '../constants/api_constants.dart';

import '../../models/notificacion_model.dart';

class NotificacionService {
  static const _base = '${ApiConstants.baseUrl}/notificaciones';

  // ── GET /mis-notificaciones ──────────────────────────────────────
  static Future<List<NotificacionModel>> misNotificaciones() async {
    try {
      final headers = await AuthService.authHeaders();
      final resp = await http.get(
        Uri.parse('$_base/mis-notificaciones'),
        headers: headers,
      );

      // LOG COMPLETO para diagnóstico
      dev.log('[Notif] status: ${resp.statusCode}');
      dev.log('[Notif] body: ${resp.body}');

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);

        // Detectar el formato real de la respuesta
        List raw;
        if (body is List) {
          raw = body;
        } else if (body is Map) {
          // Probar todas las claves posibles
          raw = (body['data']
              ?? body['notificaciones']
              ?? body['items']
              ?? body['results']
              ?? body['list']
              ?? []) as List;
        } else {
          raw = [];
        }

        dev.log('[Notif] items encontrados: ${raw.length}');
        if (raw.isNotEmpty) dev.log('[Notif] primer item: ${raw.first}');

        // Parsear uno a uno para atrapar errores individuales
        final lista = <NotificacionModel>[];
        for (final item in raw) {
          try {
            lista.add(NotificacionModel.fromJson(item as Map<String, dynamic>));
          } catch (e) {
            dev.log('[Notif] error parseando item $item: $e');
          }
        }
        return lista;
      }
      dev.log('[Notif] error HTTP ${resp.statusCode}: ${resp.body}');
      return [];
    } catch (e) {
      dev.log('[Notif] excepción: $e');
      return [];
    }
  }

  // ── GET /no-leidas ──────────────────────────────────────────────────────────
  static Future<int> contarNoLeidas() async {
    try {
      final resp = await http.get(
        Uri.parse('$_base/no-leidas'),
        headers: await AuthService.authHeaders(),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return (data['total_no_leidas'] as int?) ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  // ── PATCH /notificaciones/{id}/leer ────────────────────────────────────────
  static Future<void> marcarLeida(int idNotificacion) async {
    try {
      await http.patch(
        Uri.parse('$_base/$idNotificacion/leer'),
        headers: await AuthService.authHeaders(),
      );
    } catch (_) {}
  }

  // ── PATCH /notificaciones/leer-todas ← NUEVO ───────────────────────────────
  static Future<void> marcarTodasLeidas() async {
    try {
      await http.patch(
        Uri.parse('$_base/leer-todas'),
        headers: await AuthService.authHeaders(),
      );
    } catch (_) {}
  }

  // ── DELETE /notificaciones/{id} ← NUEVO ────────────────────────────────────
  static Future<void> eliminar(int idNotificacion) async {
    try {
      await http.delete(
        Uri.parse('$_base/$idNotificacion'),
        headers: await AuthService.authHeaders(),
      );
    } catch (_) {}
  }
}
