// lib/models/incidente_model.dart
// Mapea IncidenteOut del backend

class IncidenteModel {
  final int idIncidente;
  final int clienteId;
  final int vehiculoId;
  final String estadoEnum;
  final String prioridadEnum;
  final String? descripcionTexto;
  final int? tecnicoId;

  IncidenteModel({
    required this.idIncidente,
    required this.clienteId,
    required this.vehiculoId,
    required this.estadoEnum,
    required this.prioridadEnum,
    this.descripcionTexto,
    this.tecnicoId,
  });

  factory IncidenteModel.fromJson(Map<String, dynamic> j) => IncidenteModel(
    idIncidente: j['id_incidente'],
    clienteId: j['cliente_id'],
    vehiculoId: j['vehiculo_id'],
    estadoEnum: j['estado_enum'],
    prioridadEnum: j['prioridad_enum'],
    descripcionTexto: j['descripcion_texto'],
    tecnicoId: j['tecnico_id'],
  );
}
