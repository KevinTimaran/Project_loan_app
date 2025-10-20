// lib/main.dart
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

  // ✅ INICIALIZACIÓN SIMPLE Y DIRECTA - Sin reset automático
  await _initializeHive();
  await NotificationsService().init();

  runApp(
    ChangeNotifierProvider(
      create: (context) => LoanProvider(),
      child: const MyApp(),
    ),
  );
}

// ✅ INICIALIZACIÓN BÁSICA DE HIVE
Future<void> _initializeHive() async {
  String hivePath;

  if (Platform.isLinux) {
    final Directory appDir = Directory('${Platform.environment['HOME']}/Documentos/hive_data');
    await appDir.create(recursive: true);
    hivePath = appDir.path;
  } else {
    final Directory appDir = await getApplicationDocumentsDirectory();
    hivePath = appDir.path;
  }

  await Hive.initFlutter(hivePath);
  debugPrint('🔧 Hive inicializado en: $hivePath');

  // Registrar adaptadores
  Hive.registerAdapter(ClientAdapter());
  Hive.registerAdapter(LoanModelAdapter());
  Hive.registerAdapter(PaymentAdapter());
}

// ✅ FUNCIÓN PARA ABRIR CAJAS DE DATOS (se llama después del PIN)
Future<void> openDataBoxes() async {
  try {
    debugPrint('📂 Abriendo cajas de datos...');
    
    if (!Hive.isBoxOpen('clients')) {
      await Hive.openBox<Client>('clients');
      debugPrint('✅ Caja "clients" abierta');
    }
    
    if (!Hive.isBoxOpen('loans')) {
      await Hive.openBox<LoanModel>('loans');
      debugPrint('✅ Caja "loans" abierta');
    }
    
    if (!Hive.isBoxOpen('payments')) {
      await Hive.openBox<Payment>('payments');
      debugPrint('✅ Caja "payments" abierta');
    }
    
    debugPrint('🎉 Todas las cajas de datos listas');
  } catch (e) {
    debugPrint('❌ Error abriendo cajas de datos: $e');
    rethrow;
  }
}
// ✅ FUNCIÓN PARA LA CAJA DE CONFIGURACIÓN (PIN)
Future<Box> openSettingsBox() async {
  try {
    if (!Hive.isBoxOpen('app_settings')) {
      await Hive.openBox('app_settings');
      debugPrint('✅ Caja "app_settings" abierta');
    }
    return Hive.box('app_settings');
  } catch (e) {
    debugPrint('❌ Error abriendo caja de configuración: $e');
    rethrow;
  }
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
        useMaterial3: true,
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
        '/addPayment': (context) => const PaymentFormScreen(),
      },
    );
  }
}