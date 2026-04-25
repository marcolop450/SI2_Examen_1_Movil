// lib/models/vehiculo_model.dart
// Mapea VehiculoOut del backend

class VehiculoModel {
  final int idVehiculo;
  final int usuarioId;
  final String placa;
  final String? marca;
  final String? modelo;
  final String? color;

  VehiculoModel({
    required this.idVehiculo,
    required this.usuarioId,
    required this.placa,
    this.marca,
    this.modelo,
    this.color,
  });

  factory VehiculoModel.fromJson(Map<String, dynamic> j) => VehiculoModel(
    idVehiculo: j['id_vehiculo'],
    usuarioId: j['usuario_id'],
    placa: j['placa'],
    marca: j['marca'],
    modelo: j['modelo'],
    color: j['color'],
  );
}
