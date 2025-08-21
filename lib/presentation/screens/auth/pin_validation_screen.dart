// lib/presentation/screens/auth/pin_validation_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loan_app/presentation/screens/home_screen.dart'; // Importa HomeScreen
import 'package:loan_app/presentation/screens/auth/pin_setup_screen.dart'; // Importa PinSetupScreen

class PinValidationScreen extends StatefulWidget {
  const PinValidationScreen({super.key});

  @override
  State<PinValidationScreen> createState() => _PinValidationScreenState();
}

class _PinValidationScreenState extends State<PinValidationScreen> {
  final TextEditingController _pinController = TextEditingController();
  String? _storedPin;

  @override
  void initState() {
    super.initState();
    _loadStoredPin();
  }

  Future<void> _loadStoredPin() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _storedPin = prefs.getString('user_pin');
    });
  }

  void _validatePin() {
    if (_pinController.text == _storedPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN correcto. Acceso concedido.')),
      );
      // Navega a HomeScreen usando la ruta nombrada
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN incorrecto. Intenta de nuevo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_storedPin == null) {
      // Muestra un indicador de carga o redirige si el PIN no está cargado
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Validar PIN'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Ingresa tu PIN de seguridad para continuar.',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Ingresa tu PIN',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _validatePin,
              child: const Text('Validar PIN'),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Reiniciar Aplicación'),
                    content: const Text('Esto borrará tu PIN y datos. ¿Estás seguro?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('user_pin');
                          Navigator.of(ctx).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => const PinSetupScreen()),
                            (Route<dynamic> route) => false,
                          );
                        },
                        child: const Text('Borrar PIN y Reiniciar'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('¿Olvidaste tu PIN? Reiniciar'),
            ),
          ],
        ),
      ),
    );
  }
}