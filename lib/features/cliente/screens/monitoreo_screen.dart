import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../core/services/incidente_service.dart';
import 'pago_screen.dart';

class MonitoreoScreen extends StatefulWidget {
  final int incidenteId;
  const MonitoreoScreen({super.key, required this.incidenteId});

  @override
  State<MonitoreoScreen> createState() => _MonitoreoScreenState();
}

class _MonitoreoScreenState extends State<MonitoreoScreen> {
  static const _navy = Color(0xFF0D1B2A);
  static const _rojo = Color(0xFFE24B4A);
  static const _verde = Color(0xFF2E7D32);

  Map<String, dynamic>? _datos;
  Timer? _pollingTimer;
  String _estadoAnterior = 'pendiente';

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _obtenerEstado();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _obtenerEstado();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> mostrarNotificacionNativa(String titulo, String cuerpo) async {
    final AndroidNotificationDetails androidDetails =
        const AndroidNotificationDetails(
          'emergencias_channel',
          'Alertas de Auxilio',
          channelDescription: 'Notificaciones sobre el estado de tu mecánico',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          color: _rojo,
        );

    final NotificationDetails detalles = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: titulo,
      body: cuerpo,
      notificationDetails: detalles,
    );
  }

  // 🔥 NUEVA FUNCIÓN: Muestra el anuncio antes de ir al pago
  void _mostrarAnuncioPago(double monto) {
    showDialog(
      context: context,
      barrierDismissible: false, // Obliga al usuario a interactuar
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "📢 ¡SERVICIO FINALIZADO!",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _navy),
        ),
        content: Text(
          "El técnico ha reportado el trabajo terminado.\n\nEl costo total es de Bs. ${monto.toStringAsFixed(2)}.\n\n¿Deseas proceder al pago?",
          style: GoogleFonts.poppins(fontSize: 16),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _verde,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(context); // Cierra el anuncio
                // Navega a la pantalla de pago
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PagoScreen(
                      incidenteId: widget.incidenteId,
                      costoTotal: monto,
                    ),
                  ),
                );
              },
              child: Text(
                "IR A PAGAR",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _obtenerEstado() async {
    try {
      final datos = await IncidenteService.monitorearEmergencia(
        widget.incidenteId,
      );
      if (!mounted) return;

      setState(() => _datos = datos);

      final estadoActual = datos['estado_actual'];
      if (estadoActual != _estadoAnterior) {
        if (estadoActual == 'en_proceso') {
          mostrarNotificacionNativa(
            '¡Técnico Asignado! 🚗',
            'El mecánico va en camino a tu ubicación.',
          );
        } else if (estadoActual == 'atendido') {
          _pollingTimer?.cancel();

          mostrarNotificacionNativa(
            'Servicio Completado ✅',
            'Tu técnico ha finalizado el trabajo. Revisa el costo final.',
          );

          // Leemos el costo dinámico (Asegúrate de que 'costo_final_decimal' sea el nombre correcto de tu DB)
          final costoString = datos['costo_final_decimal']?.toString() ?? '0.0';
          final costoFinal = double.tryParse(costoString) ?? 0.0;

          // 🔥 Mostramos el anuncio en lugar de ir directo
          _mostrarAnuncioPago(costoFinal);
        }
        _estadoAnterior = estadoActual;
      }
    } catch (e) {
      print("Error obteniendo estado: $e");
    }
  }

  Future<void> _abrirMapa() async {
    final lat = _datos?['latitud_tecnico'];
    final lng = _datos?['longitud_tecnico'];
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esperando señal GPS del técnico...')),
      );
      return;
    }
    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _cancelarServicio() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar Auxilio?'),
        content: const Text('¿Estás seguro de que ya no necesitas asistencia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, mantener'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sí, cancelar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await IncidenteService.actualizarEstado(
          widget.incidenteId,
          'cancelado',
        );
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove('incidente_activo_id');

        if (mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Servicio cancelado exitosamente.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cancelar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_datos == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Conectando...',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: _navy,
        ),
        body: const Center(child: CircularProgressIndicator(color: _rojo)),
      );
    }

    final estado = _datos!['estado_actual'];
    final tecnico = _datos!['tecnico_asignado'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: _navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Emergencia #${widget.incidenteId}',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Icon(
              estado == 'pendiente' ? Icons.search : Icons.directions_car,
              size: 80,
              color: estado == 'pendiente' ? Colors.orange : Colors.blue,
            ),
            const SizedBox(height: 10),
            Text(
              estado == 'pendiente'
                  ? 'Buscando el taller más cercano...'
                  : '¡Auxilio en Camino!',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _navy,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            if (tecnico != null)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        tecnico['nombre'],
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        tecnico['especialidad'] ?? 'Mecánico',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const Divider(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _abrirMapa,
                          icon: const Icon(Icons.radar, color: Colors.blue),
                          label: Text(
                            'Ver ubicación del Técnico',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.blue),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _navy),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Seguir esperando en 2do plano',
                  style: GoogleFonts.poppins(
                    color: _navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _cancelarServicio,
              icon: const Icon(Icons.cancel, color: Colors.red),
              label: Text(
                'CANCELAR SOLICITUD',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
