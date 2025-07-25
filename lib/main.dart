// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Importa el paquete provider
import 'package:loan_app/core/database/app_database.dart';
import 'package:loan_app/presentation/providers/loan_provider.dart'; // Importa tu LoanProvider
import 'package:loan_app/presentation/screens/auth/pin_setup_screen.dart'; // Tu pantalla inicial

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.init(); // Inicializa Hive y registra adaptadores
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Envuelve toda la aplicación con ChangeNotifierProvider para LoanProvider.
    // Esto hace que LoanProvider esté disponible para todos los widgets descendientes.
    return ChangeNotifierProvider(
      create: (context) => LoanProvider(), // Crea una instancia de LoanProvider
      child: MaterialApp(
        title: 'LoanApp',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const PinSetupScreen(), // La primera pantalla será para configurar el PIN
        // Puedes definir tus rutas aquí si usas un sistema de rutas nombrado.
        // Por ahora, la navegación se maneja directamente con MaterialPageRoute.
      ),
    );
  }
}