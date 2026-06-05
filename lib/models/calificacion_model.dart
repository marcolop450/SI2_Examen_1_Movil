// #Ciclo5 CU23 - Modelo de calificación post-servicio
// lib/models/calificacion_model.dart

class CalificacionModel {
  final int? idCalificacion;
  final int incidenteId;
  final int? clienteId;
  final int? tallerId;
  final int? tecnicoId;
  final int puntuacion;
  final String? comentario;
  final String? fechaCalificacion;
  final String? clienteNombre;

  CalificacionModel({
    this.idCalificacion,
    required this.incidenteId,
    this.clienteId,
    this.tallerId,
    this.tecnicoId,
    required this.puntuacion,
    this.comentario,
    this.fechaCalificacion,
    this.clienteNombre,
  });

  factory CalificacionModel.fromJson(Map<String, dynamic> j) =>
      CalificacionModel(
        idCalificacion: j['id_calificacion'],
        incidenteId: j['incidente_id'],
        clienteId: j['cliente_id'],
        tallerId: j['taller_id'],
        tecnicoId: j['tecnico_id'],
        puntuacion: j['puntuacion'],
        comentario: j['comentario'],
        fechaCalificacion: j['fecha_calificacion'],
        clienteNombre: j['cliente_nombre'],
      );

  Map<String, dynamic> toJson() => {
        'id_calificacion': idCalificacion,
        'incidente_id': incidenteId,
        'cliente_id': clienteId,
        'taller_id': tallerId,
        'tecnico_id': tecnicoId,
        'puntuacion': puntuacion,
        'comentario': comentario,
        'fecha_calificacion': fechaCalificacion,
        'cliente_nombre': clienteNombre,
      };
}
