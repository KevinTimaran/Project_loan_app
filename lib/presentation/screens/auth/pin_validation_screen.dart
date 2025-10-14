// lib/presentation/screens/auth/pin_validation_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

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
  final String _boxName = 'app_settings';
  final String _pinKey = 'pinCode';
  bool _hiveInitialized = false;

  @override
  void initState() {
    super.initState();
    _initHiveAndLoadPin();
  }

  Future<void> _initHiveAndLoadPin() async {
    try {
      // ✅ INICIALIZACIÓN ROBUSTA DE HIVE PARA TESTS Y PRODUCCIÓN
      if (!_hiveInitialized) {
        await _initializeHive();
      }

      // Abre la caja de settings si no está abierta
      if (!Hive.isBoxOpen(_boxName)) {
        await Hive.openBox(_boxName);
      }
      
      final box = Hive.box(_boxName);
      final value = box.get(_pinKey);
      
      if (value != null && value is String && value.trim().isNotEmpty) {
        _storedPin = value;
        _hasPin = true;
      } else {
        _storedPin = null;
        _hasPin = false;
      }
    } catch (e) {
      // Si hay error, asumimos que no hay PIN
      _storedPin = null;
      _hasPin = false;
      print('Error inicializando Hive o leyendo PIN: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ✅ FUNCIÓN MEJORADA PARA INICIALIZAR HIVE
  Future<void> _initializeHive() async {
    try {
      // Primero intentamos con path_provider (para producción)
      final appDir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(appDir.path);
      _hiveInitialized = true;
    } catch (e) {
      // Fallback para entorno de tests
      try {
        final tempDir = await Directory.systemTemp.createTemp();
        await Hive.initFlutter(tempDir.path);
        _hiveInitialized = true;
      } catch (e2) {
        // Último recurso: intentar sin path específico
        try {
          Hive.init(null);
          _hiveInitialized = true;
        } catch (e3) {
          print('No se pudo inicializar Hive: $e3');
          _hiveInitialized = false;
        }
      }
    }
  }

  Future<void> _savePin(String pin) async {
    try {
      if (!_hiveInitialized) {
        await _initializeHive();
      }
      
      final box = Hive.box(_boxName);
      await box.put(_pinKey, pin);
      _storedPin = pin;
      _hasPin = true;
    } catch (e) {
      throw Exception('Error guardando PIN: $e');
    }
  }

  Future<void> _deletePin() async {
    try {
      if (!_hiveInitialized) {
        await _initializeHive();
      }
      
      final box = Hive.box(_boxName);
      await box.delete(_pinKey);
      _storedPin = null;
      _hasPin = false;
    } catch (e) {
      throw Exception('Error eliminando PIN: $e');
    }
  }

  void _onValidatePressed() {
    final input = _pinController.text.trim();
    setState(() {
      _error = null;
    });

    if (input.isEmpty) {
      setState(() => _error = 'Por favor ingresa el PIN.');
      return;
    }

    // Si no hay PIN guardado, en este flujo interpretamos que está creando PIN
    if (!_hasPin) {
      if (input.length < 4) {
        setState(() => _error = 'El PIN debe tener al menos 4 dígitos.');
        return;
      }
      _savePin(input).then((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN guardado correctamente'))
          );
          _pinController.clear();
          // Navegar a home
          Navigator.pushReplacementNamed(context, '/home');
        }
      }).catchError((e) {
        setState(() => _error = 'Error al guardar PIN: $e');
      });
      return;
    }

    // Si hay PIN guardado, validamos
    if (_storedPin == input) {
      // PIN correcto -> navega a home (reemplazando)
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() {
        _error = 'PIN incorrecto. Intenta de nuevo.';
      });
    }
  }

  void _onForgotPin() async {
    // Confirmación antes de eliminar PIN
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Olvidé PIN'),
        content: const Text('¿Deseas eliminar el PIN guardado y configurar uno nuevo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('Cancelar')
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Eliminar')
          ),
        ],
      ),
    );

    if (shouldReset == true) {
      await _deletePin();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN eliminado. Ingresa uno nuevo.'))
        );
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
    final subtitle = _hasPin 
        ? 'Ingresa tu PIN' 
        : 'Crea un PIN de acceso (mín. 4 dígitos)';
    final actionLabel = _hasPin ? 'Validar PIN' : 'Crear PIN';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock, size: 72, color: Theme.of(context).primaryColor),
        const SizedBox(height: 12),
        Text(
          'Validación de credenciales', 
          style: Theme.of(context).textTheme.titleMedium
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        SizedBox(
          width: 260,
          child: TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: _obscure,
            maxLength: 8,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'PIN',
              counterText: '',
              errorText: _error,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => _onValidatePressed(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 260,
          child: ElevatedButton(
            onPressed: _onValidatePressed,
            child: Text(actionLabel),
          ),
        ),
        const SizedBox(height: 8),
        if (_hasPin)
          TextButton(
            onPressed: _onForgotPin,
            child: const Text('Olvidé mi PIN / Resetear'),
          ),
        const SizedBox(height: 20),
        Text(
          'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', 
          style: const TextStyle(fontSize: 12, color: Colors.grey)
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Validación de Credenciales')),
      body: Center(
        child: _loading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Validando credenciales...'),
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