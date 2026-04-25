import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart'; // NATIVO: GPS
import 'package:image_picker/image_picker.dart'; // NATIVO: CÁMARA
import 'package:record/record.dart'; // NATIVO: MICRÓFONO
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/incidente_service.dart';
import '../../../models/vehiculo_model.dart';

// 🔥 IMPORTAMOS LA NUEVA PANTALLA DE MONITOREO
import '../screens/monitoreo_screen.dart';

class EmergenciaTab extends StatefulWidget {
  final List<VehiculoModel> vehiculos;

  const EmergenciaTab({super.key, required this.vehiculos});

  @override
  State<EmergenciaTab> createState() => _EmergenciaTabState();
}

class _EmergenciaTabState extends State<EmergenciaTab> {
  static const _rojo = Color(0xFFE24B4A);
  static const _navy = Color(0xFF0D1B2A);

  VehiculoModel? _vehiculoSeleccionado;
  final _descCtrl = TextEditingController();

  bool _enviando = false;

  // --- CU7: GPS ---
  double? _latitudReal;
  double? _longitudReal;
  bool _obteniendoUbicacion = true;

  // --- CU8: CÁMARA ---
  File? _fotoReal;
  final ImagePicker _picker = ImagePicker();

  // --- CU8: AUDIO ---
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _grabandoAudio = false;
  File? _audioReal;

  @override
  void initState() {
    super.initState();
    _obtenerGPS();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _obtenerGPS() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _obteniendoUbicacion = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _obteniendoUbicacion = false);
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _obteniendoUbicacion = false);
      return;
    }

    Position posicion = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    if (mounted) {
      setState(() {
        _latitudReal = posicion.latitude;
        _longitudReal = posicion.longitude;
        _obteniendoUbicacion = false;
      });
    }
  }

  Future<void> _tomarFoto() async {
    final XFile? fotoSeleccionada = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 40,
    );
    if (fotoSeleccionada != null) {
      setState(() => _fotoReal = File(fotoSeleccionada.path));
    }
  }

  Future<void> _toggleGrabacion() async {
    if (_grabandoAudio) {
      final path = await _audioRecorder.stop();
      if (path != null) {
        setState(() {
          _audioReal = File(path);
          _grabandoAudio = false;
        });
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/audio_emergencia.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _grabandoAudio = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de micrófono denegado')),
        );
      }
    }
  }

  Future<String?> _procesarAudioLocal(File audio) async {
    try {
      List<int> audioBytes = await audio.readAsBytes();
      String base64Audio = base64Encode(audioBytes);
      return "data:audio/m4a;base64,$base64Audio";
    } catch (e) {
      return null;
    }
  }

  Future<String?> _procesarImagenLocal(File imagen) async {
    try {
      List<int> imageBytes = await imagen.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      return "data:image/jpeg;base64,$base64Image";
    } catch (e) {
      return null;
    }
  }

  Future<void> _reportarEmergencia() async {
    if (_vehiculoSeleccionado == null ||
        _latitudReal == null ||
        _longitudReal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Faltan datos GPS o Vehículo.'),
          backgroundColor: _rojo,
        ),
      );
      return;
    }

    String descripcionFinal = _descCtrl.text.trim();
    if (_fotoReal == null && descripcionFinal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes tomar una foto o escribir una descripción.'),
          backgroundColor: _rojo,
        ),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      List<Map<String, String>> evidenciasPayload = [];

      if (_fotoReal != null) {
        String? dataUriImagen = await _procesarImagenLocal(_fotoReal!);
        if (dataUriImagen != null)
          evidenciasPayload.add({
            "tipo_enum": "imagen",
            "url_recurso": dataUriImagen,
          });
      }

      if (_audioReal != null) {
        String? dataUriAudio = await _procesarAudioLocal(_audioReal!);
        if (dataUriAudio != null)
          evidenciasPayload.add({
            "tipo_enum": "audio",
            "url_recurso": dataUriAudio,
          });
      }

      // 1. Enviamos todo al Backend
      final nuevoIncidente = await IncidenteService.registrarEmergencia(
        vehiculoId: _vehiculoSeleccionado!.idVehiculo,
        latitud: _latitudReal!,
        longitud: _longitudReal!,
        descripcion: descripcionFinal,
        evidencias: evidenciasPayload,
      );

      final incidenteId = nuevoIncidente.idIncidente ?? 0;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('incidente_activo_id', incidenteId);

      if (mounted) {
        setState(() {
          _enviando = false;
          _descCtrl.clear();
          _fotoReal = null;
          _audioReal = null;
        });

        // 🔥 2. EL SALTO MÁGICO: Vamos directo a la pantalla de Monitoreo
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MonitoreoScreen(incidenteId: incidenteId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _enviando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: _rojo),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildBanner(),
        const SizedBox(height: 24),
        Text(
          'Vehículo afectado',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _navy,
          ),
        ),
        const SizedBox(height: 12),
        _buildListVehiculos(),
        const SizedBox(height: 24),
        Text(
          '¿Qué sucede? (Descripción manual)',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _navy,
          ),
        ),
        const SizedBox(height: 12),
        _buildTextField(),
        const SizedBox(height: 24),
        Text(
          'Evidencia para IA (Foto / Audio)',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _navy,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildBotonCamara()),
            const SizedBox(width: 12),
            Expanded(child: _buildBotonAudio()),
          ],
        ),
        const SizedBox(height: 12),
        _buildIndicadorGPS(),
        const SizedBox(height: 24),
        _buildSubmitButton(),
      ],
    );
  }

  Widget _buildTextField() {
    return TextFormField(
      controller: _descCtrl,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: 'Describe el problema...',
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD0D8E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD0D8E0)),
        ),
      ),
    );
  }

  Widget _buildBotonCamara() {
    return InkWell(
      onTap: _tomarFoto,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD0D8E0)),
          image: _fotoReal != null
              ? DecorationImage(image: FileImage(_fotoReal!), fit: BoxFit.cover)
              : null,
        ),
        child: _fotoReal == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt_outlined, color: _navy, size: 30),
                  const SizedBox(height: 8),
                  Text(
                    'Añadir Foto',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF7A8A9A),
                    ),
                  ),
                ],
              )
            : Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.white),
                  onPressed: () => setState(() => _fotoReal = null),
                ),
              ),
      ),
    );
  }

  Widget _buildBotonAudio() {
    return InkWell(
      onTap: _toggleGrabacion,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: _grabandoAudio ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _audioReal != null ? Colors.green : const Color(0xFFD0D8E0),
            width: _audioReal != null ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _audioReal != null
                  ? Icons.check_circle
                  : (_grabandoAudio ? Icons.stop_circle : Icons.mic_none),
              color: _audioReal != null
                  ? Colors.green
                  : (_grabandoAudio ? Colors.red : _navy),
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              _audioReal != null
                  ? 'Audio Listo'
                  : (_grabandoAudio ? 'Grabando...' : 'Grabar Voz'),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _grabandoAudio ? Colors.red : const Color(0xFF7A8A9A),
              ),
            ),
            if (_audioReal != null)
              TextButton(
                onPressed: () => setState(() => _audioReal = null),
                child: const Text(
                  'Borrar',
                  style: TextStyle(color: Colors.red, fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF09595)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFA32D2D)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'La IA procesará tu foto/audio real para clasificar la emergencia.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFFA32D2D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListVehiculos() {
    if (widget.vehiculos.isEmpty)
      return const Text('No tienes vehículos registrados');
    return Column(
      children: widget.vehiculos.map((v) {
        bool esEste = _vehiculoSeleccionado?.idVehiculo == v.idVehiculo;
        return GestureDetector(
          onTap: () => setState(() => _vehiculoSeleccionado = v),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: esEste ? _rojo : const Color(0xFFE0E8F0),
                width: esEste ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.directions_car,
                  color: esEste ? _rojo : const Color(0xFF7A8A9A),
                ),
                const SizedBox(width: 12),
                Text(
                  '${v.marca} ${v.modelo}',
                  style: GoogleFonts.poppins(
                    fontWeight: esEste ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const Spacer(),
                if (esEste)
                  const Icon(Icons.check_circle, color: _rojo, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIndicadorGPS() {
    return Row(
      children: [
        Icon(
          _obteniendoUbicacion
              ? Icons.satellite_alt
              : (_latitudReal != null ? Icons.gps_fixed : Icons.gps_off),
          color: _obteniendoUbicacion
              ? Colors.orange
              : (_latitudReal != null ? Colors.green : Colors.red),
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          _obteniendoUbicacion
              ? 'Buscando GPS...'
              : (_latitudReal != null ? 'Ubicación obtenida' : 'GPS inactivo.'),
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: const Color(0xFF7A8A9A),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 55,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_enviando || _latitudReal == null)
            ? null
            : _reportarEmergencia,
        style: ElevatedButton.styleFrom(
          backgroundColor: _rojo,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _enviando
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'SOLICITAR AUXILIO',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
