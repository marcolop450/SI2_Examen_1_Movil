// #Ciclo5 CU25 - Modelo de consejo vial

class ConsejoVialModel {
  final int? idConsejo;
  final String categoria;
  final String titulo;
  final String contenido;
  final String icono;
  final bool activo;

  ConsejoVialModel({
    this.idConsejo,
    required this.categoria,
    required this.titulo,
    required this.contenido,
    required this.icono,
    required this.activo,
  });

  factory ConsejoVialModel.fromJson(Map<String, dynamic> j) => ConsejoVialModel(
    idConsejo: j['id_consejo'],
    categoria: j['categoria'] ?? 'general',
    titulo: j['titulo'] ?? '',
    contenido: j['contenido'] ?? '',
    icono: j['icono'] ?? '💡',
    activo: j['activo'] ?? true,
  );
}
