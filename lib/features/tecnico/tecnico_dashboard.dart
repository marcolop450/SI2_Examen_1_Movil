import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth_services/auth_service.dart';
import '../../core/services/incidente_service.dart';

class TecnicoDashboard extends StatefulWidget {
  const TecnicoDashboard({super.key});

  @override
  State<TecnicoDashboard> createState() => _TecnicoDashboardState();
}

class _TecnicoDashboardState extends State<TecnicoDashboard> {
  static const _navy = Color(0xFF0D1B2A);
  static const _rojo = Color(0xFFE24B4A);
  static const _verde = Color(0xFF2E7D32);

  List<dynamic> _ordenes = [];
  bool _cargando = true;
  Timer? _trackerTimer;

  @override
  void initState() {
    super.initState();
    _cargarOrdenes();
  }

  @override
  void dispose() {
    _trackerTimer?.cancel();
    super.dispose();
  }

  // =========================================================
  // CU12: CARGAR ÓRDENES Y ENCENDER RADAR DE TRANSMISIÓN
  // =========================================================
  Future<void> _cargarOrdenes() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      final ordenes = await IncidenteService.obtenerAsignados();
      setState(() {
        _ordenes = ordenes;
        _cargando = false;
      });

      if (_ordenes.isNotEmpty) {
        _iniciarTransmisionGPS(_ordenes.first['id_incidente']);
      } else {
        _trackerTimer?.cancel();
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
      _mostrarMensaje('Error al cargar órdenes: $e', isError: true);
    }
  }

  void _iniciarTransmisionGPS(int idIncidente) {
    _trackerTimer?.cancel();
    _trackerTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        await IncidenteService.reportarUbicacionTecnico(
          idIncidente,
          pos.latitude,
          pos.longitude,
        );
        print("GPS enviado al cliente: ${pos.latitude}, ${pos.longitude}");
      } catch (e) {
        print("Error enviando GPS: $e");
      }
    });
  }

  // =========================================================
  // NATIVO: ABRIR GOOGLE MAPS EN MODO CONDUCCIÓN
  // =========================================================
  Future<void> _abrirMapaNavegacion(double lat, double lng) async {
    final Uri url = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      final Uri webUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
      );
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  // =========================================================
  // CU12: FINALIZAR EL SERVICIO Y ESTABLECER PRECIO
  // =========================================================
  Future<void> _finalizarServicio(int idIncidente) async {
    final TextEditingController costoController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // 🔥 Convertimos el diálogo simple en un formulario de liquidación
    final double? costoFinal = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Liquidación del Servicio',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _navy),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ingresa el costo total del trabajo realizado. Este monto será enviado al cliente para su pago mediante PayPal.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: costoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _navy,
                ),
                decoration: InputDecoration(
                  labelText: 'Costo Total (Bs.)',
                  prefixIcon: const Icon(
                    Icons.attach_money,
                    color: _verde,
                    size: 30,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: _verde, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Requerido';
                  final numero = double.tryParse(value);
                  if (numero == null) return 'Monto inválido';
                  if (numero <= 0) return 'Debe ser mayor a 0';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _verde,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
            label: const Text(
              'COBRAR',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                // Cerramos el popup y enviamos el número de vuelta
                Navigator.pop(
                  context,
                  double.parse(costoController.text.trim()),
                );
              }
            },
          ),
        ],
      ),
    );

    // Si el técnico presionó "CANCELAR"
    if (costoFinal == null) return;

    try {
      setState(() => _cargando = true);
      // 🔥 Le enviamos el costo final a tu servicio
      await IncidenteService.actualizarEstado(
        idIncidente,
        'atendido',
        costoFinal: costoFinal,
      );

      _trackerTimer?.cancel(); // Apagamos el radar
      await _cargarOrdenes(); // Recargamos la pantalla
      _mostrarMensaje(
        'Servicio finalizado. Cobro enviado: Bs. ${costoFinal.toStringAsFixed(2)}',
      );
    } catch (e) {
      setState(() => _cargando = false);
      _mostrarMensaje('Error al finalizar: $e', isError: true);
    }
  }

  void _mostrarMensaje(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? _rojo : _verde),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: _navy,
        title: Text(
          'CENTRAL TÉCNICO',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarOrdenes,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              _trackerTimer?.cancel();
              await AuthService.logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : _ordenes.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _cargarOrdenes,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _ordenes.length,
                itemBuilder: (context, index) =>
                    _buildTarjetaTrabajo(_ordenes[index]),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radar, size: 100, color: Colors.green.shade300),
          const SizedBox(height: 20),
          Text(
            'En línea y disponible',
            style: GoogleFonts.poppins(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Esperando asignación de emergencias...',
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaTrabajo(dynamic orden) {
    String analisisIA = "Diagnóstico pendiente";
    String vozCliente = "Sin audio adjunto";

    if (orden['evidencias'] != null && orden['evidencias'].isNotEmpty) {
      analisisIA =
          orden['evidencias'][0]['clasificacion_ia_texto'] ?? analisisIA;
      final audioEv = (orden['evidencias'] as List).firstWhere(
        (e) => e['tipo_enum'] == 'audio',
        orElse: () => null,
      );
      if (audioEv != null)
        vozCliente = audioEv['transcripcion_audio_texto'] ?? vozCliente;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      shadowColor: Colors.black26,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EMERGENCIA #${orden['id_incidente']}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Row(
                  children: [
                    Icon(
                      Icons.satellite_alt,
                      color: Colors.greenAccent,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'GPS Activo',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REPORTE IA:',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _rojo,
                  ),
                ),
                Text(
                  analisisIA,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 12),
                if (vozCliente != "Sin audio adjunto")
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.mic, color: Colors.blueGrey, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '"$vozCliente"',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 40),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _abrirMapaNavegacion(
                          double.parse(orden['latitud_emergencia'].toString()),
                          double.parse(orden['longitud_emergencia'].toString()),
                        ),
                        icon: const Icon(Icons.navigation, color: Colors.blue),
                        label: Text(
                          'NAVEGAR',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Colors.blue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _finalizarServicio(orden['id_incidente']),
                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                        ),
                        label: Text(
                          'FINALIZAR',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _verde,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
