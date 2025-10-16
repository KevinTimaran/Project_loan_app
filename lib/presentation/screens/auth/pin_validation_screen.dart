// lib/presentation/screens/auth/pin_validation_screen.dart (EDITADO Y MEJORADO)

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class PinValidationScreen extends StatefulWidget {
  const PinValidationScreen({super.key});

  @override
  State<PinValidationScreen> createState() => _PinValidationScreenState();
}

class _PinValidationScreenState extends State<PinValidationScreen> {
  final TextEditingController _pinController = TextEditingController();

  bool _loading = true;
  bool _hasPin = false;
  bool _obscure = true;
  String? _storedPin;
  String? _error;

  static const String _boxName = 'app_settings';
  static const String _pinKey = 'pinCode';

  @override
  void initState() {
    super.initState();
    _initHiveAndLoadPin();
  }

  Future<void> _initHiveAndLoadPin() async {
    try {
      final box = await Hive.openBox(_boxName);
      final value = box.get(_pinKey);
      final isPinValid = value is String && value.trim().isNotEmpty;
      if (mounted) {
        setState(() {
          _storedPin = isPinValid ? value : null;
          _hasPin = isPinValid;
        });
      }
    } catch (e) {
      debugPrint('Error leyendo PIN desde Hive: $e');
      if (mounted) {
        setState(() {
          _storedPin = null;
          _hasPin = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Box get _settingsBox => Hive.box(_boxName);

  Future<void> _savePin(String pin) async {
    await _settingsBox.put(_pinKey, pin);
    _storedPin = pin;
    _hasPin = true;
  }

  Future<void> _deletePin() async {
    await _settingsBox.delete(_pinKey);
    _storedPin = null;
    _hasPin = false;
  }

  // --- Mejoras de validación y seguridad ---
  bool _isPinInsecure(String pin) {
    const insecurePins = {'0000', '1234', '1111', '2222', '4321', '1212', '9999', '5555', '1004', '2000'};
    return insecurePins.contains(pin);
  }

  void _onValidatePressed() {
    final input = _pinController.text.trim();
    setState(() => _error = null);

    if (input.isEmpty) {
      setState(() => _error = 'Por favor ingresa el PIN.');
      return;
    }

    // FLUJO DE CREACIÓN DE PIN
    if (!_hasPin) {
      if (input.length != 4 || !RegExp(r'^\d{4}$').hasMatch(input)) {
        setState(() => _error = 'El PIN debe tener exactamente 4 dígitos numéricos.');
        return;
      }
      if (_isPinInsecure(input)) {
        setState(() => _error = 'El PIN elegido es demasiado fácil. Elige uno más seguro.');
        return;
      }
      _savePin(input).then((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN guardado correctamente')));
          _pinController.clear();
          Navigator.pushReplacementNamed(context, '/home');
        }
      }).catchError((e) {
        setState(() => _error = 'Error al guardar PIN: $e');
      });
      return;
    }

    // FLUJO DE VALIDACIÓN DE PIN
    if (_storedPin == input) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() {
        _error = 'PIN incorrecto. Intenta de nuevo.';
      });
    }
  }

  void _onForgotPin() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Olvidé PIN'),
        content: const Text('Esta acción eliminará el PIN guardado, permitiéndote configurar uno nuevo. ¿Estás seguro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar y Resetear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldReset == true) {
      await _deletePin();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN eliminado. Por favor, ingresa uno nuevo para configurarlo.')));
        setState(() {
          _pinController.clear();
          _error = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Widget _buildContent() {
    final subtitle = _hasPin ? 'Ingresa tu PIN' : 'Crea un PIN de acceso (exactamente 4 dígitos)';
    final actionLabel = _hasPin ? 'Validar PIN' : 'Crear PIN';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock, size: 72, color: Theme.of(context).primaryColor),
        const SizedBox(height: 12),
        Text('Validación de credenciales', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        const SizedBox(height: 20),
        SizedBox(
          width: 260,
          child: TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: _obscure,
            maxLength: 4,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'PIN',
              counterText: '',
              errorText: _error,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pinController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _pinController.clear()),
                    ),
                  IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ],
              ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _onValidatePressed(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 260,
          child: ElevatedButton(
            onPressed: _onValidatePressed,
            child: Text(actionLabel, style: const TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 8),
        if (_hasPin)
          TextButton(
            onPressed: _onForgotPin,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Olvidé mi PIN / Resetear'),
          ),
        const SizedBox(height: 20),
        Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acceso a la Aplicación')),
      body: Center(
        child: _loading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Cargando configuración...'),
                ],
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Center(child: _buildContent()),
              ),
      ),
    );
  }
}