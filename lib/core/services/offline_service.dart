// #Ciclo5 CU19 - Servicio de cola offline con reintentos y backoff
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../services/incidente_service.dart';

class SyncResult {
  final int exitosas;
  final int fallidas;
  final List<String> errores;
  SyncResult({required this.exitosas, required this.fallidas, required this.errores});
}

class OfflineService {
  static const _key = 'emergencias_offline_v2';

  /// Save emergency to local queue with UUID and timestamp
  static Future<String> guardarEmergenciaOffline({
    required int vehiculoId,
    required double latitud,
    required double longitud,
    required String descripcion,
    required List<Map<String, String>> evidencias,
  }) async {
    final uuid = const Uuid().v4();
    final payload = {
      'vehiculoId': vehiculoId,
      'lat': latitud,
      'lng': longitud,
      'desc': descripcion,
      'evidencias': evidencias,
      'uuid': uuid,
      'timestamp': DateTime.now().toIso8601String(),
      'intentos': 0,
    };
    
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.add(jsonEncode(payload));
    await prefs.setStringList(_key, list);
    return uuid;
  }

  /// Count pending emergencies
  static Future<int> contarPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.length;
  }

  /// Get all pending emergencies
  static Future<List<Map<String, dynamic>>> obtenerPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  /// Sync all pending emergencies with exponential backoff
  static Future<SyncResult> sincronizarTodas() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    
    if (list.isEmpty) return SyncResult(exitosas: 0, fallidas: 0, errores: []);

    int exitosas = 0;
    int fallidas = 0;
    List<String> errores = [];
    List<String> restantes = [];

    for (final itemJson in list) {
      final data = jsonDecode(itemJson) as Map<String, dynamic>;
      final intentos = (data['intentos'] as int?) ?? 0;
      
      // Max 3 retries
      if (intentos >= 3) {
        errores.add('UUID ${data['uuid']}: máximo de reintentos alcanzado');
        fallidas++;
        continue; // Drop it after 3 attempts
      }

      try {
        await IncidenteService.registrarEmergencia(
          vehiculoId: data['vehiculoId'],
          latitud: (data['lat'] as num).toDouble(),
          longitud: (data['lng'] as num).toDouble(),
          descripcion: data['desc'] ?? '',
          evidencias: List<Map<String, String>>.from(
            (data['evidencias'] as List).map((e) => Map<String, String>.from(e)),
          ),
          uuidOffline: data['uuid'],
        );
        exitosas++;
        print('✅ Emergencia offline sincronizada: ${data['uuid']}');
        
        // Backoff delay between syncs
        if (list.length > 1) {
          await Future.delayed(Duration(seconds: (intentos + 1) * 1));
        }
      } catch (e) {
        final errorMsg = e.toString().toLowerCase();
        // If duplicate (409 or constraint error), consider it synced
        if (errorMsg.contains('duplicate') || errorMsg.contains('uuid_offline') || errorMsg.contains('409')) {
          exitosas++;
          print('ℹ️ Emergencia ya existía (UUID duplicado): ${data['uuid']}');
        } else if (errorMsg.contains('400') || errorMsg.contains('422') || errorMsg.contains('validación')) {
          // Validation error - don't retry
          errores.add('UUID ${data['uuid']}: error de validación');
          fallidas++;
        } else {
          // Server/network error - keep for retry with incremented counter
          data['intentos'] = intentos + 1;
          restantes.add(jsonEncode(data));
          fallidas++;
          errores.add('UUID ${data['uuid']}: $e');
        }
      }
    }

    await prefs.setStringList(_key, restantes);
    return SyncResult(exitosas: exitosas, fallidas: fallidas, errores: errores);
  }

  /// Remove a specific emergency from the queue
  static Future<void> eliminarDeCola(String uuid) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.removeWhere((item) {
      final data = jsonDecode(item) as Map<String, dynamic>;
      return data['uuid'] == uuid;
    });
    await prefs.setStringList(_key, list);
  }

  /// Clear entire queue
  static Future<void> limpiarCola() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
