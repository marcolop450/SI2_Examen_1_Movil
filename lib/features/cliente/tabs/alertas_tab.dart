// lib/features/cliente/tabs/alertas_tab.dart
// Tab 3 — CU15: Ver y marcar notificaciones
// GET   /notificaciones/mis-notificaciones
// PATCH /notificaciones/{id}/leer

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/notificacion_service.dart';
import '../../../models/notificacion_model.dart';

class AlertasTab extends StatefulWidget {
  final List<NotificacionModel> notificaciones;
  final Future<void> Function() onRefresh;

  const AlertasTab({
    super.key,
    required this.notificaciones,
    required this.onRefresh,
  });

  @override
  State<AlertasTab> createState() => _AlertasTabState();
}

class _AlertasTabState extends State<AlertasTab> {
  static const _rojo = Color(0xFFE24B4A);
  static const _navy = Color(0xFF0D1B2A);
  static const _gris = Color(0xFF7A8A9A);

  // Copia local para poder marcar sin esperar al padre
  late List<NotificacionModel> _lista;
  bool _marcando = false;

  @override
  void initState() {
    super.initState();
    _lista = List.from(widget.notificaciones);
  }

  @override
  void didUpdateWidget(covariant AlertasTab old) {
    super.didUpdateWidget(old);
    if (old.notificaciones != widget.notificaciones) {
      setState(() => _lista = List.from(widget.notificaciones));
    }
  }

  Future<void> _marcarLeida(NotificacionModel n) async {
    if (n.leido || _marcando) return;
    setState(() => _marcando = true);
    try {
      await NotificacionService.marcarLeida(n.idNotificacion);
      // Actualizar localmente sin esperar al padre
      setState(() {
        final idx = _lista.indexWhere((x) => x.idNotificacion == n.idNotificacion);
        if (idx >= 0) {
          _lista[idx] = NotificacionModel(
            idNotificacion: n.idNotificacion,
            usuarioId: n.usuarioId,
            titulo: n.titulo,
            mensaje: n.mensaje,
            leido: true,
            fechaCreacion: n.fechaCreacion,
          );
        }
      });
      await widget.onRefresh();
    } catch (_) {
      // Si falla, igual se actualizó localmente
    } finally {
      if (mounted) setState(() => _marcando = false);
    }
  }

  Future<void> _marcarTodasLeidas() async {
    // Usar nuevo endpoint masivo del backend
    await NotificacionService.marcarTodasLeidas();
    await widget.onRefresh();
  }

  Future<void> _eliminar(NotificacionModel n) async {
    await NotificacionService.eliminar(n.idNotificacion);
    setState(() => _lista.removeWhere((x) => x.idNotificacion == n.idNotificacion));
    await widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final noLeidas = _lista.where((n) => !n.leido).length;

    return RefreshIndicator(
      color: _rojo,
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Header con conteo y botón "marcar todas"
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    noLeidas > 0
                        ? '$noLeidas sin leer'
                        : _lista.isEmpty
                            ? 'Sin notificaciones'
                            : 'Todo leído ✅',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: noLeidas > 0 ? _rojo : _gris,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (noLeidas > 0)
                    TextButton.icon(
                      onPressed: _marcarTodasLeidas,
                      icon: const Icon(Icons.done_all, size: 16, color: _navy),
                      label: Text('Marcar todas',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: _navy, fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Estado vacío
          if (_lista.isEmpty)
            SliverFillRemaining(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No tienes notificaciones aún',
                      style: GoogleFonts.poppins(fontSize: 15, color: _gris)),
                  const SizedBox(height: 8),
                  Text('Desliza hacia abajo para actualizar',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400)),
                ],
              ),
            ),

          // Lista
          if (_lista.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final n = _lista[i];
                    return _buildCard(n);
                  },
                  childCount: _lista.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(NotificacionModel n) {
    return Dismissible(
      key: ValueKey(n.idNotificacion),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 26),
            SizedBox(height: 2),
            Text('Eliminar', style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
      onDismissed: (_) => _eliminar(n),
      child: GestureDetector(
        onTap: () => _marcarLeida(n),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.leido ? Colors.white : const Color(0xFFFCEBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: n.leido ? const Color(0xFFE0E8F0) : const Color(0xFFF09595),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: n.leido ? 0.03 : 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icono
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: n.leido ? const Color(0xFFF1F3F5) : const Color(0xFFFCEBEB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                n.leido ? Icons.notifications_none : Icons.notifications_active,
                color: n.leido ? _gris : _rojo,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Contenido
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.titulo ?? 'Notificación',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: n.leido ? FontWeight.normal : FontWeight.w600,
                      color: _navy,
                    ),
                  ),
                  if (n.mensaje != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      n.mensaje!,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: _gris, height: 1.4),
                    ),
                  ],
                  if (n.fechaCreacion != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatFecha(n.fechaCreacion!),
                      style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade400),
                    ),
                  ],
                  if (!n.leido) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Toca para marcar como leída',
                      style: GoogleFonts.poppins(fontSize: 10, color: _rojo),
                    ),
                  ],
                ],
              ),
            ),
            // Punto rojo si no leída
            if (!n.leido)
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(color: _rojo, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    ),   // GestureDetector
    );   // Dismissible
  }

  String _formatFecha(String fecha) {
    try {
      final dt = DateTime.parse(fecha).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Ahora mismo';
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return fecha;
    }
  }
}
