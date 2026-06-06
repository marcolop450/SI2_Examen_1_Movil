// #Ciclo5 CU9 - Monitoreo: mapa + detalles técnico/costo + pago y calificación
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/incidente_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/auth_services/auth_service.dart';
import 'pago_screen.dart';
import 'calificacion_screen.dart';
import 'consejos_seguridad_screen.dart';

class MonitoreoScreen extends StatefulWidget {
  final int incidenteId;
  const MonitoreoScreen({super.key, required this.incidenteId});

  @override
  State<MonitoreoScreen> createState() => _MonitoreoScreenState();
}

class _MonitoreoScreenState extends State<MonitoreoScreen> {
  static const _navy  = Color(0xFF0D1B2A);
  static const _rojo  = Color(0xFFE24B4A);
  static const _verde = Color(0xFF2E7D32);

  Map<String, dynamic>? _datos;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSub;
  final MapController _mapController = MapController();

  LatLng? _posicionTecnico;
  LatLng? _posicionCliente;
  double? _etaMinutos;
  double? _distanciaKm;
  bool _yaCalificado = false;
  bool _yaPago       = false;
  double _costoFinal = 0.0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _cargarPrecioYEstado();   // 1) prefs (instantáneo)
    _obtenerEstadoInicial();        // 2) API monitoreo
    _conectarWebSocket();           // 3) WS
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _wsChannel?.sink.close();
    super.dispose();
  }

  // ─── 1. SharedPreferences ────────────────────────────────────────────────────
  Future<void> _cargarPrecioYEstado() async {
    final prefs = await SharedPreferences.getInstance();
    final precio = prefs.getDouble('costo_servicio_${widget.incidenteId}') ?? 0.0;
    final pagado = prefs.getBool('pagado_${widget.incidenteId}') ?? false;
    if (mounted) {
      setState(() {
        if (precio > 0) _costoFinal = precio;
        _yaPago = pagado;
      });
    }
    // Si sigue en 0, consultar cotizaciones
    if (_costoFinal <= 0) await _fetchCostoDesdeAPI();
  }

  // ─── 2. Fallback: GET /cotizaciones/{id} ─────────────────────────────────────
  Future<void> _fetchCostoDesdeAPI() async {
    try {
      final headers = await AuthService.authHeaders();
      final resp = await http.get(
        Uri.parse(ApiConstants.cotizaciones(widget.incidenteId)),
        headers: headers,
      );
      if (!mounted || resp.statusCode != 200) return;
      final list = jsonDecode(resp.body) as List<dynamic>;
      if (list.isEmpty) return;

      // Preferir aceptada, sino la primera
      Map<String, dynamic>? aceptada;
      for (final c in list) {
        final e = (c['estado'] as String? ?? '').toLowerCase();
        if (e == 'aceptada' || e == 'accepted' || e == 'aceptado') {
          aceptada = c as Map<String, dynamic>;
          break;
        }
      }
      aceptada ??= list.first as Map<String, dynamic>;

      final precio =
          double.tryParse(aceptada['precio_estimado']?.toString() ?? '') ??
          double.tryParse(aceptada['precio']?.toString() ?? '') ??
          double.tryParse(aceptada['monto']?.toString() ?? '') ?? 0.0;

      if (precio > 0 && mounted) {
        setState(() => _costoFinal = precio);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('costo_servicio_${widget.incidenteId}', precio);
      }
    } catch (_) {}
  }

  // ─── 3. WebSocket ─────────────────────────────────────────────────────────────
  void _conectarWebSocket() {
    _wsChannel = WebSocketChannel.connect(
      Uri.parse(ApiConstants.wsIncidenteUrl(widget.incidenteId)),
    );
    _wsSub = _wsChannel!.stream.listen((msg) {
      if (!mounted) return;
      final data = jsonDecode(msg) as Map<String, dynamic>;
      final tipo = data['tipo'] as String? ?? '';

      if (tipo == 'ubicacion_tecnico') {
        final lat = double.tryParse(data['latitud']?.toString() ?? '');
        final lng = double.tryParse(data['longitud']?.toString() ?? '');
        if (lat != null && lng != null) {
          setState(() {
            _posicionTecnico = LatLng(lat, lng);
            _etaMinutos = (data['eta_minutos'] as num?)?.toDouble();
            if (_posicionCliente != null) {
              _distanciaKm = const Distance().as(
                LengthUnit.Kilometer, _posicionTecnico!, _posicionCliente!);
            }
          });
          _ajustarVistaAmbos();
        }
      } else if (tipo == 'cambio_estado') {
        final estado = data['estado'] as String? ?? '';
        final c = double.tryParse(data['costo_final']?.toString() ?? '') ?? 0.0;
        setState(() {
          if (_datos != null) _datos!['estado_actual'] = estado;
          if (c > 0) _costoFinal = c;
        });
        if (['atendido', 'finalizado'].contains(estado) && c > 0) {
          _mostrarAnuncioPago(c);
        }
      }
    }, onError: (_) => Future.delayed(const Duration(seconds: 3), _conectarWebSocket));
  }

  // ─── 4. GET monitoreo ─────────────────────────────────────────────────────────
  Future<void> _obtenerEstadoInicial() async {
    final prefs = await SharedPreferences.getInstance();
    final latL = prefs.getDouble('emergencia_lat');
    final lngL = prefs.getDouble('emergencia_lng');
    if (latL != null && lngL != null && _posicionCliente == null) {
      setState(() => _posicionCliente = LatLng(latL, lngL));
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) try { _mapController.move(_posicionCliente!, 15.0); } catch (_) {}
    }
    try {
      final datos = await IncidenteService.monitorearEmergencia(widget.incidenteId);
      if (!mounted) return;
      setState(() => _datos = datos);

      final lat = double.tryParse(datos['latitud_emergencia']?.toString() ?? '')
          ?? double.tryParse(datos['latitud']?.toString() ?? '') ?? latL;
      final lng = double.tryParse(datos['longitud_emergencia']?.toString() ?? '')
          ?? double.tryParse(datos['longitud']?.toString() ?? '') ?? lngL;
      if (lat != null && lng != null && _posicionCliente == null) {
        setState(() => _posicionCliente = LatLng(lat, lng));
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) try { _mapController.move(_posicionCliente!, 15.0); } catch (_) {}
      }

      // costo_final o precio_cotizacion del backend
      final costoB =
          double.tryParse(datos['precio_cotizacion_aceptada']?.toString() ?? '') ??
          double.tryParse(datos['precio_cotizacion']?.toString() ?? '') ??
          double.tryParse(datos['costo_final_decimal']?.toString() ?? '') ??
          double.tryParse(datos['costo_final']?.toString() ?? '') ?? 0.0;
      if (costoB > 0 && mounted) {
        setState(() => _costoFinal = costoB);
        // Persistir para próximas aperturas
        final prefs2 = await SharedPreferences.getInstance();
        await prefs2.setDouble('costo_servicio_${widget.incidenteId}', costoB);
      }

      final latT = double.tryParse(datos['latitud_tecnico']?.toString() ?? '');
      final lngT = double.tryParse(datos['longitud_tecnico']?.toString() ?? '');
      if (latT != null && lngT != null) {
        setState(() => _posicionTecnico = LatLng(latT, lngT));
        _ajustarVistaAmbos();
      }
    } catch (_) {}
  }

  void _ajustarVistaAmbos() {
    if (_posicionCliente == null && _posicionTecnico == null) return;
    final pos = (_posicionCliente != null && _posicionTecnico != null)
        ? LatLng((_posicionCliente!.latitude + _posicionTecnico!.latitude) / 2,
                 (_posicionCliente!.longitude + _posicionTecnico!.longitude) / 2)
        : (_posicionCliente ?? _posicionTecnico!);
    try { _mapController.move(pos, 13.0); } catch (_) {}
  }

  // ─── Pago ─────────────────────────────────────────────────────────────────────
  Future<void> _marcarComoPagado() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pagado_${widget.incidenteId}', true);
    if (mounted) setState(() => _yaPago = true);
  }

  void _mostrarAnuncioPago(double monto) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('📢 ¡Servicio Finalizado!',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _navy)),
        content: Text('Costo total: Bs. ${monto.toStringAsFixed(2)}\n\n¿Procedemos al pago?',
            style: GoogleFonts.poppins(fontSize: 15)),
        actions: [
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _verde,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                Navigator.pop(ctx);
                final r = await Navigator.push<bool>(context, MaterialPageRoute(
                    builder: (_) => PagoScreen(incidenteId: widget.incidenteId, costoTotal: monto)));
                if (r == true) _marcarComoPagado();
              },
              child: Text('IR A PAGAR',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            )),
        ],
      ),
    );
  }

  // ─── Cancelación ──────────────────────────────────────────────────────────────
  void _mostrarDialogoCancelacion() {
    String tipo = 'cancelacion_cliente';
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setM) => Container(
          decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: EdgeInsets.only(left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Text('¿Por qué cancelás?',
                  style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              for (final opt in [
                ['cancelacion_cliente', '⏳ Esperé demasiado'],
                ['llego_seguro_primero', '🛡️ Llegó mi seguro primero'],
                ['llegaron_ambos', '🤝 Llegamos a un acuerdo'],
              ])
                RadioListTile<String>(dense: true, value: opt[0],
                    groupValue: tipo, activeColor: _rojo,
                    title: Text(opt[1], style: GoogleFonts.poppins(fontSize: 13)),
                    onChanged: (v) => setM(() => tipo = v!)),
              const SizedBox(height: 6),
              Text('Compensación Bs. (0 si no se desplazó)',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange.shade700)),
              const SizedBox(height: 4),
              TextField(controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(prefixText: 'Bs. ', hintText: '0.00',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _rojo,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    final monto = double.tryParse(ctrl.text) ?? 0.0;
                    Navigator.pop(ctx);
                    try {
                      final h = await AuthService.authHeaders();
                      await http.post(Uri.parse(
                          '${ApiConstants.baseUrl}/incidentes/${widget.incidenteId}/excepcion'),
                        headers: h,
                        body: jsonEncode({'tipo_excepcion': tipo,
                          'motivo': 'Cancelado por cliente.', 'compensacion_taller': monto}));
                    } catch (_) {}
                    if (!mounted) return;
                    if (monto > 0) {
                      Navigator.pushReplacement(context, MaterialPageRoute(
                          builder: (_) => PagoScreen(incidenteId: widget.incidenteId, costoTotal: monto)));
                    } else {
                      Navigator.popUntil(context, (r) => r.isFirst);
                    }
                  },
                  child: Text('Confirmar Cancelación',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                )),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Getters ──────────────────────────────────────────────────────────────────
  String get _estadoActual => _datos?['estado_actual'] as String? ?? 'buscando_taller';

  String get _labelEstado {
    switch (_estadoActual) {
      case 'buscando_taller': return '🔍 Buscando taller...';
      case 'taller_asignado': return '✅ Taller confirmado';
      case 'en_proceso':      return '🚗 Técnico en camino';
      case 'en_atencion':     return '🔧 En atención';
      case 'atendido':        return '✅ Servicio completado';
      case 'finalizado':      return '🏁 Finalizado';
      case 'cancelado':       return '❌ Cancelado';
      default:                return '⏳ Procesando...';
    }
  }

  Color get _colorEstado {
    switch (_estadoActual) {
      case 'en_proceso':           return Colors.blue;
      case 'en_atencion':          return Colors.orange;
      case 'atendido':
      case 'finalizado':           return _verde;
      case 'cancelado':            return _rojo;
      default:                     return const Color(0xFFF59E0B);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: _navy, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Seguimiento #${widget.incidenteId}',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(_labelEstado, style: GoogleFonts.poppins(color: _colorEstado, fontSize: 11)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
              onPressed: _obtenerEstadoInicial),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          if (['buscando_taller', 'taller_asignado', 'en_proceso'].contains(_estadoActual))
            _buildBannerConsejos(),
          _buildDetallesCard(),
          Expanded(child: _buildMapa()),
          _buildLeyenda(),
          // Botón pagar
          if (['atendido', 'finalizado'].contains(_estadoActual) && !_yaPago)
            _buildBotonPagar(),
          // Botón calificar (solo después de pagar)
          if (['atendido', 'finalizado'].contains(_estadoActual) && _yaPago && !_yaCalificado)
            _buildBotonCalificar(),
          // Botón cancelar
          if (!['atendido', 'finalizado', 'cancelado'].contains(_estadoActual))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity, height: 46,
                child: OutlinedButton.icon(
                  onPressed: _mostrarDialogoCancelacion,
                  icon: const Icon(Icons.cancel_outlined, color: _rojo, size: 18),
                  label: Text('Cancelar Servicio',
                      style: GoogleFonts.poppins(color: _rojo, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _rojo),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  // ─── Tarjeta detalles: técnico + costo ───────────────────────────────────────
  Widget _buildDetallesCard() {
    final tecnico = _datos?['tecnico_asignado'] as Map<String, dynamic>?;
    final nombreTecnico = tecnico?['nombre'] as String?
        ?? _datos?['nombre_tecnico'] as String?;
    final nombreTaller = _datos?['nombre_taller'] as String?
        ?? _datos?['taller_responsable'] as String?;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _colorEstado.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.build_circle, color: _colorEstado, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_labelEstado,
                style: GoogleFonts.poppins(color: _colorEstado, fontSize: 12,
                    fontWeight: FontWeight.bold)),
            if (nombreTecnico != null) ...[
              const SizedBox(height: 2),
              Text('Técnico: $nombreTecnico',
                  style: GoogleFonts.poppins(color: _navy, fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
            if (nombreTaller != null) ...[
              Text('Taller: $nombreTaller',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 11)),
            ],
            if (_etaMinutos != null && !['atendido', 'finalizado'].contains(_estadoActual))
              Text('⏱ ETA: ${_etaMinutos!.toInt()} min',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.orange.shade700)),
          ]),
        ),
        // Costo
        if (_costoFinal > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _verde.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _verde.withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              Text('TOTAL', style: GoogleFonts.poppins(fontSize: 9, color: _verde,
                  fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              Text('Bs. ${_costoFinal.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
            ]),
          )
        else if (['atendido', 'finalizado'].contains(_estadoActual))
          // Spinner mientras carga
          const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: _verde)),
      ]),
    );
  }

  // ─── Mapa ─────────────────────────────────────────────────────────────────────
  Widget _buildMapa() {
    final center = _posicionCliente ?? _posicionTecnico ?? const LatLng(-17.7833, -63.1821);
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center, initialZoom: 15.0,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
        onMapReady: () {
          if (_posicionCliente != null) {
            try { _mapController.move(_posicionCliente!, 15.0); } catch (_) {}
          }
        },
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.emergencias.movil'),
        MarkerLayer(markers: [
          if (_posicionCliente != null)
            Marker(point: _posicionCliente!, width: 52, height: 62,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6)]),
                  child: const Icon(Icons.location_pin, color: _rojo, size: 28)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: _rojo, borderRadius: BorderRadius.circular(4)),
                  child: Text('Tú', style: GoogleFonts.poppins(color: Colors.white, fontSize: 9,
                      fontWeight: FontWeight.bold))),
              ])),
          if (_posicionTecnico != null)
            Marker(point: _posicionTecnico!, width: 62, height: 68,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFF59E0B), shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                          blurRadius: 10, spreadRadius: 2)]),
                  child: const Icon(Icons.build, color: Colors.white, size: 22)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('Técnico', style: GoogleFonts.poppins(color: Colors.white, fontSize: 9,
                      fontWeight: FontWeight.bold))),
              ])),
        ]),
      ],
    );
  }

  Widget _buildLeyenda() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        const Icon(Icons.location_pin, color: _rojo, size: 14),
        Text(' Tú  ', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade700)),
        const Icon(Icons.build_circle, color: Color(0xFFF59E0B), size: 14),
        Text(' Técnico', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade700)),
        if (_distanciaKm != null) ...[
          const Spacer(),
          Text('📍 ${_distanciaKm!.toStringAsFixed(1)} km',
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }

  Widget _buildBannerConsejos() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ConsejosSeguridad(incidenteId: widget.incidenteId))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF0D1B2A)]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Text('🛡️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text('Tips de seguridad mientras esperas →',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500))),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 14),
        ]),
      ),
    );
  }

  // ─── Botón PAGAR ──────────────────────────────────────────────────────────────
  Widget _buildBotonPagar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: SizedBox(
        width: double.infinity, height: 54,
        child: ElevatedButton(
          onPressed: _costoFinal > 0 ? () async {
            // Navegar a PagoScreen y SIEMPRE re-leer prefs al volver
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) =>
                  PagoScreen(incidenteId: widget.incidenteId, costoTotal: _costoFinal)),
            );
            // #Ciclo5 FIX - Recargar estado de pago desde SharedPreferences
            // independientemente de lo que haya devuelto PagoScreen
            if (mounted) await _cargarPrecioYEstado();
          } : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _verde,
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 3,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.payment, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Column(mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PAGAR SERVICIO',
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(_costoFinal > 0 ? 'Bs. ${_costoFinal.toStringAsFixed(2)}' : 'Cargando monto...',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildBotonCalificar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: SizedBox(
        width: double.infinity, height: 50,
        child: ElevatedButton.icon(
          onPressed: () async {
            final r = await Navigator.push<bool>(context, MaterialPageRoute(
                builder: (_) => CalificacionScreen(
                  incidenteId: widget.incidenteId,
                  nombreTaller: _datos?['tecnico_asignado']?['nombre'],
                )));
            if (r == true && mounted) setState(() => _yaCalificado = true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Text('⭐', style: TextStyle(fontSize: 18)),
          label: Text('Califica este servicio',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        ),
      ),
    );
  }
}
