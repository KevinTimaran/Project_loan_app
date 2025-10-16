import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final TextEditingController _pinController = TextEditingController();

  // Limpia todos los datos de SharedPreferences y Hive
  Future<void> _clearAllAppData() async {
    // Borra SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Lista manual de cajas Hive que usas en tu app
    final boxNames = [
      'loans',
      'clients',
      'payments',
      // agrega aquí los nombres de todas tus cajas Hive
    ];

    for (var boxName in boxNames) {
      final box = await Hive.openBox(boxName);
      await box.clear();
    }
  }

  Future<void> _setPin() async {
    final pin = _pinController.text.trim();
    if (pin.length == 4 && RegExp(r'^\d{4}$').hasMatch(pin)) {
      await _clearAllAppData();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_pin', pin);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN configurado y datos restaurados')),
      );
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El PIN debe tener exactamente 4 dígitos numéricos')),
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
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Establece un PIN de 4 dígitos para tu aplicación.\n\nAl guardar, se eliminarán TODOS los datos de la app.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: 'Ingresa tu nuevo PIN',
                labelStyle: const TextStyle(color: Color(0xFFBDBDBD)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _setPin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Guardar PIN y borrar datos', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}