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

  String hivePath;

  // Determinar la ruta de Hive según la plataforma
  if (Platform.isLinux) {
    // Usar una ruta específica para desarrollo en Linux (o Windows/macOS si se usa Dart Standalone)
    // Esto asegura que la DB de desarrollo NO está en la carpeta de compilación.
    final Directory appDir = Directory('${Platform.environment['HOME']}/Documentos/hive_data');
    await appDir.create(recursive: true);
    hivePath = appDir.path;
  } else {
    // Usar la ruta estándar de documentos de la aplicación para móviles (Android/iOS)
    final Directory appDir = await getApplicationDocumentsDirectory();
    hivePath = appDir.path;
  }

  // Inicializa Hive en ruta decidida
  await Hive.initFlutter(hivePath);
  debugPrint('DEBUG: Hive usando la ruta: $hivePath');

  // Registrar adaptadores
  Hive.registerAdapter(ClientAdapter());
  Hive.registerAdapter(LoanModelAdapter());
  Hive.registerAdapter(PaymentAdapter());

  // Abrir cajas (incluye 'app_settings' para el PIN)
  try {
    if (!Hive.isBoxOpen('clients')) await Hive.openBox<Client>('clients').timeout(const Duration(seconds: 3));
    if (!Hive.isBoxOpen('loans')) await Hive.openBox<LoanModel>('loans').timeout(const Duration(seconds: 3));
    if (!Hive.isBoxOpen('payments')) await Hive.openBox<Payment>('payments').timeout(const Duration(seconds: 3));
    
    // ✅ IMPORTANTE: Abrir la caja de configuración para el PIN aquí
    if (!Hive.isBoxOpen('app_settings')) await Hive.openBox('app_settings').timeout(const Duration(seconds: 3));
    
    debugPrint('DEBUG: Cajas Hive abiertas correctamente ✅');
  } catch (e, st) {
    debugPrint('WARN: No se pudieron abrir las cajas Hive al inicio: $e\n$st');
  }

  // Inicializar el servicio de notificaciones
  await NotificationsService().init();

  runApp(
    ChangeNotifierProvider(
      // Carga inicial de préstamos
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
      // La ruta inicial que siempre lleva al chequeo de PIN
      initialRoute: '/',
      routes: {
        '/': (context) => const PinValidationScreen(), // Comprueba PIN o pide crearlo
        '/home': (context) => const HomeScreen(),
        '/clientList': (context) => const ClientListScreen(),
        '/addLoan': (context) => const AddLoanScreen(),
        '/loanList': (context) => const LoanListScreen(),
        '/addPayment': (context) => const PaymentFormScreen(),
        // Se necesitan más rutas si tienes pantallas para 'Crear PIN' o 'Editar PIN'
      },
    );
  }
}