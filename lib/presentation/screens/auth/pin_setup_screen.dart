import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final TextEditingController _pinController = TextEditingController();
  static const String _boxName = 'app_settings';
  static const String _pinKey = 'pinCode';
  bool _isResetting = false;

  // ✅ SOLUCIÓN CORREGIDA: No usar initFlutter() si ya está inicializado
  Future<void> _nuclearReset() async {
    try {
      debugPrint('💥 INICIANDO ELIMINACIÓN NUCLEAR DE DATOS...');
      
      // 1. Cerrar todas las cajas de Hive
      await Hive.close();
      debugPrint('✅ Todas las cajas de Hive cerradas');

      // 2. Eliminar la carpeta completa de Hive
      final appDocDir = await getApplicationDocumentsDirectory();
      final hivePath = '${appDocDir.path}/hive';
      final hiveDir = Directory(hivePath);
      
      if (await hiveDir.exists()) {
        await hiveDir.delete(recursive: true);
        debugPrint('🗑️ Carpeta Hive eliminada: $hivePath');
      } else {
        debugPrint('⚠️ Carpeta Hive no encontrada: $hivePath');
      }

      // 3. ✅ CORRECCIÓN: No llamar initFlutter() - ya está inicializado
      // En su lugar, simplemente abrir las cajas necesarias
      debugPrint('🔄 Hive listo para reutilizar');

      debugPrint('🎉 ELIMINACIÓN NUCLEAR COMPLETADA - TODOS LOS DATOS DESTRUIDOS');
      
    } catch (e) {
      debugPrint('❌ Error en eliminación nuclear: $e');
      rethrow;
    }
  }

  // ✅ SOLUCIÓN ALTERNATIVA MEJORADA
  Future<void> _deleteAllBoxesIndividually() async {
    try {
      debugPrint('🔍 Eliminando cajas individualmente...');
      
      // Lista de TODAS las cajas Hive que usa tu app
      final boxNames = [
        'loans',
        'clients', 
        'payments',
        'app_settings',
        // Agrega aquí cualquier otra caja que uses
      ];

      for (var boxName in boxNames) {
        try {
          debugPrint('🔄 Procesando caja: $boxName');
          
          // Intentar eliminar directamente
          await Hive.deleteBoxFromDisk(boxName);
          debugPrint('   🗑️ Caja $boxName eliminada del disco');
          
        } catch (e) {
          debugPrint('   ⚠️ Error con caja $boxName: $e');
          // Intentar cerrar primero y luego eliminar
          try {
            if (Hive.isBoxOpen(boxName)) {
              await Hive.box(boxName).close();
            }
            await Hive.deleteBoxFromDisk(boxName);
            debugPrint('   ✅ Caja $boxName eliminada después de cerrar');
          } catch (e2) {
            debugPrint('   ❌ Error persistente con caja $boxName: $e2');
          }
        }
      }

      debugPrint('✅ Todas las cajas procesadas');
    } catch (e) {
      debugPrint('❌ Error en eliminación individual: $e');
      rethrow;
    }
  }

  // ✅ MÉTODO PRINCIPAL MEJORADO
  Future<void> _setPin() async {
    final pin = _pinController.text.trim();
    
    if (pin.length == 4 && RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() {
        _isResetting = true;
      });

      try {
        // Mostrar diálogo de confirmación
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ ADVERTENCIA'),
            content: const Text(
              'Esta acción eliminará PERMANENTEMENTE:\n\n'
              '• Todos los préstamos\n'
              '• Todos los clientes\n'
              '• Todos los pagos\n'
              '• Toda la configuración\n\n'
              '¿Estás completamente seguro?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('ELIMINAR TODO', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (shouldProceed != true) {
          setState(() {
            _isResetting = false;
          });
          return;
        }

        // INTENTAR MÉTODO NUCLEAR PRIMERO
        debugPrint('🚀 Intentando método nuclear...');
        await _nuclearReset();

      } catch (e) {
        debugPrint('❌ Método nuclear falló, intentando método individual...');
        
        // FALLBACK: Método individual
        try {
          await _deleteAllBoxesIndividually();
        } catch (e2) {
          debugPrint('❌ Ambos métodos fallaron: $e2');
          if (!mounted) return;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error crítico: $e2')),
          );
          setState(() {
            _isResetting = false;
          });
          return;
        }
      }

      // GUARDAR NUEVO PIN
      try {
        final settingsBox = await Hive.openBox(_boxName);
        await settingsBox.put(_pinKey, pin);
        await settingsBox.flush();
        
        debugPrint('✅ Nuevo PIN guardado: $pin');

        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PIN configurado y TODOS los datos eliminados'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pushReplacementNamed('/home');
        
      } catch (e) {
        debugPrint('❌ Error guardando nuevo PIN: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error guardando PIN: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El PIN debe tener exactamente 4 dígitos numéricos'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      _isResetting = false;
    });
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
              '⚠️ ADVERTENCIA CRÍTICA ⚠️\n\n'
              'Al establecer un nuevo PIN, se eliminarán PERMANENTEMENTE:\n\n'
              '• Todos los préstamos\n'
              '• Todos los clientes\n'
              '• Todos los pagos\n'
              '• Toda la configuración\n\n'
              'Esta acción NO se puede deshacer.',
              style: TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: 'Ingresa tu nuevo PIN (4 dígitos)',
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
            if (_isResetting)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Eliminando todos los datos...\nEsto puede tomar unos segundos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.orange),
                  ),
                ],
              )
            else
              ElevatedButton(
                onPressed: _setPin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  '🔥 ELIMINAR TODO Y CONFIGURAR NUEVO PIN',
                  style: TextStyle(fontSize: 14, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}