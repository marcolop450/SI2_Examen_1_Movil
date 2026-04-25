// lib/features/cliente/tabs/vehiculos_tab.dart
// Tab 1 — CU5: listar, agregar y eliminar vehículos
// GET    /vehiculos/
// POST   /vehiculos/    → HTTP 201
// DELETE /vehiculos/{id}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/vehiculo_service.dart';
import '../../../models/vehiculo_model.dart';

class VehiculosTab extends StatefulWidget {
  final List<VehiculoModel> vehiculos;
  final Future<void> Function() onRefresh;

  const VehiculosTab({
    super.key,
    required this.vehiculos,
    required this.onRefresh,
  });

  @override
  State<VehiculosTab> createState() => _VehiculosTabState();
}

class _VehiculosTabState extends State<VehiculosTab> {
  static const _rojo = Color(0xFFE24B4A);
  static const _navy = Color(0xFF0D1B2A);
  static const _gris = Color(0xFF7A8A9A);
  static const _borde = Color(0xFFE0E8F0);

  // ── Eliminar vehículo con confirmación
  Future<void> _eliminar(VehiculoModel v) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Eliminar vehículo',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        content: Text(
          '¿Eliminar ${v.marca ?? ''} ${v.modelo ?? ''} (${v.placa})?',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: GoogleFonts.poppins(color: _gris)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: GoogleFonts.poppins(color: _rojo)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await VehiculoService.eliminarVehiculo(v.idVehiculo);
        await widget.onRefresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vehículo eliminado'),
              backgroundColor: Color(0xFF3B6D11),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: _rojo,
            ),
          );
        }
      }
    }
  }

  // ── Bottom sheet para agregar vehículo
  void _mostrarFormularioAgregar() {
    final placaCtrl = TextEditingController();
    final marcaCtrl = TextEditingController();
    final modeloCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle del sheet
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0D8E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Agregar Vehículo',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 16),
                // Campos del formulario
                _campo(
                  ctrl: placaCtrl,
                  label: 'Placa *',
                  hint: 'ABC-123',
                  validator: (v) =>
                      v == null || v.isEmpty ? 'La placa es obligatoria' : null,
                ),
                const SizedBox(height: 12),
                _campo(ctrl: marcaCtrl, label: 'Marca', hint: 'Toyota'),
                const SizedBox(height: 12),
                _campo(ctrl: modeloCtrl, label: 'Modelo', hint: 'Corolla'),
                const SizedBox(height: 12),
                _campo(ctrl: colorCtrl, label: 'Color', hint: 'Rojo'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _rojo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: guardando
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setModal(() => guardando = true);
                            try {
                              // POST /vehiculos/
                              await VehiculoService.registrarVehiculo(
                                placa: placaCtrl.text.trim().toUpperCase(),
                                marca: marcaCtrl.text.trim(),
                                modelo: modeloCtrl.text.trim(),
                                color: colorCtrl.text.trim(),
                              );
                              await widget.onRefresh();
                              if (mounted) Navigator.pop(ctx);
                            } catch (e) {
                              setModal(() => guardando = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      e.toString().replaceFirst(
                                        'Exception: ',
                                        '',
                                      ),
                                    ),
                                    backgroundColor: _rojo,
                                  ),
                                );
                              }
                            }
                          },
                    child: guardando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Guardar',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextFormField _campo({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      validator: validator,
      style: GoogleFonts.poppins(fontSize: 14, color: _navy),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.poppins(fontSize: 12, color: _gris),
        hintStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: const Color(0xFFB0BAC4),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _borde),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _borde),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _rojo, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F5),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarFormularioAgregar,
        backgroundColor: _rojo,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        color: _rojo,
        onRefresh: widget.onRefresh,
        child: widget.vehiculos.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 80),
                  Icon(
                    Icons.directions_car_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes vehículos registrados',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 15, color: _gris),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toca el botón + para agregar tu primer vehículo',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFFAAB4BE),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: widget.vehiculos.length,
                itemBuilder: (_, i) {
                  final v = widget.vehiculos[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _borde, width: 0.5),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCEBEB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.directions_car,
                          color: _rojo,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        '${v.marca ?? ''} ${v.modelo ?? ''}'.trim().isEmpty
                            ? 'Vehículo'
                            : '${v.marca ?? ''} ${v.modelo ?? ''}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _navy,
                        ),
                      ),
                      subtitle: Text(
                        'Placa: ${v.placa}  ·  ${v.color ?? 'Sin color'}',
                        style: GoogleFonts.poppins(fontSize: 12, color: _gris),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFFD0D8E0),
                        ),
                        onPressed: () => _eliminar(v),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
