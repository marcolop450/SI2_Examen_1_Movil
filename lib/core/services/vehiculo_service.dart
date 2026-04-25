// lib/core/services/vehiculo_service.dart
// CU5 — Administrar Vehículos
// GET    /vehiculos/          → listar mis vehículos
// POST   /vehiculos/          → registrar vehículo (HTTP 201)
// DELETE /vehiculos/{id}      → eliminar vehículo

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth_services/auth_service.dart';
import '../constants/api_constants.dart';
import '../../models/vehiculo_model.dart';

class VehiculoService {
  // GET /vehiculos/ — devuelve solo los del usuario autenticado
  static Future<List<VehiculoModel>> listarMisVehiculos() async {
    final response = await http.get(
      Uri.parse(ApiConstants.vehiculosEndpoint),
      headers: await AuthService.authHeaders(),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => VehiculoModel.fromJson(e)).toList();
    }
    throw Exception('Error al cargar vehículos');
  }

  // POST /vehiculos/ — registra un nuevo vehículo
  static Future<VehiculoModel> registrarVehiculo({
    required String placa,
    required String marca,
    required String modelo,
    required String color,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConstants.vehiculosEndpoint),
      headers: await AuthService.authHeaders(),
      body: jsonEncode({
        'placa': placa,
        'marca': marca,
        'modelo': modelo,
        'color': color,
      }),
    );
    if (response.statusCode == 201) {
      return VehiculoModel.fromJson(jsonDecode(response.body));
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? 'Error al registrar vehículo');
  }

  // DELETE /vehiculos/{id}
  static Future<void> eliminarVehiculo(int idVehiculo) async {
    final response = await http.delete(
      Uri.parse('${ApiConstants.vehiculosEndpoint}$idVehiculo'),
      headers: await AuthService.authHeaders(),
    );
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Error al eliminar vehículo');
    }
  }
}
