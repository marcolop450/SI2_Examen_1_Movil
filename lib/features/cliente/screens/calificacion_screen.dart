// #Ciclo5 CU23 - Pantalla de calificación post-servicio
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/calificacion_service.dart';

class CalificacionScreen extends StatefulWidget {
  final int incidenteId;
  final String? nombreTaller;

  const CalificacionScreen({
    super.key,
    required this.incidenteId,
    this.nombreTaller,
  });

  @override
  State<CalificacionScreen> createState() => _CalificacionScreenState();
}

class _CalificacionScreenState extends State<CalificacionScreen>
    with TickerProviderStateMixin {
  // ── Colores ──────────────────────────────────
  static const _navy = Color(0xFF0D1B2A);
  static const _rojo = Color(0xFFE24B4A);
  static const _verde = Color(0xFF2E7D32);
  static const _bg = Color(0xFFF8F9FA);

  // ── Estado ───────────────────────────────────
  int _puntuacion = 0;
  final TextEditingController _comentarioCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;

  // ── Animaciones de estrellas ──────────────────
  late List<AnimationController> _starControllers;
  late List<Animation<double>> _starScales;

  // ── Animaciones de confetti/éxito ─────────────
  late AnimationController _successController;
  late Animation<double> _checkScale;
  late List<Animation<double>> _confettiOpacities;

  final List<String> _ratingLabels = [
    '',
    'Malo',
    'Regular',
    'Bueno',
    'Muy bueno',
    'Excelente',
  ];

  @override
  void initState() {
    super.initState();

    // Controladores de escala para cada estrella
    _starControllers = List.generate(5, (_) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 250),
      );
    });

    _starScales = _starControllers.map((ctrl) {
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
      ]).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutBack));
    }).toList();

    // Controlador de éxito (confetti + check)
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successController,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    // 8 partículas de confetti con delays escalonados
    _confettiOpacities = List.generate(8, (i) {
      final start = 0.2 + (i * 0.08);
      final end = (start + 0.3).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _successController,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    for (final c in _starControllers) {
      c.dispose();
    }
    _successController.dispose();
    _comentarioCtrl.dispose();
    super.dispose();
  }

  // ── Seleccionar estrella ──────────────────────
  void _onStarTap(int index) {
    setState(() => _puntuacion = index + 1);
    _starControllers[index].forward(from: 0);
  }

  // ── Enviar calificación ───────────────────────
  Future<void> _enviarCalificacion() async {
    if (_puntuacion == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selecciona al menos una estrella',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: _rojo,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await CalificacionService.enviarCalificacion(
        incidenteId: widget.incidenteId,
        puntuacion: _puntuacion,
        comentario: _comentarioCtrl.text.trim().isEmpty
            ? null
            : _comentarioCtrl.text.trim(),
      );

      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
      _successController.forward();

      // Esperar 2 segundos y salir
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;

      final errorMsg = e.toString().replaceFirst('Exception: ', '');

      // Errores específicos del backend
      if (errorMsg.toLowerCase().contains('ya calific')) {
        _showErrorSnackBar('Ya has calificado este servicio');
      } else if (errorMsg.toLowerCase().contains('finalizado') ||
          errorMsg.toLowerCase().contains('finalizar')) {
        _showErrorSnackBar('Solo puedes calificar incidentes finalizados');
      } else {
        _showErrorSnackBar(errorMsg);
      }
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: _rojo,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          '⭐ Califica el Servicio',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: _navy,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _isSuccess ? _buildSuccessView() : _buildFormView(),
      ),
    );
  }

  // ── Vista de éxito ────────────────────────────
  Widget _buildSuccessView() {
    // Posiciones de confetti alrededor del check
    final confettiPositions = <Offset>[
      const Offset(-60, -70),
      const Offset(60, -70),
      const Offset(-80, -10),
      const Offset(80, -10),
      const Offset(-50, 50),
      const Offset(50, 50),
      const Offset(-30, -90),
      const Offset(30, -90),
    ];

    final confettiColors = [
      Colors.amber,
      _rojo,
      _verde,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];

    return Center(
      key: const ValueKey('success'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Confetti partículas
                ...List.generate(8, (i) {
                  return AnimatedBuilder(
                    animation: _confettiOpacities[i],
                    builder: (context, child) {
                      return Positioned(
                        left: 100 + confettiPositions[i].dx - 8,
                        top: 100 + confettiPositions[i].dy - 8,
                        child: AnimatedOpacity(
                          opacity: _confettiOpacities[i].value,
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            Icons.circle,
                            size: 16,
                            color: confettiColors[i],
                          ),
                        ),
                      );
                    },
                  );
                }),
                // Checkmark central
                ScaleTransition(
                  scale: _checkScale,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: _verde,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _verde.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '¡Gracias por tu opinión!',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _navy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tu calificación nos ayuda a mejorar',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Vista del formulario ──────────────────────
  Widget _buildFormView() {
    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── Header card ─────────────────────────
          _buildHeaderCard(),
          const SizedBox(height: 24),

          // ── Card de calificación ────────────────
          Card(
            elevation: 4,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Column(
                children: [
                  Text(
                    '¿Cómo fue tu experiencia?',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Estrellas ───────────────────
                  _buildStarRating(),
                  const SizedBox(height: 10),

                  // ── Label de puntuación ─────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _puntuacion > 0
                          ? _ratingLabels[_puntuacion]
                          : 'Toca una estrella',
                      key: ValueKey(_puntuacion),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _puntuacion > 0
                            ? Colors.amber.shade800
                            : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '1=Malo, 2=Regular, 3=Bueno, 4=Muy bueno, 5=Excelente',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // ── Comentario ──────────────────
                  TextField(
                    controller: _comentarioCtrl,
                    maxLines: 3,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Comparte tu experiencia...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey.shade400,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _navy, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Botón enviar ────────────────────────
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _rojo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              onPressed: _isLoading ? null : _enviarCalificacion,
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      'Enviar Calificación',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Header Card ───────────────────────────────
  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navy, Color(0xFF1B2F45)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.build_circle_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auxilio #${widget.incidenteId}',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (widget.nombreTaller != null)
                  Text(
                    widget.nombreTaller!,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Star Rating Widget ────────────────────────
  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final isFilled = index < _puntuacion;
        return GestureDetector(
          onTap: () => _onStarTap(index),
          child: AnimatedBuilder(
            animation: _starScales[index],
            builder: (context, child) {
              return Transform.scale(
                scale: _starScales[index].value,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    isFilled ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 44,
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
