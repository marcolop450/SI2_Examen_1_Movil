import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/vehiculo_model.dart';
import '../screens/monitoreo_screen.dart'; // 🔥 Importamos la pantalla de monitoreo

class InicioTab extends StatelessWidget {
  final String nombreUsuario;
  final List<VehiculoModel> vehiculos;
  final int? incidenteActivoId; // Recibe si hay una emergencia en curso
  final VoidCallback onReportarEmergencia;
  final Future<void> Function() onRefresh;

  const InicioTab({
    super.key,
    required this.nombreUsuario,
    required this.vehiculos,
    this.incidenteActivoId,
    required this.onReportarEmergencia,
    required this.onRefresh,
  });

  static const _navy = Color(0xFF0D1B2A);
  static const _rojo = Color(0xFFE24B4A);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _rojo,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ==========================================
          // BANNER INTERACTIVO DE EMERGENCIA ACTIVA
          // ==========================================
          if (incidenteActivoId != null)
            GestureDetector(
              onTap: () {
                // 🔥 AL HACER CLICK, SALTAMOS A LA PANTALLA DE MONITOREO
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        MonitoreoScreen(incidenteId: incidenteActivoId!),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.radar, color: Colors.white, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Servicio en Curso',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Toca aquí para ver el GPS del técnico en vivo.',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),

          // ==========================================
          // BOTÓN GIGANTE DE SOLICITAR AUXILIO
          // ==========================================
          if (incidenteActivoId ==
              null) // Solo se muestra si no hay emergencia activa
            GestureDetector(
              onTap: onReportarEmergencia,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _rojo,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _rojo.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sos,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Solicitar Auxilio',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Asistencia mecánica mediante IA',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 32),

          // ==========================================
          // LISTA DE VEHÍCULOS
          // ==========================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tus Vehículos',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _navy,
                ),
              ),
              Text(
                '${vehiculos.length} registrados',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF7A8A9A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (vehiculos.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0E8F0)),
              ),
              child: Center(
                child: Text(
                  'Aún no has registrado ningún vehículo.',
                  style: GoogleFonts.poppins(color: const Color(0xFF7A8A9A)),
                ),
              ),
            )
          else
            ...vehiculos.map((v) => _buildVehiculoCard(v)).toList(),
        ],
      ),
    );
  }

  Widget _buildVehiculoCard(VehiculoModel v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.directions_car, color: _navy),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${v.marca} ${v.modelo}',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Placa: ${v.placa}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF7A8A9A),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Activo',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
