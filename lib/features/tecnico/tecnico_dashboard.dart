// #Ciclo5 - TecnicoDashboard con mapa OSM, precio cotización y estados completos
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

import '../../core/auth_services/auth_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/incidente_service.dart';
import '../cliente/screens/pago_screen.dart';

class TecnicoDashboard extends StatefulWidget {
  const TecnicoDashboard({super.key});

  @override
  State<TecnicoDashboard> createState() => _TecnicoDashboardState();
}

class _TecnicoDashboardState extends State<TecnicoDashboard> {
  static const _navy = Color(0xFF0D1B2A);
  static const _rojo = Color(0xFFE24B4A);
  static const _verde = Color(0xFF2E7D32);
  static const _amber = Color(0xFFF59E0B);

  List<dynamic> _trabajos = [];
  bool _cargando = true;
  String? _gpsStatus;
  LatLng? _miPosicion;
  // #Ciclo5 FIX - Precios de cotización por incidente
  final Map<int, double> _preciosPorIncidente = {};

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSub;
  Timer? _gpsTimer;
  int? _incidenteActivoId;

  // MapControllers por incidente
  final Map<int, MapController> _mapControllers = {};

  @override
  void initState() {
    super.initState();
    _cargarMisTrabajos();
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _wsSub?.cancel();
    _wsChannel?.sink.close();
    super.dispose();
  }

  // ─── GET /incidentes/mis-trabajos ─────────────────────────────────────────────
  Future<void> _cargarMisTrabajos() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      final headers = await AuthService.authHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/incidentes/mis-trabajos'),
        headers: headers,
      );
      if (!mounted) return;
      List<dynamic> trabajos = [];
      if (response.statusCode == 200) {
        trabajos = jsonDecode(response.body) as List<dynamic>;
      } else {
        trabajos = await IncidenteService.obtenerAsignados();
      }
      setState(() {
        _trabajos = trabajos;
        _cargando = false;
      });
      // Buscar precios de cotización para cada trabajo
      for (final t in trabajos) {
        final id = t['id_incidente'] as int;
        await _fetchPrecioCotizacion(id, t);
      }
      if (trabajos.isNotEmpty) {
        _iniciarTracking(trabajos.first['id_incidente'] as int);
      } else {
        _detenerTracking();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        _mostrarSnack('Error al cargar: $e', isError: true);
      }
    }
  }

  // #Ciclo5 FIX - Obtener precio de cotización aceptada
  Future<void> _fetchPrecioCotizacion(
      int incidenteId, Map<String, dynamic> trabajo) async {
    // Primero intentar desde el propio trabajo
    final pDesdeTrabajoRaw = trabajo['precio_cotizacion']
        ?? trabajo['costo_final']
        ?? trabajo['precio_estimado'];
    if (pDesdeTrabajoRaw != null) {
      final p = double.tryParse(pDesdeTrabajoRaw.toString());
      if (p != null && p > 0) {
        if (mounted) setState(() => _preciosPorIncidente[incidenteId] = p);
        return;
      }
    }
    // Fallback: buscar en GET /cotizaciones/{id} la aceptada
    try {
      final headers = await AuthService.authHeaders();
      final resp = await http.get(
        Uri.parse(ApiConstants.cotizaciones(incidenteId)),
        headers: headers,
      );
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        final aceptada = list.firstWhere(
          (c) => c['estado'] == 'aceptada' || c['estado'] == 'accepted',
          orElse: () => list.isNotEmpty ? list.first : null,
        );
        if (aceptada != null) {
          final precio = double.tryParse(
              aceptada['precio_estimado']?.toString() ?? '');
          if (precio != null && precio > 0 && mounted) {
            setState(() => _preciosPorIncidente[incidenteId] = precio);
          }
        }
      }
    } catch (_) {}
  }

  // ─── Tracking GPS ──────────────────────────────────────────────────────────────
  void _iniciarTracking(int incidenteId) {
    if (_incidenteActivoId == incidenteId && _wsChannel != null) return;
    _detenerTracking();
    _incidenteActivoId = incidenteId;

    _wsChannel = WebSocketChannel.connect(
      Uri.parse(ApiConstants.wsIncidenteUrl(incidenteId)),
    );
    _wsSub = _wsChannel!.stream.listen((msg) {
      if (!mounted) return;
      final data = jsonDecode(msg) as Map<String, dynamic>;
      if (data['tipo'] == 'cambio_estado' &&
          data['estado'] == 'cancelado') {
        _mostrarSnack('⚠️ El cliente canceló el servicio');
        _detenerTracking();
        _cargarMisTrabajos();
      }
    }, onError: (_) {});

    _gpsTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      await _enviarUbicacion(incidenteId);
    });
    _enviarUbicacion(incidenteId);
  }

  void _detenerTracking() {
    _gpsTimer?.cancel();
    _wsSub?.cancel();
    _wsChannel?.sink.close();
    _wsChannel = null;
    _incidenteActivoId = null;
    if (mounted) setState(() => _gpsStatus = null);
  }

  Future<void> _enviarUbicacion(int incidenteId) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final headers = await AuthService.authHeaders();
      await http.put(
        Uri.parse(
            '${ApiConstants.baseUrl}/incidentes/$incidenteId/ubicacion-tecnico'),
        headers: headers,
        body: jsonEncode({
          'latitud': pos.latitude,
          'longitud': pos.longitude,
          'eta_minutos': null,
        }),
      );
      if (mounted) {
        setState(() {
          _miPosicion = LatLng(pos.latitude, pos.longitude);
          _gpsStatus =
              '📡 ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _gpsStatus = '⚠️ GPS no disponible');
    }
  }

  // ─── Cambiar estado ──────────────────────────────────────────────────────────
  Future<void> _cambiarEstado(int idIncidente, String nuevoEstado,
      {double? costoFinal}) async {
    try {
      await IncidenteService.actualizarEstado(idIncidente, nuevoEstado,
          costoFinal: costoFinal);
      _wsChannel?.sink.add(jsonEncode({
        'tipo': 'cambio_estado',
        'estado': nuevoEstado,
        'mensaje': _mensajeEstado(nuevoEstado),
        if (costoFinal != null) 'costo_final': costoFinal,
      }));
      if (nuevoEstado == 'atendido') _detenerTracking();
      await _cargarMisTrabajos();
      _mostrarSnack('Estado: ${_labelEstado(nuevoEstado)}');
    } catch (e) {
      _mostrarSnack('Error: $e', isError: true);
    }
  }

  String _mensajeEstado(String e) {
    switch (e) {
      case 'en_proceso': return 'El técnico va en camino';
      case 'en_atencion': return 'El técnico llegó y está atendiendo';
      case 'atendido': return 'Servicio finalizado';
      default: return e;
    }
  }

  String _labelEstado(String e) {
    switch (e) {
      case 'taller_asignado': return 'Asignado';
      case 'en_proceso': return '🚗 En camino';
      case 'en_atencion': return '🔧 Atendiendo';
      case 'atendido': return '✅ Finalizado';
      default: return e;
    }
  }

  // ─── Finalizar: muestra precio de cotización, NO editable ────────────────────
  Future<void> _mostrarConfirmacionFinalizar(
      int idIncidente, double precioCotizacion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('✅ Finalizar Servicio',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: _navy, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('El cliente pagará el precio acordado en la cotización:',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _verde.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _verde),
              ),
              child: Column(
                children: [
                  Text('TOTAL A COBRAR',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: _verde,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                  Text('Bs. ${precioCotizacion.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: _navy)),
                  Text('Precio de la cotización aceptada',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _verde,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
            label: Text('CONFIRMAR Y COBRAR',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _cambiarEstado(idIncidente, 'atendido',
          costoFinal: precioCotizacion);
    }
  }

  // ─── Cancelación con pago opcional ───────────────────────────────────────────
  Future<void> _mostrarDialogCancelacion(int idIncidente) async {
    final compensacionCtrl = TextEditingController(text: '0');
    String tipoSeleccionado = 'cancelacion_cliente';

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Cancelar Servicio',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _navy)),
              const SizedBox(height: 4),
              Text('Si el técnico ya se desplazó, podes cobrar compensación.',
                  style:
                      GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              for (final opt in [
                ['cancelacion_cliente', '⏳ Esperé demasiado'],
                ['llego_seguro_primero', '🛡️ Llegó mi seguro primero'],
                ['llegaron_ambos', '🤝 Llegamos a un acuerdo'],
              ])
                RadioListTile<String>(
                  dense: true,
                  value: opt[0],
                  groupValue: tipoSeleccionado,
                  activeColor: _rojo,
                  title: Text(opt[1], style: GoogleFonts.poppins(fontSize: 13)),
                  onChanged: (v) => setModal(() => tipoSeleccionado = v!),
                ),
              const SizedBox(height: 8),
              Text('Compensación Bs. — Pon 0 si no hubo desplazamiento',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: compensacionCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixText: 'Bs. ',
                  hintText: '0.00',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _rojo,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final monto =
                        double.tryParse(compensacionCtrl.text) ?? 0.0;
                    Navigator.pop(ctx,
                        {'tipo': tipoSeleccionado, 'monto': monto});
                  },
                  child: Text('Confirmar Cancelación',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null || !mounted) return;
    final monto = (result['monto'] as num).toDouble();
    final tipo = result['tipo'] as String;

    try {
      final headers = await AuthService.authHeaders();
      await http.post(
        Uri.parse(
            '${ApiConstants.baseUrl}/incidentes/$idIncidente/excepcion'),
        headers: headers,
        body: jsonEncode({
          'tipo_excepcion': tipo,
          'motivo': 'Cancelado desde app.',
          'compensacion_taller': monto,
        }),
      );
    } catch (_) {}

    if (!mounted) return;
    if (monto > 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PagoScreen(incidenteId: idIncidente, costoTotal: monto),
        ),
      );
    } else {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  Future<void> _abrirNavegacion(double lat, double lng) async {
    final uri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(
        Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  void _mostrarSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: isError ? _rojo : _verde,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⚙️ CENTRAL TÉCNICO',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            if (_gpsStatus != null)
              Text(_gpsStatus!,
                  style: GoogleFonts.poppins(
                      color: Colors.greenAccent, fontSize: 10)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarMisTrabajos,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              _detenerTracking();
              await AuthService.logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : _trabajos.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  color: _rojo,
                  onRefresh: _cargarMisTrabajos,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _trabajos.length,
                    itemBuilder: (ctx, i) =>
                        _buildTarjetaTrabajo(_trabajos[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radar, size: 90, color: Colors.green.shade300),
          const SizedBox(height: 16),
          Text('En línea y disponible',
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade600)),
          const SizedBox(height: 8),
          Text('Esperando asignación...',
              style: GoogleFonts.poppins(color: Colors.grey)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _cargarMisTrabajos,
            icon: const Icon(Icons.refresh),
            label: Text('Actualizar', style: GoogleFonts.poppins()),
            style: OutlinedButton.styleFrom(foregroundColor: _navy),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaTrabajo(dynamic trabajo) {
    final id = trabajo['id_incidente'] as int;
    final estado = trabajo['estado_enum'] as String? ?? 'taller_asignado';
    final descripcion =
        trabajo['descripcion_texto'] as String? ?? 'Sin descripción';
    // FIX: coordenadas pueden venir como String
    final lat = double.tryParse(trabajo['latitud_emergencia']?.toString() ?? '');
    final lng = double.tryParse(trabajo['longitud_emergencia']?.toString() ?? '');
    final especialidad =
        trabajo['especialidad_tecnico'] as String? ?? 'General';
    final nombre = trabajo['nombre_tecnico'] as String? ?? 'Técnico';
    // Precio desde el mapa de cotizaciones (cargado al iniciar)
    final precioCotizacion = _preciosPorIncidente[id] ?? 0.0;

    String diagIA = 'Diagnóstico pendiente';
    if (trabajo['evidencias'] != null &&
        (trabajo['evidencias'] as List).isNotEmpty) {
      diagIA = trabajo['evidencias'][0]['clasificacion_ia_texto'] ?? diagIA;
    }

    final Color colorEstado = estado == 'en_proceso'
        ? Colors.blue
        : estado == 'en_atencion'
            ? _amber
            : estado == 'atendido'
                ? _verde
                : const Color(0xFF6B7280);

    // MapController por incidente
    _mapControllers.putIfAbsent(id, () => MapController());

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      child: Column(
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: _navy,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Text('🔧', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EMERGENCIA #$id',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      Text('$nombre · $especialidad',
                          style: GoogleFonts.poppins(
                              color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorEstado.withValues(alpha: 0.2),
                    border: Border.all(color: colorEstado),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_labelEstado(estado),
                      style: GoogleFonts.poppins(
                          color: colorEstado,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // MAPA mini (cliente + técnico)
          if (lat != null && lng != null)
            SizedBox(
              height: 220,
              child: FlutterMap(
                mapController: _mapControllers[id],
                options: MapOptions(
                  initialCenter: LatLng(lat, lng),
                  initialZoom: 14.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.emergencias.movil',
                  ),
                  MarkerLayer(markers: [
                    // 📍 Cliente (rojo)
                    Marker(
                      point: LatLng(lat, lng),
                      width: 40,
                      height: 50,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_pin,
                              color: _rojo, size: 32),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                                color: _rojo,
                                borderRadius: BorderRadius.circular(4)),
                            child: Text('Cliente',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    // 🔧 Técnico (ámbar — posición GPS actual)
                    if (_miPosicion != null)
                      Marker(
                        point: _miPosicion!,
                        width: 44,
                        height: 54,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _amber,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          _amber.withValues(alpha: 0.4),
                                      blurRadius: 8)
                                ],
                              ),
                              child: const Icon(Icons.build,
                                  color: Colors.white, size: 16),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                  color: _amber,
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text('Yo',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                  ]),
                ],
              ),
            ),

          // Contenido
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // GPS status
                if (_incidenteActivoId == id && _gpsStatus != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.satellite_alt,
                            color: Colors.green, size: 13),
                        const SizedBox(width: 6),
                        Text(_gpsStatus!,
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.green.shade700)),
                      ],
                    ),
                  ),

                // Precio cotización
                if (precioCotizacion > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _verde.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _verde.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_money,
                            color: _verde, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Precio acordado (cotización)',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey.shade600)),
                              Text(
                                  'Bs. ${precioCotizacion.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _verde)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Diagnóstico IA
                Text('🤖 REPORTE IA:',
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _rojo)),
                const SizedBox(height: 4),
                Text(diagIA,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _navy)),
                const SizedBox(height: 8),
                Text('📋 Descripción:',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey.shade600)),
                Text(descripcion,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.grey.shade800)),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                _buildBotonesEstado(
                    id, estado, lat, lng, precioCotizacion),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonesEstado(int id, String estado, double? lat, double? lng,
      double precioCotizacion) {
    return Column(
      children: [
        if (lat != null && lng != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _abrirNavegacion(lat, lng),
              icon: const Icon(Icons.navigation, color: Colors.blue, size: 18),
              label: Text('📍 NAVEGAR AL CLIENTE',
                  style: GoogleFonts.poppins(
                      color: Colors.blue, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.blue),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        const SizedBox(height: 8),

        if (estado == 'taller_asignado')
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _cambiarEstado(id, 'en_proceso'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              icon: const Icon(Icons.directions_car,
                  color: Colors.white, size: 18),
              label: Text('🚗 INICIAR VIAJE',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),

        if (estado == 'en_proceso')
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _cambiarEstado(id, 'en_atencion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _amber,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              icon: const Icon(Icons.build, color: Colors.white, size: 18),
              label: Text('🔧 LLEGUÉ — Atendiendo',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),

        if (estado == 'en_atencion')
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              // Usa precio de cotización, no editable
              onPressed: () =>
                  _mostrarConfirmacionFinalizar(id, precioCotizacion),
              style: ElevatedButton.styleFrom(
                backgroundColor: _verde,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              icon: const Icon(Icons.check_circle,
                  color: Colors.white, size: 18),
              label: Text('✅ FINALIZAR — Bs. ${precioCotizacion.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),

        if (!['atendido', 'finalizado', 'cancelado'].contains(estado)) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _mostrarDialogCancelacion(id),
              icon: const Icon(Icons.cancel_outlined, color: _rojo, size: 18),
              label: Text('Cancelar Servicio',
                  style: GoogleFonts.poppins(
                      color: _rojo, fontWeight: FontWeight.w500)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _rojo),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],

        if (estado == 'atendido')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: _verde.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _verde),
            ),
            child: Text('🏁 Esperando pago del cliente',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    color: _verde,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
      ],
    );
  }
}
