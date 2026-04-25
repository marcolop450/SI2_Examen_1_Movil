import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/auth_services/auth_service.dart';
import '../../core/storage/storage_service.dart';
import '../../core/services/vehiculo_service.dart';
import '../../core/services/notificacion_service.dart';
import '../../core/services/incidente_service.dart'; // NATIVO: Para el Radar
import '../../models/vehiculo_model.dart';
import '../../models/notificacion_model.dart';
import 'tabs/inicio_tab.dart';
import 'tabs/vehiculos_tab.dart';
import 'tabs/emergencia_tab.dart';
import 'tabs/alertas_tab.dart';

class ClienteDashboard extends StatefulWidget {
  const ClienteDashboard({super.key});

  @override
  State<ClienteDashboard> createState() => _ClienteDashboardState();
}

class _ClienteDashboardState extends State<ClienteDashboard> {
  static const _redEmergencia = Color(0xFFE24B4A);
  static const _darkNavy = Color(0xFF0D1B2A);
  static const _verde = Color(0xFF2E7D32);

  int _tabActual = 0;
  String _nombreUsuario = 'Cliente';
  int _noLeidas = 0;

  List<VehiculoModel> _vehiculos = [];
  List<NotificacionModel> _notificaciones = [];
  bool _cargando = true;

  // --- VARIABLES DEL RADAR GLOBAL ---
  Timer? _radarTimer;
  int? _incidenteActivoId;
  String _estadoAnteriorRadar = 'pendiente';

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
    _iniciarRadarGlobal(); // Encendemos el radar de notificaciones al abrir la app
  }

  @override
  void dispose() {
    _radarTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    setState(() => _cargando = true);

    // 1. OBTENER NOMBRE
    String nombreReal = await StorageService.getNombre() ?? '';
    if (nombreReal.isEmpty || nombreReal == 'null') {
      nombreReal = 'Cliente';
    } else {
      nombreReal = nombreReal[0].toUpperCase() + nombreReal.substring(1);
    }

    // 🔥 2. PREGUNTAR AL BACKEND SI HAY EMERGENCIA ACTIVA
    try {
      final idActivo = await IncidenteService.obtenerEmergenciaActiva();
      SharedPreferences prefs = await SharedPreferences.getInstance();

      if (idActivo != null) {
        await prefs.setInt('incidente_activo_id', idActivo);
        _incidenteActivoId = idActivo;
      } else {
        await prefs.remove('incidente_activo_id');
        _incidenteActivoId = null;
      }
    } catch (e) {
      print("Error obteniendo emergencia activa: $e");
    }

    // 3. CARGAR VEHÍCULOS Y ALERTAS
    try {
      _vehiculos = await VehiculoService.listarMisVehiculos();
    } catch (e) {
      print("Error cargando vehículos: $e");
    }

    try {
      _notificaciones = await NotificacionService.misNotificaciones();
      _noLeidas = await NotificacionService.contarNoLeidas();
    } catch (e) {
      print("Error cargando alertas: $e");
    }

    if (mounted) {
      setState(() {
        _nombreUsuario = nombreReal;
        _cargando = false;
      });
    }
  }

  // =========================================================
  // EL RADAR GLOBAL DE PUSH NOTIFICATIONS
  // =========================================================
  Future<void> _iniciarRadarGlobal() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    _radarTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      _incidenteActivoId = prefs.getInt('incidente_activo_id');
      if (_incidenteActivoId == null) return;

      try {
        final data = await IncidenteService.monitorearEmergencia(
          _incidenteActivoId!,
        );
        final estado = data['estado_actual'];

        if (estado != _estadoAnteriorRadar) {
          if (estado == 'en_proceso') {
            _mostrarNotificacionPush(
              '¡Técnico Asignado!',
              'El mecánico va en camino a tu ubicación. Entra al monitoreo.',
            );
          } else if (estado == 'atendido') {
            _mostrarNotificacionPush(
              '¡Servicio Completado!',
              'Toca el botón verde de Servicio en Curso para realizar el pago.',
            );
          }
          _estadoAnteriorRadar = estado;
          if (mounted) setState(() {});
        }
      } catch (e) {
        // Ignoramos errores de red
      }
    });
  }

  void _mostrarNotificacionPush(String titulo, String cuerpo) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(cuerpo),
          ],
        ),
        backgroundColor: _verde,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      InicioTab(
        nombreUsuario: _nombreUsuario,
        vehiculos: _vehiculos,
        incidenteActivoId: _incidenteActivoId, // 🔥 Pasamos el ID al inicio
        onReportarEmergencia: () => setState(() => _tabActual = 2),
        onRefresh: _cargarDatosIniciales, // 🔥 Refresco manual
      ),
      VehiculosTab(vehiculos: _vehiculos, onRefresh: _cargarDatosIniciales),
      EmergenciaTab(vehiculos: _vehiculos),
      AlertasTab(
        notificaciones: _notificaciones,
        onRefresh: _cargarDatosIniciales,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F5),
      appBar: AppBar(
        backgroundColor: _darkNavy,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola de nuevo 👋',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF5A8AAA),
              ),
            ),
            Text(
              _nombreUsuario,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _tabActual = 3),
            icon: Badge(
              label: _noLeidas > 0 ? Text('$_noLeidas') : null,
              isLabelVisible: _noLeidas > 0,
              child: const Icon(
                Icons.notifications_outlined,
                color: Color(0xFF8FA8C0),
              ),
            ),
          ),
          IconButton(
            onPressed: () async {
              _radarTimer?.cancel();
              await AuthService.logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/');
            },
            icon: const Icon(Icons.logout, color: Color(0xFF8FA8C0), size: 20),
          ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: _redEmergencia),
            )
          : tabs[_tabActual],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabActual,
        onTap: (i) => setState(() => _tabActual = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: _redEmergencia,
        unselectedItemColor: const Color(0xFFAAB4BE),
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_outlined),
            activeIcon: Icon(Icons.directions_car),
            label: 'Vehículos',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: _redEmergencia,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 20),
            ),
            label: 'Emergencia',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              label: _noLeidas > 0 ? Text('$_noLeidas') : null,
              isLabelVisible: _noLeidas > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            label: 'Alertas',
          ),
        ],
      ),
    );
  }
}
