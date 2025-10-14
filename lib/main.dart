// lib/main.dart - VERSIÓN CORREGIDA
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/domain/entities/client.dart';
import 'package:loan_app/domain/entities/payment.dart';
import 'package:loan_app/presentation/providers/loan_provider.dart';
import 'package:loan_app/presentation/screens/clients/client_list_screen.dart';
import 'package:loan_app/presentation/screens/loans/add_loan_screen.dart';
import 'package:loan_app/presentation/screens/loans/loan_list_screen.dart';
import 'package:loan_app/presentation/screens/home_screen.dart';
import 'package:loan_app/presentation/screens/auth/pin_validation_screen.dart';
import 'package:loan_app/presentation/screens/payments/payment_form_screen.dart';
import 'package:loan_app/services/notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ DETECCIÓN DE MODO TEST
  bool isInTestMode = false;
  assert(() {
    isInTestMode = true;
    return true;
  }());

  String hivePath;

  if (isInTestMode) {
    // ✅ RUTA TEMPORAL PARA TESTS
    final tempDir = await Directory.systemTemp.createTemp('loan_app_test_${DateTime.now().millisecondsSinceEpoch}');
    hivePath = tempDir.path;
    debugPrint('DEBUG: MODO TEST - Hive usando ruta temporal: $hivePath');
  } else if (Platform.isLinux) {
    final Directory appDir = Directory('${Platform.environment['HOME']}/Documentos/hive_data');
    await appDir.create(recursive: true);
    hivePath = appDir.path;
    debugPrint('DEBUG: Hive usando la ruta: $hivePath');
  } else {
    final Directory appDir = await getApplicationDocumentsDirectory();
    hivePath = appDir.path;
    debugPrint('DEBUG: Hive usando la ruta: $hivePath');
  }

  // ✅ INICIALIZACIÓN ROBUSTA DE HIVE
  try {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ClientAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(LoanModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(PaymentAdapter());
    }
    
    await Hive.initFlutter(hivePath);
    
    // ✅ CORREGIDO: ABRIR CAJAS CON TIPOS ESPECÍFICOS
    if (!Hive.isBoxOpen('clients')) {
      await Hive.openBox<Client>('clients').timeout(const Duration(seconds: 3));
      debugPrint('DEBUG: Caja clients abierta correctamente');
    }
    if (!Hive.isBoxOpen('loans')) {
      await Hive.openBox<LoanModel>('loans').timeout(const Duration(seconds: 3));
      debugPrint('DEBUG: Caja loans abierta correctamente');
    }
    if (!Hive.isBoxOpen('payments')) {
      await Hive.openBox<Payment>('payments').timeout(const Duration(seconds: 3));
      debugPrint('DEBUG: Caja payments abierta correctamente');
    }
    if (!Hive.isBoxOpen('app_settings')) {
      await Hive.openBox('app_settings').timeout(const Duration(seconds: 3));
      debugPrint('DEBUG: Caja app_settings abierta correctamente');
    }
    
    debugPrint('DEBUG: Todas las cajas Hive abiertas correctamente ✅');
  } catch (e, st) {
    debugPrint('ERROR: Fallo al inicializar Hive: $e');
    debugPrint('Stack trace: $st');
    
    // ✅ RECUPERACIÓN EN CASO DE ERROR
    try {
      await Hive.close();
      await Hive.initFlutter(hivePath);
      debugPrint('DEBUG: Hive reinicializado después de error');
    } catch (recoveryError) {
      debugPrint('ERROR CRÍTICO: No se pudo recuperar Hive: $recoveryError');
    }
  }

  // ✅ INICIALIZAR SERVICIO DE NOTIFICACIONES SOLO SI NO ES TEST
  if (!isInTestMode) {
    try {
      await NotificationsService().init();
    } catch (e) {
      debugPrint('DEBUG: Servicio de notificaciones no inicializado: $e');
    }
  } else {
    debugPrint('DEBUG: MODO TEST - Saltando inicialización de notificaciones');
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => LoanProvider()..loadLoans(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LoanApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      locale: const Locale('es', 'ES'),
      initialRoute: '/',
      routes: {
        '/': (context) => const PinValidationScreen(),
        '/home': (context) => const HomeScreen(),
        '/clientList': (context) => const ClientListScreen(),
        '/addLoan': (context) => const AddLoanScreen(),
        '/loanList': (context) => const LoanListScreen(),
        '/addPayment': (context) => const PaymentFormScreen(loan: null),
      },
    );
  }
}