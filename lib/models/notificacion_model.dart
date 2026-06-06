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
        idNotificacion: j['id_notificacion'] ?? j['id'] ?? 0,
        usuarioId: j['usuario_id'] ?? j['usuarioId'] ?? 0,
        titulo: j['titulo']?.toString(),
        mensaje: j['mensaje']?.toString(),
        leido: j['leido_boolean'] ?? j['leido'] ?? false,
        fechaCreacion: j['fecha_creacion_timestamp']?.toString() ?? j['fecha_creacion']?.toString(),
      );
}
