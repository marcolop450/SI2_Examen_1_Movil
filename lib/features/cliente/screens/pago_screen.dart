import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_paypal/flutter_paypal.dart';
import '../../../core/services/pago_service.dart';

class PagoScreen extends StatefulWidget {
  final int incidenteId;
  final double costoTotal;

  const PagoScreen({
    super.key,
    required this.incidenteId,
    required this.costoTotal,
  });

  @override
  State<PagoScreen> createState() => _PagoScreenState();
}

class _PagoScreenState extends State<PagoScreen> {
  static const _navy = Color(0xFF0D1B2A);
  static const _verde = Color(0xFF2E7D32);
  static const _paypalBlue = Color(0xFF003087);

  bool _procesando = false;

  Future<void> _registrarPagoExitoso() async {
    setState(() => _procesando = true);
    try {
      await PagoService.registrarPago(
        incidenteId: widget.incidenteId,
        monto: widget.costoTotal,
        metodo: 'paypal',
      );

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('incidente_activo_id');

      if (mounted) {
        _mostrarExitoYSalir();
      }
    } catch (e) {
      setState(() => _procesando = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _mostrarExitoYSalir() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, color: _verde, size: 80),
            const SizedBox(height: 16),
            Text(
              '¡Pago Confirmado!',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'El pago a través de PayPal fue exitoso y el técnico ha sido notificado.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text(
                  'VOLVER AL INICIO',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double totalUSD = widget.costoTotal / 6.96;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Liquidación de Servicio',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: _navy,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Resumen del Auxilio #${widget.incidenteId}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),

            Card(
              elevation: 6,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'TOTAL A PAGAR',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      'Bs. ${widget.costoTotal.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: _navy,
                      ),
                    ),
                    const Divider(height: 30),
                    Text(
                      'Seleccione su método de pago',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: _navy,
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _paypalBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.payment, color: Colors.white),
                        label: Text(
                          'Pagar con PayPal',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        onPressed: _procesando
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (BuildContext context) => UsePaypal(
                                      sandboxMode: true,
                                      clientId:
                                          "AU_FgWBuXnOFtpiwWhbCqYePfn_zqxkNSfgNbnB1ztmHZMyP95CJo3b_s1KgRQ06WSXYYSEMTlqgAmKw",
                                      secretKey:
                                          "EBEyVJ_ojv1iD_61lEWPJrrvYC6Qg-sP0t3piK_jRbk0XzJ7oW17slVugBd06yUD1gnGjk0yb1R2hKax",
                                      returnURL:
                                          "https://sandbox.paypal.com/success?clear=1",
                                      cancelURL:
                                          "https://sandbox.paypal.com/cancel?clear=1",
                                      transactions: [
                                        {
                                          "amount": {
                                            "total": totalUSD.toStringAsFixed(
                                              2,
                                            ),
                                            "currency": "USD",
                                            "details": {
                                              "subtotal": totalUSD
                                                  .toStringAsFixed(2),
                                              "shipping": '0',
                                              "shipping_discount": 0,
                                            },
                                          },
                                          "description":
                                              "Pago por Auxilio Mecánico #${widget.incidenteId}",
                                          // 🔥 AGREGADO PARA EVITAR ERRORES EN SANDBOX
                                          "item_list": {
                                            "items": [
                                              {
                                                "name":
                                                    "Servicio de Asistencia",
                                                "quantity": 1,
                                                "price": totalUSD
                                                    .toStringAsFixed(2),
                                                "currency": "USD",
                                              },
                                            ],
                                          },
                                        },
                                      ],
                                      note:
                                          "Gracias por utilizar nuestra plataforma.",
                                      onSuccess: (Map params) async {
                                        print(
                                          "Pago exitoso en Sandbox: $params",
                                        );
                                        await _registrarPagoExitoso();
                                      },
                                      onError: (error) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              "Error en el pago: $error",
                                            ),
                                          ),
                                        );
                                      },
                                      onCancel: (params) {
                                        print('Pago cancelado: $params');
                                      },
                                    ),
                                  ),
                                );
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
