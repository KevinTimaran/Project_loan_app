
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final TextEditingController _pinController = TextEditingController();

  // 3.1.3 Botones: Lógica para guardar el PIN
  Future<void> _setPin() async {
    if (_pinController.text.length == 4) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_pin', _pinController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN configurado con éxito')),
      );
      // Navegamos a la pantalla de la lista de préstamos.
      Navigator.of(context).pushReplacementNamed('/loanList');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El PIN debe tener 4 dígitos')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 3.1.5 Elementos fijos: Encabezado superior
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
            // 3.1.2 Tipografía: Texto base con estilo
            const Text(
              'Establece un PIN de 4 dígitos para tu aplicación.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // 3.1.3 Campos de formulario estandarizado
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
            // 3.1.3 Botón principal (CTA)
            ElevatedButton(
              onPressed: _setPin,
              child: const Text('Guardar PIN', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}