// #Ciclo5 - Modelo de incidente actualizado con campos del nuevo flujo
class IncidenteModel {
  final int? idIncidente;
  final int? clienteId;
  final int? vehiculoId;
  final String estadoEnum;
  final String? prioridadEnum;
  final String? descripcionTexto;
  final int? tecnicoId;
  final int? tallerActualId; // #Ciclo5 - null hasta que cliente acepta cotización
  final double? costoFinalDecimal; // #Ciclo5 - costo final del servicio
  final String? uuidOffline; // #Ciclo5 CU19 - UUID para deduplicación offline
  final String? categoriaIa; // #Ciclo5 CU25 - Categoría extraída de la IA
  final String? diagnosticoIa; // #Ciclo5 CU25 - Diagnóstico completo de la IA
  final double? latitudTecnico;
  final double? longitudTecnico;

  IncidenteModel({
    this.idIncidente,
    this.clienteId,
    this.vehiculoId,
    required this.estadoEnum,
    this.prioridadEnum,
    this.descripcionTexto,
    this.tecnicoId,
    this.tallerActualId,
    this.costoFinalDecimal,
    this.uuidOffline,
    this.categoriaIa,
    this.diagnosticoIa,
    this.latitudTecnico,
    this.longitudTecnico,
  });

  factory IncidenteModel.fromJson(Map<String, dynamic> j) {
    // #Ciclo5 CU25 - Parsear categoria_ia de evidencias[0].clasificacion_ia_texto
    String? catIa;
    String? diagIa;
    if (j['evidencias'] != null && (j['evidencias'] as List).isNotEmpty) {
      final texto =
          j['evidencias'][0]['clasificacion_ia_texto']?.toString() ?? '';
      if (texto.isNotEmpty) {
        final match = RegExp(r'\[(\w+)\]').firstMatch(texto);
        catIa = match?.group(1)?.toLowerCase();
        diagIa = texto;
      }
    }

    return IncidenteModel(
      idIncidente: j['id_incidente'],
      clienteId: j['cliente_id'],
      vehiculoId: j['vehiculo_id'],
      estadoEnum: j['estado_enum'] ?? 'buscando_taller',
      prioridadEnum: j['prioridad_enum'],
      descripcionTexto: j['descripcion_texto'],
      tecnicoId: j['tecnico_id'],
      tallerActualId: j['taller_actual_id'],
      costoFinalDecimal: j['costo_final_decimal'] != null
          ? double.tryParse(j['costo_final_decimal'].toString())
          : null,
      uuidOffline: j['uuid_offline'],
      categoriaIa: catIa,
      diagnosticoIa: diagIa,
      latitudTecnico: j['latitud_tecnico'] != null
          ? double.tryParse(j['latitud_tecnico'].toString())
          : null,
      longitudTecnico: j['longitud_tecnico'] != null
          ? double.tryParse(j['longitud_tecnico'].toString())
          : null,
    );
  }
}
