// lib/main.dart (SUGERENCIA - no cambia nombres públicos)
import 'package:flutter/material.dart';
// ✅ ADD: Import for localizations
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

// ✅ NUEVO: Importar servicios
import 'package:loan_app/services/notifications_service.dart'; // <-- Asegúrate de que esta línea esté

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String hivePath;

  if (Platform.isLinux) {
    final Directory appDir = Directory('${Platform.environment['HOME']}/Documentos/hive_data');
    await appDir.create(recursive: true);
    hivePath = appDir.path;
  } else {
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

  // Abrir cajas con try/catch para evitar crash si algo falla
  try {
    if (!Hive.isBoxOpen('clients')) await Hive.openBox<Client>('clients').timeout(const Duration(seconds: 3));
    if (!Hive.isBoxOpen('loans')) await Hive.openBox<LoanModel>('loans').timeout(const Duration(seconds: 3));
    if (!Hive.isBoxOpen('payments')) await Hive.openBox<Payment>('payments').timeout(const Duration(seconds: 3));
    debugPrint('DEBUG: Cajas Hive abiertas correctamente ✅');
  } catch (e, st) {
    // Si abrir cajas falla, lo registramos y seguimos: la app puede crear cajas al vuelo.
    debugPrint('WARN: No se pudieron abrir las cajas Hive al inicio: $e\n$st');
  }

  // ✅ NUEVO: Inicializar el servicio de notificaciones (ahora maneja plataformas incompatibles)
  await NotificationsService().init(); // <-- Esta línea ya no debería causar el crash en Linux

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
      // ✅ ADD: Localization configuration
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Spanish first
        Locale('en', 'US'), // English as fallback
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