// test/widget_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_app/main.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory _tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    _tempDir = await Directory.systemTemp.createTemp('loan_app_hive_test_');
    final tempPath = _tempDir.path;

    Hive.init(tempPath);

    // Si usas adapters: registralos aquí
    // Hive.registerAdapter(ClientAdapter());
    // Hive.registerAdapter(PaymentAdapter());
    // Hive.registerAdapter(LoanModelAdapter());

    // Abrir cajas necesarias si tu app espera que existan
    // await Hive.openBox('clients');
    // await Hive.openBox('loans');
    // await Hive.openBox('payments');

    print('✅ Hive initialized for tests in: $tempPath');
  });

  tearDownAll(() async {
    try {
      await Hive.close();
    } catch (_) {}
    try {
      if (await _tempDir.exists()) {
        await _tempDir.delete(recursive: true);
        print('🧹 Hive temporary data deleted: ${_tempDir.path}');
      }
    } catch (e) {
      print('⚠️ No se pudo borrar temp dir: $e');
    }
  });

  testWidgets('Smoke test: arranca la app y muestra un Scaffold', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // 1) espera corta para que la construcción inicial ocurra
    await tester.pump(const Duration(milliseconds: 500));

    // 2) intenta estabilizar pero con timeout aumentado
    try {
      await tester.pumpAndSettle(const Duration(seconds: 5));
    } catch (e) {
      // pumpAndSettle puede lanzar si no se estabiliza — lo ignoramos y hacemos un pump corto
      await tester.pump(const Duration(milliseconds: 500));
    }

    // Comprueba que al menos hay un Scaffold en la pantalla inicial.
    expect(find.byType(Scaffold), findsWidgets);
  });
}
