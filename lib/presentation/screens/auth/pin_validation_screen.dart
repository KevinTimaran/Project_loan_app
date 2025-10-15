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
  
  // Variables de Estado
  bool _loading = true;
  bool _hasPin = false; // Indica si ya hay un PIN guardado (Validación vs Creación)
  bool _obscure = true;
  String? _storedPin;
  String? _error;
  
  // Constantes de Hive
  static const String _boxName = 'app_settings';
  static const String _pinKey = 'pinCode';

  @override
  void initState() {
    super.initState();
    _initHiveAndLoadPin();
  }

  // --- LÓGICA DE HIVE Y CARGA INICIAL ---
  Future<void> _initHiveAndLoadPin() async {
    try {
      // 1. Abre la caja de settings (el main ya la abre, pero es un buen fallback)
      final box = await Hive.openBox(_boxName);
      
      // 2. Lee el valor del PIN
      final value = box.get(_pinKey);
      
      // 3. Verifica si es una cadena válida y no está vacía
      final isPinValid = value is String && value.trim().isNotEmpty;

      if (mounted) {
        setState(() {
          _storedPin = isPinValid ? value : null;
          _hasPin = isPinValid;
        });
      }
    } catch (e) {
      // Manejo de errores: si falla la lectura, asumimos que no hay PIN
      debugPrint('Error leyendo PIN desde Hive: $e');
      if (mounted) {
        setState(() {
          _storedPin = null;
          _hasPin = false;
        });
      }
    } finally {
      // 4. Finaliza la carga
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
  
  // --- MÉTODOS CRUD DEL PIN ---
  
  // Abrir la caja de forma segura (se usa en save/delete)
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

  // --- LÓGICA DE VALIDACIÓN Y NAVEGACIÓN ---

  void _onValidatePressed() {
    final input = _pinController.text.trim();
    setState(() => _error = null);

    if (input.isEmpty) {
      setState(() => _error = 'Por favor ingresa el PIN.');
      return;
    }

    // 1. FLUJO DE CREACIÓN DE PIN (NO HAY PIN GUARDADO)
    if (!_hasPin) {
      if (input.length < 4) {
        setState(() => _error = 'El PIN debe tener al menos 4 dígitos.');
        return;
      }
      
      _savePin(input).then((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN guardado correctamente')));
          _pinController.clear();
          // Navegar a home (reemplaza la pantalla de PIN)
          Navigator.pushReplacementNamed(context, '/home');
        }
      }).catchError((e) {
        setState(() => _error = 'Error al guardar PIN: $e');
      });
      return;
    }

    // 2. FLUJO DE VALIDACIÓN DE PIN (YA HAY PIN GUARDADO)
    if (_storedPin == input) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() {
        _error = 'PIN incorrecto. Intenta de nuevo.';
      });
    }
  }

  // --- RESET DE PIN ---
  
  void _onForgotPin() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Olvidé PIN'),
        content: const Text('Esta acción eliminará el PIN guardado, permitiéndote configurar uno nuevo. ¿Estás seguro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          // Usamos un color distintivo para la acción de eliminación
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
  
  // --- WIDGETS DE UI ---

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Widget _buildContent() {
    final subtitle = _hasPin ? 'Ingresa tu PIN' : 'Crea un PIN de acceso (mín. 4 dígitos)';
    final actionLabel = _hasPin ? 'Validar PIN' : 'Crear PIN';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock, size: 72, color: Theme.of(context).primaryColor),
        const SizedBox(height: 12),
        Text('Validación de credenciales', style: Theme.of(context).textTheme.titleLarge), // título más prominente
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 16)),
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
            child: Text(actionLabel, style: const TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 8),
        if (_hasPin)
          TextButton(
            onPressed: _onForgotPin,
            child: const Text('Olvidé mi PIN / Resetear'),
          ),
        const SizedBox(height: 20),
        // Se usa `const` si la fecha no cambia dinámicamente, o se envuelve en Builder si lo hace
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