// #Ciclo5 CU23/CU25 - Monitoreo con botón de calificación y consejos de seguridad
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../core/services/incidente_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/auth_services/auth_service.dart';
import 'pago_screen.dart';
import 'calificacion_screen.dart'; // #Ciclo5 CU23
import 'consejos_seguridad_screen.dart'; // #Ciclo5 CU25
import 'package:http/http.dart' as http;

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
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSub;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // #Ciclo5 CU23 - Estado de calificación
  bool _yaCalificado = false;



  @override
  void initState() {
    super.initState();

    _conectarWebSocket();
    _obtenerEstado(); // Mantenemos tu llamada original
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _wsChannel?.sink.close();
    _pollingTimer?.cancel();

    super.dispose();
  }

  // #Ciclo5 CU19 - Usar ApiConstants.wsIncidenteUrl dinámico
  void _conectarWebSocket() {
    final uri = Uri.parse(
      ApiConstants.wsIncidenteUrl(widget.incidenteId),
    );

    _wsChannel = WebSocketChannel.connect(uri);

    _wsSub = _wsChannel!.stream.listen(
      (mensaje) {
        final data = jsonDecode(mensaje) as Map<String, dynamic>;
        final tipo = data['tipo'] as String;

        if (!mounted) return;
        setState(() {
          // ------------------------------------------------
          // Actualizar ubicación del técnico en el mapa
          // ------------------------------------------------
          if (tipo == 'ubicacion_tecnico') {
            if (_datos != null) {
              _datos!['latitud_tecnico'] = data['latitud'];
              _datos!['longitud_tecnico'] = data['longitud'];
              _datos!['eta_minutos'] = data['eta_minutos'];
            }
          }

          // ------------------------------------------------
          // Actualizar estado del incidente
          // ------------------------------------------------
          if (tipo == 'cambio_estado') {
            final nuevoEstado = data['estado'] as String;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  data['mensaje'] ?? 'Estado actualizado: $nuevoEstado',
                ),
                backgroundColor: Colors.green,
              ),
            );

            // Extraemos el costo y usamos el método correcto
            if (nuevoEstado == 'finalizado') {
              final costoString = data['costo_final']?.toString() ?? '0.0';
              final costoFinal = double.tryParse(costoString) ?? 0.0;

              _mostrarAnuncioPago(costoFinal);
            }
          }
        });
      },
      onError: (error) {
        // Reconectar automáticamente después de 3 segundos
        Future.delayed(const Duration(seconds: 3), _conectarWebSocket);
      },
      onDone: () {
        // Reconectar si se cerró inesperadamente
        if (mounted) {
          Future.delayed(const Duration(seconds: 3), _conectarWebSocket);
        }
      },
    );
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

  void _mostrarDialogoCancelacion() {
    String tipoSeleccionado = 'cancelacion_cliente';
    final compensacionCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // permite que el teclado no tape el modal
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Por qué cancelás?',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Opción 1
              RadioListTile<String>(
                title: Text(
                  'Esperé demasiado',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                value: 'cancelacion_cliente',
                groupValue: tipoSeleccionado,
                onChanged: (v) => setModalState(() => tipoSeleccionado = v!),
              ),

              // Opción 2
              RadioListTile<String>(
                title: Text(
                  'Llegó mi seguro primero',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                value: 'llego_seguro_primero',
                groupValue: tipoSeleccionado,
                onChanged: (v) => setModalState(() => tipoSeleccionado = v!),
              ),

              // Opción 3
              RadioListTile<String>(
                title: Text(
                  'Llegamos ambos (taller + seguro)',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                value: 'llegaron_ambos',
                groupValue: tipoSeleccionado,
                onChanged: (v) => setModalState(() => tipoSeleccionado = v!),
              ),

              // Campo compensación — aparece siempre porque el taller se desplazó
              const SizedBox(height: 8),
              Text(
                'Compensación al taller por desplazamiento (Bs.)',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: compensacionCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Ej: 50',
                  prefixText: 'Bs. ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: 'Ingresá 0 si no hubo desplazamiento',
                ),
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE24B4A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final monto = double.tryParse(compensacionCtrl.text) ?? 0.0;

                    // Validar: si el taller llegó, debe haber compensación
                    if (tipoSeleccionado == 'llegaron_ambos' && monto <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Debés ingresar un monto mayor a 0 cuando el taller llegó.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(ctx);

                    try {
                      final headers = await AuthService.authHeaders();
                      final response = await http.post(
                        Uri.parse(
                          '${ApiConstants.baseUrl}/incidentes/${widget.incidenteId}/excepcion',
                        ),
                        headers: headers,
                        body: jsonEncode({
                          'tipo_excepcion': tipoSeleccionado,
                          'motivo': 'Cancelado por el cliente desde la app.',
                          'compensacion_taller': monto,
                        }),
                      );

                      if (response.statusCode == 200 && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              monto > 0
                                  ? 'Servicio cancelado. Compensación de $monto Bs. enviada al taller.'
                                  : 'Servicio cancelado correctamente.',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                        // Volver al inicio del cliente
                        Navigator.pushReplacementNamed(
                          context,
                          '/cliente/home',
                        );
                      }
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Error al cancelar el servicio.'),
                          ),
                        );
                    }
                  },
                  child: Text(
                    'Confirmar Cancelación',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Muestra el anuncio antes de ir al pago
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

          // Leemos el costo dinámico
          final costoString = datos['costo_final_decimal']?.toString() ?? '0.0';
          final costoFinal = double.tryParse(costoString) ?? 0.0;

          // Mostramos el anuncio en lugar de ir directo
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

  // =========================================================
  // #Ciclo5 CU25 - Banner de consejos de seguridad vial
  // =========================================================
  Widget _buildBannerConsejos(String estado) {
    final estadosEspera = [
      'buscando_taller',
      'taller_asignado',
      'en_camino',
      'pendiente'
    ];
    if (!estadosEspera.contains(estado)) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConsejosSeguridad(incidenteId: widget.incidenteId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A5F), Color(0xFF0D1B2A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3A5F).withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('🛡️', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tips de Seguridad',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Consejos mientras esperas auxilio →',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // #Ciclo5 CU23 - Botón para calificar el servicio
  // =========================================================
  Widget _buildBotonCalificar(String estado) {
    final estadosCalificables = ['atendido', 'finalizado'];
    if (!estadosCalificables.contains(estado) || _yaCalificado) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => CalificacionScreen(
                incidenteId: widget.incidenteId,
                nombreTaller: _datos?['tecnico_asignado']?['nombre'],
              ),
            ),
          );
          if (result == true && mounted) {
            setState(() => _yaCalificado = true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⭐ ¡Gracias por calificar el servicio!'),
                backgroundColor: Color(0xFF059669),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF59E0B),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
        icon: const Text('⭐', style: TextStyle(fontSize: 20)),
        label: Text(
          'Califica este servicio',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // #Ciclo5 CU25 - Banner de consejos cuando está esperando
            _buildBannerConsejos(estado),

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
                  : estado == 'atendido' || estado == 'finalizado'
                      ? '✅ Servicio Completado'
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

            const SizedBox(height: 20),

            if (tecnico != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📍 Ubicación de la emergencia',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lat: ${_datos?['latitud_tecnico'] ?? 'Esperando GPS...'}',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    Text(
                      'Lng: ${_datos?['longitud_tecnico'] ?? ''}',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    if (_datos?['eta_minutos'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'ETA: ${_datos!['eta_minutos']} minutos',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // #Ciclo5 CU23 - Botón de calificación post-servicio
            _buildBotonCalificar(estado),

            const SizedBox(height: 20),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFE24B4A),
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('Cancelar Servicio'),
        onPressed: _mostrarDialogoCancelacion,
      ),
    );
  }
}
