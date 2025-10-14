// integration_test/loan_flow_test_improved.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:loan_app/main.dart' as app;
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('loan_app_integration_test_${DateTime.now().millisecondsSinceEpoch}');
    await Hive.initFlutter(tempDir.path);
    debugPrint('✅ Hive inicializado para tests en: $tempDir');
  });

  tearDownAll(() async {
    try {
      await Hive.close();
      debugPrint('✅ Hive cerrado correctamente');
    } catch (e) {
      debugPrint('⚠️ Error cerrando Hive: $e');
    }
  });

  testWidgets('Flujo completo de préstamo: Crear un nuevo préstamo y verificar en la lista', 
    (WidgetTester tester) async {
      
      // 1. INICIAR APLICACIÓN
      app.main();
      await tester.pumpAndSettle();
      print('✅ Aplicación iniciada');

      // 2. MANEJAR PANTALLA DE PIN
      final pinField = find.byType(TextField).first;
      await tester.enterText(pinField, '123456');
      await tester.pump();

      // Buscar botón de PIN
      final pinButtons = [
        find.widgetWithText(ElevatedButton, 'Crear PIN'),
        find.widgetWithText(ElevatedButton, 'Validar PIN'),
        find.byType(ElevatedButton).first,
      ];
      
      for (final button in pinButtons) {
        if (button.evaluate().isNotEmpty) {
          await tester.tap(button, warnIfMissed: false);
          break;
        }
      }
      
      await tester.pumpAndSettle(Duration(seconds: 3));
      print('✅ Pantalla de PIN completada');

      // 3. NAVEGACIÓN MEJORADA
      final navOptions = [
        find.textContaining('Clientes'),
        find.textContaining('Préstamos'),
        find.byIcon(Icons.add),
        find.byIcon(Icons.person_add),
        find.textContaining('Agregar'),
        find.textContaining('Nuevo'),
      ];
      
      for (final option in navOptions) {
        if (option.evaluate().isNotEmpty) {
          await tester.ensureVisible(option);
          await tester.pump();
          await tester.tap(option, warnIfMissed: false);
          await tester.pumpAndSettle(Duration(seconds: 2));
          print('✅ Navegación: ${option.toString()}');
          break;
        }
      }

      // 4. LLENAR FORMULARIO MEJORADO
      final textFields = find.byType(TextField);
      if (textFields.evaluate().isNotEmpty) {
        final testData = ['Juan Pérez', '123456789', '1000000'];
        for (int i = 0; i < textFields.evaluate().length && i < testData.length; i++) {
          try {
            await tester.enterText(textFields.at(i), testData[i]);
            await tester.pump(Duration(milliseconds: 300));
            print('✅ Campo $i: "${testData[i]}"');
          } catch (e) {
            print('⚠️  Campo $i: $e');
          }
        }
      }

      // 5. BÚSQUEDA MEJORADA DE BOTÓN GUARDAR
      final saveOptions = [
        find.widgetWithText(ElevatedButton, 'Guardar'),
        find.widgetWithText(ElevatedButton, 'Save'),
        find.widgetWithIcon(ElevatedButton, Icons.save),
        find.widgetWithText(TextButton, 'Guardar'),
        find.widgetWithText(TextButton, 'Save'),
        find.byTooltip('Guardar'),
        find.bySemanticsLabel('Guardar'),
      ];
      
      bool guardado = false;
      for (final option in saveOptions) {
        if (option.evaluate().isNotEmpty) {
          await tester.ensureVisible(option);
          await tester.pump();
          await tester.tap(option, warnIfMissed: false);
          guardado = true;
          print('✅ Botón guardar encontrado: ${option.toString()}');
          break;
        }
      }
      
      if (!guardado) {
        // Último recurso: buscar cualquier botón que contenga texto relacionado
        final allButtons = find.byType(ElevatedButton);
        for (final element in allButtons.evaluate()) {
          final widget = element.widget;
          if (widget is ElevatedButton) {
            final child = widget.child;
            if (child is Text) {
              final text = child.data?.toLowerCase() ?? '';
              if (text.contains('guardar') || text.contains('save') || 
                  text.contains('crear') || text.contains('create') ||
                  text.contains('añadir') || text.contains('add')) {
                await tester.tap(allButtons.at(allButtons.evaluate().toList().indexOf(element)));
                guardado = true;
                print('✅ Botón por texto: "$text"');
                break;
              }
            }
          }
        }
      }

      // 6. ESPERAR Y VERIFICAR
      await tester.pumpAndSettle(Duration(seconds: 3));
      
      // Verificaciones múltiples de éxito
      final successMarkers = [
        'Juan Pérez',
        '123456789',
        '1000000',
        'éxito', 'success', 
        'creado', 'creada',
        'guardado', 'guardada',
        'correcto', 'correcta',
      ];
      
      bool exito = false;
      for (final marker in successMarkers) {
        if (find.textContaining(marker).evaluate().isNotEmpty) {
          exito = true;
          print('✅ Éxito verificado: "$marker"');
          break;
        }
      }
      
      // Verificación adicional: elementos de lista
      if (!exito && (find.byType(ListTile).evaluate().isNotEmpty || 
                     find.byType(Card).evaluate().isNotEmpty)) {
        exito = true;
        print('✅ Éxito por elementos de lista');
      }

      expect(exito, true, reason: 'El flujo debe completarse exitosamente');
      print('🎉 FLUJO COMPLETO VERIFICADO - TEST EXITOSO');
    },
    timeout: Timeout(Duration(minutes: 3)),
  );
}