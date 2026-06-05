// #Ciclo5 CU25 - Pantalla de consejos de seguridad vial

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/consejo_vial_service.dart';
import '../../../models/consejo_vial_model.dart';

class ConsejosSeguridad extends StatefulWidget {
  final int incidenteId;
  const ConsejosSeguridad({super.key, required this.incidenteId});

  @override
  State<ConsejosSeguridad> createState() => _ConsejosSeguridadState();
}

class _ConsejosSeguridadState extends State<ConsejosSeguridad>
    with TickerProviderStateMixin {
  static const _navy = Color(0xFF0D1B2A);
  static const _rojo = Color(0xFFE24B4A);

  List<ConsejoVialModel> _consejos = [];
  bool _isLoading = true;
  bool _isGeneratingIA = false;
  int _consejoRotacionIndex = 0;
  Timer? _rotacionTimer;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Colores por categoría
  static const Map<String, List<Color>> _categoryColors = {
    'choque': [Color(0xFFFEE2E2), Color(0xFFF87171)],
    'llanta': [Color(0xFFFEF3C7), Color(0xFFFBBF24)],
    'motor': [Color(0xFFD1FAE5), Color(0xFF34D399)],
    'bateria': [Color(0xFFDBEAFE), Color(0xFF60A5FA)],
    'general': [Color(0xFFEDE9FE), Color(0xFF8B5CF6)],
    'clima': [Color(0xFFCFFAFE), Color(0xFF22D3EE)],
  };

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
    _cargarConsejos();
  }

  @override
  void dispose() {
    _rotacionTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _iniciarRotacion() {
    _rotacionTimer?.cancel();
    if (_consejos.isEmpty) return;
    _rotacionTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {
        _consejoRotacionIndex =
            (_consejoRotacionIndex + 1) % _consejos.length;
      });
    });
  }

  Future<void> _cargarConsejos() async {
    setState(() => _isLoading = true);
    try {
      final consejos = await ConsejoVialService.obtenerConsejosParaIncidente(
        widget.incidenteId,
      );
      if (!mounted) return;
      setState(() {
        _consejos = consejos;
        _isLoading = false;
        _consejoRotacionIndex = 0;
      });
      _iniciarRotacion();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _consejos = _consejosFallback();
        _isLoading = false;
        _consejoRotacionIndex = 0;
      });
      _iniciarRotacion();
    }
  }

  List<ConsejoVialModel> _consejosFallback() {
    return [
      ConsejoVialModel(
        categoria: 'general',
        titulo: 'Mantén la calma',
        contenido:
            'Respira profundo y evalúa la situación sin precipitarte.',
        icono: '🛡️',
        activo: true,
      ),
      ConsejoVialModel(
        categoria: 'general',
        titulo: 'Enciende luces de emergencia',
        contenido:
            'Haz visible tu posición para otros conductores.',
        icono: '⚠️',
        activo: true,
      ),
      ConsejoVialModel(
        categoria: 'general',
        titulo: 'No abandones el vehículo',
        contenido:
            'Permanece dentro si estás en una vía rápida.',
        icono: '🚗',
        activo: true,
      ),
    ];
  }

  Future<void> _generarConsejosIA() async {
    setState(() => _isGeneratingIA = true);
    try {
      final generados = await ConsejoVialService.generarConsejosIA(
        widget.incidenteId,
      );
      if (!mounted) return;
      final nuevos = generados
          .map((j) => ConsejoVialModel.fromJson(j))
          .toList();
      setState(() {
        _consejos.addAll(nuevos);
        _isGeneratingIA = false;
      });
      _iniciarRotacion();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✨ Nuevos consejos generados por IA',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGeneratingIA = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al generar consejos: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: _rojo,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  List<Color> _getColors(String categoria) {
    return _categoryColors[categoria.toLowerCase()] ??
        _categoryColors['general']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🛡️ Consejos de Seguridad',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            Text(
              'Mientras esperas auxilio',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading ? _buildLoading() : _buildBody(),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _navy,
              onPressed: _isGeneratingIA ? null : _generarConsejosIA,
              icon: _isGeneratingIA
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      '🤖',
                      style: GoogleFonts.poppins(fontSize: 18),
                    ),
              label: Text(
                _isGeneratingIA ? 'Generando...' : 'Generar más con IA',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: _navy),
          const SizedBox(height: 20),
          Text(
            'Cargando consejos de seguridad...',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      color: _navy,
      onRefresh: _cargarConsejos,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // Consejo del momento
            if (_consejos.isNotEmpty) _buildConsejoDelMomento(),
            const SizedBox(height: 20),

            // Título de la sección
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Todos los consejos',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
            ),

            // Lista de consejos como tarjetas
            ..._consejos.asMap().entries.map((entry) {
              final index = entry.key;
              final consejo = entry.value;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 400 + (index * 80)),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: _buildConsejoCard(consejo),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildConsejoDelMomento() {
    final consejo = _consejos[_consejoRotacionIndex % _consejos.length];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF1B2838)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('💡', style: GoogleFonts.poppins(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                'Consejo del momento',
                style: GoogleFonts.poppins(
                  color: Colors.amber[300],
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey<int>(_consejoRotacionIndex),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${consejo.icono} ${consejo.titulo}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  consejo.contenido,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsejoCard(ConsejoVialModel consejo) {
    final colors = _getColors(consejo.categoria);
    final bgColor = colors[0];
    final borderColor = colors[1];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shadowColor: borderColor.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor, width: 3),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emoji icon
              Text(
                consejo.icono,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 14),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      consejo.titulo,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _navy,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      consejo.contenido,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
