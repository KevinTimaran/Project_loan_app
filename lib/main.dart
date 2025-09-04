// lib/main.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

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
  
  await Hive.initFlutter();

  // ⚠️ Asegúrate de que los adaptadores estén registrados.
  // Si no tienes estos archivos, necesitas ejecutar:
  // 'flutter pub run build_runner build --delete-conflicting-outputs'
  Hive.registerAdapter(ClientAdapter());
  Hive.registerAdapter(LoanModelAdapter());
  Hive.registerAdapter(PaymentAdapter()); // ⬅️ Se añade el adaptador de pagos
  
  // ⚠️ Abriendo todas las cajas de Hive al inicio de la aplicación
  await Hive.openBox<Client>('clients');
  await Hive.openBox<LoanModel>('loans');
  await Hive.openBox<Payment>('payments');

  // Si necesitas limpiar los datos para pruebas, puedes descomentar esta línea:
  // await clearAllHiveData();

  runApp(const MyApp());
}

// Comentada para evitar borrado accidental durante el desarrollo
/*
Future<void> clearAllHiveData() async {
  try {
    await Hive.deleteBoxFromDisk('clients');
    await Hive.deleteBoxFromDisk('loans');
    await Hive.deleteBoxFromDisk('payments');
    print('DEBUG: Todas las bases de datos de Hive han sido borradas.');
  } catch (e) {
    print('ERROR: Fallo al borrar las bases de datos de Hive: $e');
  }
}
*/

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LoanProvider()..loadLoans(),
      child: MaterialApp(
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
          '/addPayment': (context) => const PaymentFormScreen(), // ⬅️ Se añade la ruta para pagos
        },
      ),
    );
  }
}