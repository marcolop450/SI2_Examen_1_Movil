// #Ciclo5 CU19 - Dashboard del cliente con banner de conectividad y auto-sync
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/auth_services/auth_service.dart';
import '../../core/storage/storage_service.dart';
import '../../core/services/vehiculo_service.dart';
import '../../core/services/notificacion_service.dart';
import '../../core/services/incidente_service.dart'; // NATIVO: Para el Radar
import '../../core/services/connectivity_service.dart'; // #Ciclo5 CU19
import '../../core/services/offline_service.dart'; // #Ciclo5 CU19
import '../../models/vehiculo_model.dart';
import '../../models/notificacion_model.dart';
import 'tabs/inicio_tab.dart';
import 'tabs/vehiculos_tab.dart';
import 'tabs/emergencia_tab.dart';
import 'tabs/alertas_tab.dart';
import 'screens/cotizaciones_screen.dart';

class ClienteDashboard extends StatefulWidget {
  const ClienteDashboard({super.key});

  @override
  State<ClienteDashboard> createState() => _ClienteDashboardState();
}

class _ClienteDashboardState extends State<ClienteDashboard>
    with SingleTickerProviderStateMixin {
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
  String? _estadoAnteriorRadar;

  // --- #Ciclo5 CU19 - Variables de conectividad ---
  bool _isOnline = true;
  int _pendientesOffline = 0;
  StreamSubscription<bool>? _connectivitySub;
  bool _mostrarBannerSyncExito = false;

  // --- Notificaciones locales ---
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
    _iniciarRadarGlobal();
    _iniciarMonitoreoConectividad(); // #Ciclo5 CU19
    _cargarPendientesOffline(); // #Ciclo5 CU19
  }

  @override
  void dispose() {
    _radarTimer?.cancel();
    _connectivitySub?.cancel(); // #Ciclo5 CU19
    super.dispose();
  }

  // =========================================================
  // #Ciclo5 CU19 - Monitoreo de conectividad global
  // =========================================================
  void _iniciarMonitoreoConectividad() {
    _isOnline = ConnectivityService.instance.isOnline;

    _connectivitySub =
        ConnectivityService.instance.onConnectivityChanged.listen((online) {
      if (!mounted) return;

      final wasOffline = !_isOnline;
      setState(() => _isOnline = online);

      if (online && wasOffline) {
        // ¡Conexión restaurada! Auto-sync
        _sincronizarEmergenciasOffline();
      }
    });
  }

  // #Ciclo5 CU19 - Cargar cantidad de emergencias pendientes
  Future<void> _cargarPendientesOffline() async {
    final count = await OfflineService.contarPendientes();
    if (mounted) setState(() => _pendientesOffline = count);
  }

  // #Ciclo5 CU19 - Sincronizar emergencias offline con reintentos
  Future<void> _sincronizarEmergenciasOffline() async {
    final pendientes = await OfflineService.contarPendientes();
    if (pendientes == 0) return;

    final result = await OfflineService.sincronizarTodas();

    if (result.exitosas > 0) {
      // Mostrar banner de éxito
      if (mounted) {
        setState(() => _mostrarBannerSyncExito = true);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _mostrarBannerSyncExito = false);
        });
      }

      // Notificación local nativa
      await _notificationsPlugin.show(
        id: 99,
        title: '✅ Sincronización completada',
        body:
            '${result.exitosas} emergencia(s) enviada(s) al servidor exitosamente.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'sync_channel',
            'Sincronización Offline',
            channelDescription: 'Notificaciones de sincronización offline',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }

    await _cargarPendientesOffline();
    await _cargarDatosIniciales(); // Recargar datos
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
        try {
          final data = await IncidenteService.monitorearEmergencia(idActivo);
          _estadoAnteriorRadar = data['estado_actual'];
        } catch (_) {}
      } else {
        await prefs.remove('incidente_activo_id');
        _incidenteActivoId = null;
        _estadoAnteriorRadar = null;
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

    // #Ciclo5 CU19 - Actualizar pendientes offline
    await _cargarPendientesOffline();

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
          if (estado == 'buscando_taller') {
            // #Ciclo5 CU18 - Nuevo flujo: hay cotizaciones llegando
            final cotizaciones = data['cotizaciones_pendientes'] ?? 0;
            if (cotizaciones > 0) {
              _mostrarBannerCotizaciones();
            } else {
              _mostrarNotificacionPush(
                '📡 Buscando talleres...',
                'Tu emergencia fue recibida. Pronto recibirás cotizaciones.',
              );
            }
          } else if (estado == 'taller_asignado') {
            _mostrarNotificacionPush(
              '✅ Taller Confirmado',
              'Tu taller fue asignado. Podes seguir el recorrido en Monitoreo.',
            );
          } else if (estado == 'en_proceso') {
            _mostrarNotificacionPush(
              '¡Técnico Asignado!',
              'El mecánico va en camino a tu ubicación. Entra al monitoreo.',
            );
          } else if (estado == 'en_atencion') {
            _mostrarNotificacionPush(
              '🔧 En Atención',
              'El técnico está trabajando en tu vehículo.',
            );
          } else if (estado == 'atendido') {
            _mostrarNotificacionPush(
              '¡Servicio Completado!',
              'Toca el botón verde de Servicio en Curso para realizar el pago.',
            );
          } else if (estado == 'cancelado') {
            _mostrarNotificacionPush(
              'Servicio Cancelado',
              'Tu emergencia fue cerrada.',
            );
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.remove('incidente_activo_id');
            if (mounted) setState(() => _incidenteActivoId = null);
          }
          _estadoAnteriorRadar = estado;
          if (mounted) setState(() {});
        }
      } catch (e) {
        // Ignoramos errores de red
      }
    });
  }

  void _mostrarBannerCotizaciones() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '💰 Tenés cotizaciones disponibles. ¡Revisalas ahora!',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1D4ED8),
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
        action: SnackBarAction(
          label: 'Ver',
          textColor: Colors.white,
          onPressed: () {
            if (_incidenteActivoId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CotizacionesScreen(incidenteId: _incidenteActivoId!),
                ),
              );
            }
          },
        ),
      ),
    );
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

  // =========================================================
  // #Ciclo5 CU19 - Widget del banner de conectividad
  // =========================================================
  Widget _buildBannerConectividad() {
    if (_isOnline && !_mostrarBannerSyncExito && _pendientesOffline == 0) {
      return const SizedBox.shrink();
    }

    Color bgColor;
    IconData icon;
    String text;

    if (_mostrarBannerSyncExito) {
      bgColor = const Color(0xFF059669); // verde esmeralda
      icon = Icons.cloud_done_rounded;
      text = '✅ Conexión restaurada — Emergencias sincronizadas';
    } else if (!_isOnline) {
      bgColor = const Color(0xFFDC2626); // rojo
      icon = Icons.cloud_off_rounded;
      text = _pendientesOffline > 0
          ? '📡 Sin conexión — $_pendientesOffline emergencia(s) pendiente(s)'
          : '📡 Sin conexión a internet';
    } else if (_pendientesOffline > 0) {
      bgColor = const Color(0xFFF59E0B); // ámbar
      icon = Icons.sync_rounded;
      text = '🔄 $_pendientesOffline emergencia(s) pendiente(s) de sincronizar';
    } else {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_isOnline && _pendientesOffline > 0)
            GestureDetector(
              onTap: _sincronizarEmergenciasOffline,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Sincronizar',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
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
        estadoActivo: _estadoAnteriorRadar,    // 🔥 Pasamos el estado para saber si está cotizando
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
          // #Ciclo5 CU19 - Indicador de conectividad en AppBar
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: _isOnline
                  ? const Color(0xFF34D399)
                  : const Color(0xFFF87171),
              size: 18,
            ),
          ),
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
              _connectivitySub?.cancel(); // #Ciclo5 CU19
              await AuthService.logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/');
            },
            icon: const Icon(Icons.logout, color: Color(0xFF8FA8C0), size: 20),
          ),
        ],
      ),
      body: Column(
        children: [
          // #Ciclo5 CU19 - Banner de conectividad global
          _buildBannerConectividad(),
          Expanded(
            child: _cargando
                ? const Center(
                    child: CircularProgressIndicator(color: _redEmergencia),
                  )
                : tabs[_tabActual],
          ),
        ],
      ),
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
