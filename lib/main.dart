// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart'; 

import 'package:loan_app/core/database/app_database.dart';
import 'package:loan_app/presentation/providers/loan_provider.dart';
import 'package:loan_app/presentation/screens/auth/pin_setup_screen.dart';
import 'package:loan_app/presentation/screens/loans/loan_list_screen.dart'; // Importamos LoanListScreen como placeholder

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Definimos la paleta de colores y el tema de la aplicación.
    final ThemeData appTheme = ThemeData(
      // 3.1.1 Colores del sistema: Fondo, Encabezado, Texto
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E88E5), // Azul profesional
        foregroundColor: Colors.white,
      ),
      // 3.1.2 Tipografía: Usamos Roboto en toda la app.
      textTheme: GoogleFonts.robotoTextTheme(Theme.of(context).textTheme).apply(
        bodyColor: const Color(0xFF212121), // Color del texto general
      ),
      // 3.1.3 Botones: Estilo para los botones elevados (ElevatedButton)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF43A047), // Verde para CTA
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48), // Altura mínima de 48px
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0), // Bordes redondeados
          ),
        ),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    return ChangeNotifierProvider(
      create: (context) => LoanProvider(),
      child: MaterialApp(
        title: 'LoanApp',
        theme: appTheme, // Aplicamos el tema que acabamos de definir.
        home: const PinSetupScreen(),
        // Agrega rutas aquí para que las demás pantallas puedan ser accedidas.
        routes: {
          '/loanList': (context) => const LoanListScreen(),
        },
      ),
    );
  }
}