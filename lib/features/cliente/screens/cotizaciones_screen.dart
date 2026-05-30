import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/cotizacion_service.dart';
import 'monitoreo_screen.dart';

class CotizacionesScreen extends StatefulWidget {
  final int incidenteId;
  const CotizacionesScreen({Key? key, required this.incidenteId})
    : super(key: key);

  @override
  _CotizacionesScreenState createState() => _CotizacionesScreenState();
}

class _CotizacionesScreenState extends State<CotizacionesScreen> {
  List<dynamic> _cotizaciones = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarCotizaciones();
  }

  Future<void> _cargarCotizaciones() async {
    try {
      final data = await CotizacionService.getCotizaciones(widget.incidenteId);
      setState(() {
        _cotizaciones = data.where((c) => c['estado'] == 'pendiente').toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _aceptar(int id) async {
    await CotizacionService.aceptarCotizacion(id);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MonitoreoScreen(incidenteId: widget.incidenteId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cotizaciones Recibidas', style: GoogleFonts.poppins()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _cotizaciones.length,
              itemBuilder: (context, index) {
                final cot = _cotizaciones[index];
                return Card(
                  margin: const EdgeInsets.all(10),
                  child: ListTile(
                    title: Text(
                      'Precio: \$${cot['precio_estimado']} - ${cot['tiempo_estimado_min']} min',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      cot['descripcion'] ?? '',
                      style: GoogleFonts.poppins(),
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => _aceptar(cot['id_cotizacion']),
                      child: Text('Aceptar', style: GoogleFonts.poppins()),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
