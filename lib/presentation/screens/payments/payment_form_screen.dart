// lib/presentation/screens/payments/payment_form_screen.dart

import 'package:flutter/material.dart';

class PaymentFormScreen extends StatelessWidget {
  const PaymentFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Pago'),
      ),
      body: const Center(
        child: Text(
          '¡Esta es la pantalla de registro de pagos!',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}