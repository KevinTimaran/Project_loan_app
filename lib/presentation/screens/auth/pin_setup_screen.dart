// lib/presentation/screens/auth/pin_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:loan_app/presentation/screens/loans/loan_form_screen.dart';
import 'package:loan_app/presentation/screens/loans/loan_list_screen.dart'; // Importa la pantalla de lista de préstamos

/// Pantalla básica de configuración de PIN.
/// En una aplicación real, aquí se implementaría la lógica para establecer y verificar un PIN.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final TextEditingController _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _setupPin() {
    if (_formKey.currentState!.validate()) {
      // Lógica de configuración de PIN (simulada)
      // En una app real, guardarías el PIN de forma segura y harías validaciones.
      debugPrint('PIN configurado: ${_pinController.text}');

      // Navegar a la pantalla principal de préstamos después de la configuración del PIN.
      // Usa pushReplacement para que el usuario no pueda volver a esta pantalla con el botón de atrás.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoanListScreen()),
      );
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar PIN'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Por favor, configura tu PIN de seguridad',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true, // Para ocultar el PIN
                maxLength: 4, // Por ejemplo, un PIN de 4 dígitos
                decoration: const InputDecoration(
                  labelText: 'Ingresa tu PIN',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty || value.length != 4) {
                    return 'El PIN debe tener 4 dígitos';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _setupPin,
                child: const Text('Configurar PIN y Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
