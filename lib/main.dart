// lib/main.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Importaciones de modelos y entidades
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/domain/entities/client.dart';
import 'package:loan_app/domain/entities/payment.dart';

// Importaciones de pantallas y providers
import 'package:loan_app/presentation/providers/loan_provider.dart';
import 'package:loan_app/presentation/screens/clients/client_list_screen.dart';
import 'package:loan_app/presentation/screens/loans/add_loan_screen.dart';
import 'package:loan_app/presentation/screens/loans/loan_list_screen.dart';
import 'package:loan_app/presentation/screens/home_screen.dart';
import 'package:loan_app/presentation/screens/auth/pin_validation_screen.dart';
import 'package:loan_app/presentation/screens/payments/payment_form_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Usa una carpeta interna de la app para evitar errores de bloqueo en Linux
  final Directory appDir = await getApplicationDocumentsDirectory();
  final String hivePath = '${appDir.path}/hive_data';
  await Directory(hivePath).create(recursive: true);

  // ✅ Inicializa Hive en una ruta segura
  await Hive.initFlutter(hivePath);
  print('DEBUG: Hive usando la ruta: $hivePath');

  // ✅ Registra todos los adaptadores necesarios
  Hive.registerAdapter(ClientAdapter());
  Hive.registerAdapter(LoanModelAdapter());
  Hive.registerAdapter(PaymentAdapter());

  // ✅ Abre las cajas necesarias
  await Hive.openBox<Client>('clients');
  await Hive.openBox<LoanModel>('loans');
  await Hive.openBox<Payment>('payments');

  // ✅ Inicia la app normalmente
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          color: Color(0xFF1E88E5),
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(color: Colors.white),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF1E88E5),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
          ),
        ),
      ),
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
