// test/widget_test.dart
// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Importa tu widget principal
import 'package:loan_app/main.dart'; // Asume que MyApp está aquí

// ✅ NUEVO: Importa Hive y dependencias necesarias para inicializarlo en tests
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() {
  // ✅ NUEVO: Configurar Hive antes de ejecutar cualquier test en este grupo
  setUpAll(() async {
    // WidgetsFlutterBinding.ensureInitialized(); // Ya lo llama testWidgets

    // Determinar una ruta temporal para Hive en el entorno de prueba
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path;

    // Inicializar Hive con la ruta temporal
    // Usamos `Hive.initFlutter()` que maneja rutas en tests también.
    // Si prefieres usar `Hive.init()` directamente con `tempPath`, también funciona.
    await Hive.initFlutter(tempPath); // O simplemente await Hive.init(tempPath);

    // ✅ REGISTRA TUS ADAPTADORES AQUÍ SI LOS USAS EN EL TEST
    // Por ejemplo, si usas Client, LoanModel, Payment:
    // Hive.registerAdapter(ClientAdapter());
    // Hive.registerAdapter(LoanModelAdapter());
    // Hive.registerAdapter(PaymentAdapter());

    // Opcional: Abrir cajas específicas que sepas que se usarán en el test
    // await Hive.openBox('pinBox'); // Si sabes que se usará esta caja
    
    print('✅ Hive initialized for tests in: $tempPath');
  });

  // ✅ NUEVO: Limpiar después de los tests (cerrar cajas, borrar datos temporales si es necesario)
  tearDownAll(() async {
    // Cerrar todas las cajas abiertas
    // await Hive.close(); // Cierra todas las cajas
    // O cerrar específicas:
    // if (Hive.isBoxOpen('pinBox')) await Hive.box('pinBox').close();
    
    // Opcional: Borrar los archivos temporales de Hive si quieres empezar limpio
    // Directory tempDir = await getTemporaryDirectory();
    // String tempPath = tempDir.path;
    // final hiveTempDir = Directory('$tempPath/hive_data'); // Ajusta según tu estructura
    // if (await hiveTempDir.exists()) {
    //   await hiveTempDir.delete(recursive: true);
    //   print('🧹 Hive temporary data deleted.');
    // }
    print('🧹 Hive cleanup (if needed) after tests.');
  });

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp()); // MyApp debe estar definido en lib/main.dart

    // Verificar que algo de la pantalla inicial se muestra.
    // Como el test original era un "smoke test" básico, verificamos simplemente
    // que no haya errores críticos al construir la app.
    // Si PinValidationScreen tiene un campo de texto o botón específico,
    // puedes buscarlo aquí. Ejemplo genérico:
    expect(find.byType(Scaffold), findsOneWidget); // Asegura que se dibuja al menos un Scaffold

    // NOTA: El test original intentaba encontrar texto '0' y '1' relacionado con un Counter.
    // Tu app real probablemente no tenga ese Counter, por lo que ese test no es relevante.
    // Puedes eliminar o modificar estas líneas según lo que quieras probar realmente.
    //
    // Si tu app *sí* tiene un contador visible desde el inicio, ajusta esto:
    // expect(find.text('0'), findsOneWidget);
    // expect(find.text('1'), findsNothing);

    // Ejemplo de interacción si hubiera un botón incrementar (ajusta según tu UI):
    // await tester.tap(find.byIcon(Icons.add)); // O find.byType(ElevatedButton)
    // await tester.pump(); // Reconstruye después de la interacción

    // Verifica el cambio si se hizo clic en algo:
    // expect(find.text('0'), findsNothing);
    // expect(find.text('1'), findsOneWidget);
  });
}