import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:loan_app/data/models/loan_model.dart';
import 'package:loan_app/domain/entities/client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:loan_app/presentation/providers/loan_provider.dart';
import 'package:loan_app/presentation/screens/clients/client_list_screen.dart';
import 'package:loan_app/presentation/screens/loans/add_loan_screen.dart';
import 'package:loan_app/presentation/screens/loans/loan_list_screen.dart';
import 'package:loan_app/presentation/screens/home_screen.dart';
import 'package:loan_app/presentation/screens/auth/pin_validation_screen.dart';
import 'dart:io';

Future<void> clearAllHiveData() async {
  try {
    if (Platform.isLinux || Platform.isWindows) {
      final appDocumentDir = await getApplicationDocumentsDirectory();
      Hive.init(appDocumentDir.path);
      print('DEBUG: Ruta de Hive en Linux/Windows: ${appDocumentDir.path}');
    } else {
      await Hive.initFlutter();
    }

    final clientBox = await Hive.openBox<Client>('clients');
    await clientBox.clear();
    print('DEBUG: Caja "clients" ha sido limpiada.');

    final loanBox = await Hive.openBox<LoanModel>('loans');
    await loanBox.clear();
    print('DEBUG: Caja "loans" ha sido limpiada.');

    await clientBox.close();
    await loanBox.close();

    await Hive.close();
    print('DEBUG: Todas las bases de datos de Hive han sido cerradas y limpiadas.');

  } catch (e) {
    print('ERROR: Fallo al limpiar la base de datos de Hive: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await clearAllHiveData();

  if (Platform.isLinux || Platform.isWindows) {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);
  } else {
    await Hive.initFlutter();
  }

  Hive.registerAdapter(ClientAdapter());
  Hive.registerAdapter(LoanModelAdapter());

  runApp(const MyApp());
}

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
          '/': (context) => const PinValidationScreen(), // Establece PinScreen como la ruta inicial
          '/home': (context) => const HomeScreen(),
          '/clientList': (context) => const ClientListScreen(),
          '/addLoan': (context) => const AddLoanScreen(),
          '/loanList': (context) => const LoanListScreen(),
        },
      ),
    );
  }
}