// lib/features/cliente/tabs/alertas_tab.dart
// Tab 3 — CU15: Ver y marcar notificaciones
// GET   /notificaciones/mis-notificaciones
// PATCH /notificaciones/{id}/leer

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/notificacion_service.dart';
import '../../../models/notificacion_model.dart';

class AlertasTab extends StatelessWidget {
  final List<NotificacionModel> notificaciones;
  final Future<void> Function() onRefresh;

  const AlertasTab({
    super.key,
    required this.notificaciones,
    required this.onRefresh,
  });

  static const _rojo = Color(0xFFE24B4A);
  static const _navy = Color(0xFF0D1B2A);
  static const _gris = Color(0xFF7A8A9A);

  Future<void> _marcarLeida(BuildContext context, NotificacionModel n) async {
    if (n.leido) return;
    await NotificacionService.marcarLeida(n.idNotificacion);
    await onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _rojo,
      onRefresh: onRefresh,
      child: notificaciones.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 80),
                Icon(
                  Icons.notifications_none,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No tienes alertas',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 15, color: _gris),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notificaciones.length,
              itemBuilder: (ctx, i) {
                final n = notificaciones[i];
                return GestureDetector(
                  onTap: () => _marcarLeida(ctx, n),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: n.leido ? Colors.white : const Color(0xFFFCEBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: n.leido
                            ? const Color(0xFFE0E8F0)
                            : const Color(0xFFF09595),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: n.leido
                                ? const Color(0xFFF1F3F5)
                                : const Color(0xFFFCEBEB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            n.leido
                                ? Icons.notifications_none
                                : Icons.notifications_active,
                            color: n.leido ? _gris : _rojo,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n.titulo ?? 'Notificación',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: n.leido
                                      ? FontWeight.normal
                                      : FontWeight.w500,
                                  color: _navy,
                                ),
                              ),
                              if (n.mensaje != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  n.mensaje!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: _gris,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              if (!n.leido) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Toca para marcar como leída',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: _rojo,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!n.leido)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: _rojo,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
