import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
// NOTE: Se asume que estos imports están en tu proyecto
// import 'package:loan_app/data/models/loan_model.dart';
// import 'package:loan_app/domain/entities/client.dart';
// import 'package:loan_app/domain/entities/payment.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:loan_app/main.dart' as app_main;

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
  bool _resetting = false;
  String? _storedPin;
  String? _error;

  static const String _boxName = 'app_settings';
  static const String _pinKey = 'pinCode';

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  // ✅ CARGA SIMPLE DEL PIN
  Future<void> _loadPin() async {
    try {
      debugPrint('🔍 Cargando configuración de PIN...');
      final settingsBox = await app_main.openSettingsBox();
      final value = settingsBox.get(_pinKey);
      final isPinValid = value is String && value.trim().isNotEmpty && value.length == 4;
      
      setState(() {
        _storedPin = isPinValid ? value : null;
        _hasPin = isPinValid;
        _loading = false;
      });
      
    } catch (e) {
      debugPrint('❌ Error cargando PIN: $e');
      setState(() {
        _storedPin = null;
        _hasPin = false;
        _loading = false;
      });
    }
  }

  // ✅ GUARDAR PIN
  Future<void> _savePin(String pin) async {
    try {
      final settingsBox = await app_main.openSettingsBox();
      await settingsBox.put(_pinKey, pin);
      await settingsBox.flush(); 
      
      debugPrint('💾 PIN guardado: $pin');
      
      setState(() {
        _storedPin = pin;
        _hasPin = true;
      });
    } catch (e) {
      debugPrint('❌ Error guardando PIN: $e');
      rethrow;
    }
  }

  // 💣 FUNCIÓN DESTRUCTIVA: RESET NUCLEAR (Borra todos los datos)
  Future<void> _performNuclearReset() async {
    try {
      debugPrint('💥 INICIANDO RESET NUCLEAR...');
      
      // 1. Cerrar todas las cajas de Hive
      await Hive.close();
      debugPrint('✅ Hive cerrado');
      
      // 2. Eliminar carpeta Hive completa
      String hivePath;
      if (Platform.isLinux) {
        hivePath = '${Platform.environment['HOME']}/Documentos/hive_data';
      } else {
        final appDocDir = await getApplicationDocumentsDirectory();
        hivePath = appDocDir.path;
      }
      
      final hiveDir = Directory(hivePath);
      if (await hiveDir.exists()) {
        await hiveDir.delete(recursive: true);
        debugPrint('🗑️ Carpeta eliminada: $hivePath');
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // NOTA: No es necesario llamar a Hive.initFlutter() aquí si ya está en main.dart
      
    } catch (e) {
      debugPrint('❌ Error en reset nuclear: $e');
      rethrow;
    }
  }

  // ✅ VALIDACIÓN/CREACIÓN DE PIN
  void _validateOrCreatePin() {
    final input = _pinController.text.trim();
    
    if (input.isEmpty) {
      setState(() => _error = 'Por favor ingresa el PIN');
      return;
    }
    
    if (input.length != 4 || !RegExp(r'^\d{4}$').hasMatch(input)) {
      setState(() => _error = 'El PIN debe tener 4 dígitos numéricos');
      return;
    }

    setState(() => _error = null);

    // CREAR NUEVO PIN
    if (!_hasPin) {
      _savePin(input).then((_) {
        _showSuccess('PIN configurado correctamente');
        _navigateToHome();
      }).catchError((e) {
        setState(() => _error = 'Error: $e');
      });
      return;
    }

    // VALIDAR PIN EXISTENTE
    if (_storedPin == input) {
      _navigateToHome();
    } else {
      setState(() => _error = 'PIN incorrecto');
    }
  }

  // ✅ NAVEGACIÓN A HOME
  void _navigateToHome() {
    app_main.openDataBoxes().then((_) {
      Navigator.pushReplacementNamed(context, '/home');
    }).catchError((e) {
      setState(() => _error = 'Error cargando datos: $e');
    });
  }

  // -----------------------------------------------------------------------
  // 🎯 FLUJO ÚNICO: OLVIDÉ PIN = BORRAR TODO 🎯
  // -----------------------------------------------------------------------
  
  // ✅ INICIA EL BORRADO TOTAL
  void _initiateReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ REINICIO TOTAL DEL SISTEMA'),
        content: const Text(
          '¡ADVERTENCIA CRÍTICA! ¿Estás seguro que deseas reiniciar el sistema? '
          'Esto **eliminará PERMANENTEMENTE**:\n\n'
          '• Todos los préstamos\n'
          '• Todos los clientes\n'
          '• Todos los pagos\n'
          '• El PIN de acceso\n\n'
          'Tras el reinicio, podrás crear un nuevo PIN. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ELIMINAR TODO Y REINICIAR'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _executeReset();
    }
  }

  // ✅ EJECUCIÓN DEL BORRADO TOTAL Y CAMBIO DE ESTADO
  Future<void> _executeReset() async {
    setState(() => _resetting = true);

    try {
      await _performNuclearReset(); // 💣 Llama al borrado de toda la carpeta Hive
      
      _showSuccess('Sistema reiniciado. Todos los datos han sido eliminados.');
      
      // Recargar estado al modo "Crear PIN"
      setState(() {
        _pinController.clear();
        _error = null;
        _hasPin = false; // <-- Esto fuerza al modo de creación de PIN
        _storedPin = null;
        _resetting = false;
      });
      
    } catch (e) {
      setState(() {
        _resetting = false;
        _error = 'Error en borrado total: $e';
      });
    }
  }
  // -----------------------------------------------------------------------

  // ✅ MOSTRAR MENSAJE DE ÉXITO
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  // ✅ INTERFAZ DE USUARIO SIMPLE (Se usa _initiateReset en el TextButton)
  Widget _buildContent() {
    if (_loading) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Cargando...'),
        ],
      );
    }

    if (_resetting) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
            'Reiniciando sistema...',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Icono y título
        Icon(
          Icons.lock,
          size: 64,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 16),
        Text(
          _hasPin ? 'Ingresa tu PIN' : 'Configura tu PIN',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _hasPin ? 'Para acceder a la aplicación' : 'Crea un PIN de 4 dígitos para seguridad',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),

        // Campo de PIN
        SizedBox(
          width: 200,
          child: TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: _obscure,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, letterSpacing: 8),
            decoration: InputDecoration(
              labelText: 'PIN',
              counterText: '',
              errorText: _error,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 24),

        // Botón de acción
        SizedBox(
          width: 200,
          child: ElevatedButton(
            onPressed: _validateOrCreatePin,
            child: Text(_hasPin ? 'Validar' : 'Crear PIN'),
          ),
        ),

        // Botón de reset (solo si hay PIN)
        if (_hasPin) ...[
          const SizedBox(height: 16),
          TextButton(
            // 🎯 CAMBIO CLAVE: Llama al flujo de borrado total
            onPressed: _initiateReset, 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Olvidé mi PIN (Borrar Todos los Datos)'),
          ),
        ],

        // Información
        const SizedBox(height: 32),
        Text(
          'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso Seguro'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _buildContent(),
        ),
      ),
    );
  }
}