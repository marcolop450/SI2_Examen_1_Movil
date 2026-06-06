// #Ciclo5 CU18 - Pantalla de cotizaciones con diseño premium y WS nueva_cotizacion
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/services/cotizacion_service.dart';
import '../../../core/constants/api_constants.dart';
import 'monitoreo_screen.dart';

class CotizacionesScreen extends StatefulWidget {
  final int incidenteId;
  const CotizacionesScreen({super.key, required this.incidenteId});

  @override
  State<CotizacionesScreen> createState() => _CotizacionesScreenState();
}

class _CotizacionesScreenState extends State<CotizacionesScreen> {
  static const _navy = Color(0xFF0D1B2A);
  static const _rojo = Color(0xFFE24B4A);

  List<dynamic> _cotizaciones = [];
  bool _isLoading = true;
  bool _aceptando = false;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _cargarCotizaciones();
    _conectarWS();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _wsChannel?.sink.close();
    super.dispose();
  }

  // Escuchar WS para nuevas cotizaciones en tiempo real
  void _conectarWS() {
    final uri = Uri.parse(ApiConstants.wsIncidenteUrl(widget.incidenteId));
    _wsChannel = WebSocketChannel.connect(uri);
    _wsSub = _wsChannel!.stream.listen((msg) {
      if (!mounted) return;
      final data = jsonDecode(msg) as Map<String, dynamic>;
      if (data['tipo'] == 'nueva_cotizacion') {
        // Recargar la lista cuando llega nueva cotización
        _cargarCotizaciones();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🔔 Nueva cotización de ${data['taller'] ?? 'un taller'}',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF1D4ED8),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }, onError: (_) {});
  }

  Future<void> _cargarCotizaciones() async {
    try {
      final data =
          await CotizacionService.getCotizaciones(widget.incidenteId);
      if (!mounted) return;
      setState(() {
        _cotizaciones =
            data.where((c) => c['estado'] == 'pendiente').toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _aceptar(Map<String, dynamic> cot) async {
    setState(() => _aceptando = true);
    try {
      await CotizacionService.aceptarCotizacion(cot['id_cotizacion']);
      if (!mounted) return;

      // #Ciclo5 FIX - Guardar precio para PagoScreen (viene de cotización aceptada)
      final precio = double.tryParse(
              cot['precio_estimado']?.toString() ?? '') ??
          double.tryParse(cot['precio']?.toString() ?? '') ?? 0.0;
      if (precio > 0) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('costo_servicio_${widget.incidenteId}', precio);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MonitoreoScreen(incidenteId: widget.incidenteId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _aceptando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: _rojo,
        ),
      );
    }
  }

  // Icono por especialidad
  String _iconoEspecialidad(String? esp) {
    if (esp == null) return '🔧';
    final e = esp.toLowerCase();
    if (e.contains('llant')) return '🛞';
    if (e.contains('motor') || e.contains('mecán')) return '⚙️';
    if (e.contains('elec') || e.contains('bater')) return '⚡';
    if (e.contains('carrocer') || e.contains('choque')) return '🚗';
    return '🔧';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💰 Cotizaciones',
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17),
            ),
            Text(
              'Emergencia #${widget.incidenteId}',
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              setState(() => _isLoading = true);
              _cargarCotizaciones();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _rojo))
          : _cotizaciones.isEmpty
              ? _buildEsperando()
              : _buildLista(),
    );
  }

  // Pantalla cuando aún no hay cotizaciones
  Widget _buildEsperando() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⏳', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            Text(
              'Esperando cotizaciones...',
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _navy),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Los talleres cercanos están revisando tu emergencia. Recibirás notificación cuando llegue una oferta.',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade600, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Animación de pulso
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1.1),
              duration: const Duration(milliseconds: 800),
              builder: (ctx, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: _rojo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _rojo.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _rojo),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Buscando talleres cercanos',
                      style: GoogleFonts.poppins(
                          color: _rojo, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLista() {
    return RefreshIndicator(
      color: _rojo,
      onRefresh: _cargarCotizaciones,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Header info
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF0D1B2A), Color(0xFF1B3A5C)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_cotizaciones.length} oferta(s) disponible(s)',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      Text(
                        'Ordenadas por menor precio · Escoge la mejor',
                        style: GoogleFonts.poppins(
                            color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Cards de cotización
          ...(_cotizaciones.asMap().entries.map((e) {
            final idx = e.key;
            final cot = e.value as Map<String, dynamic>;
            return _buildCotizacionCard(cot, idx == 0);
          })),
        ],
      ),
    );
  }

  Widget _buildCotizacionCard(Map<String, dynamic> cot, bool esMejor) {
    final precio = cot['precio_estimado'];
    final nombre = cot['nombre_taller'] ?? 'Taller';
    final tiempo = cot['tiempo_estimado_min'];
    final distancia = cot['distancia_km'];
    final descripcion = cot['descripcion'] ?? '';
    final especialidad = cot['especialidad_tecnico'];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Card(
        elevation: esMejor ? 6 : 3,
        shadowColor: esMejor
            ? const Color(0xFF059669).withValues(alpha: 0.3)
            : Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: esMejor
              ? const BorderSide(color: Color(0xFF059669), width: 2)
              : BorderSide.none,
        ),
        child: Column(
          children: [
            // Badge "Mejor oferta"
            if (esMejor)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFF059669),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Text(
                  '⭐ MEJOR OFERTA',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Taller nombre + especialidad
                  Row(
                    children: [
                      Text(
                        _iconoEspecialidad(especialidad),
                        style: const TextStyle(fontSize: 26),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: _navy),
                            ),
                            if (especialidad != null)
                              Text(
                                'Especialidad: $especialidad',
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ),
                      // Precio grande
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Bs. $precio',
                            style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: esMejor
                                    ? const Color(0xFF059669)
                                    : _navy),
                          ),
                          if (tiempo != null)
                            Text(
                              '~$tiempo min',
                              style: GoogleFonts.poppins(
                                  fontSize: 11, color: Colors.grey),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Chips: distancia
                  Row(
                    children: [
                      if (distancia != null)
                        _buildChip(
                            '📍 ${distancia.toStringAsFixed(1)} km',
                            const Color(0xFFDBEAFE),
                            const Color(0xFF1D4ED8)),
                      const SizedBox(width: 8),
                      if (tiempo != null)
                        _buildChip(
                            '⏱️ $tiempo min',
                            const Color(0xFFFEF3C7),
                            const Color(0xFFD97706)),
                    ],
                  ),
                  if (descripcion.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      descripcion,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 14),
                  // Botón Aceptar
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _aceptando ? null : () => _aceptar(cot),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: esMejor
                            ? const Color(0xFF059669)
                            : _rojo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: _aceptando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              'Aceptar esta cotización ✓',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 11, color: fg, fontWeight: FontWeight.w500)),
    );
  }
}
