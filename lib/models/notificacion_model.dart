// lib/models/notificacion_model.dart

class NotificacionModel {
  final int idNotificacion;
  final int usuarioId;
  final String? titulo;
  final String? mensaje;
  final bool leido;
  final String? fechaCreacion;

  NotificacionModel({
    required this.idNotificacion,
    required this.usuarioId,
    this.titulo,
    this.mensaje,
    required this.leido,
    this.fechaCreacion,
  });

  factory NotificacionModel.fromJson(Map<String, dynamic> j) =>
      NotificacionModel(
        idNotificacion: j['id_notificacion'],
        usuarioId: j['usuario_id'],
        titulo: j['titulo'],
        mensaje: j['mensaje'],
        leido: j['leido_boolean'] ?? false,
        fechaCreacion: j['fecha_creacion_timestamp'],
      );
}
