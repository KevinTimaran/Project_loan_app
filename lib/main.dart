// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import 'package:loan_app/core/database/app_database.dart';
import 'package:loan_app/presentation/providers/loan_provider.dart';
import 'package:loan_app/presentation/screens/auth/pin_setup_screen.dart';
import 'package:loan_app/presentation/screens/auth/pin_validation_screen.dart'; // <--- Make sure this is imported
import 'package:loan_app/presentation/screens/home_screen.dart'; // <--- Make sure this is imported
import 'package:loan_app/presentation/screens/loans/loan_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.init();
  await Hive.deleteBoxFromDisk('loans');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Define the app's color palette and theme.
    final ThemeData appTheme = ThemeData(
      // 3.1.1 System Colors: Background, Header, Text
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E88E5), // Professional Blue
        foregroundColor: Colors.white,
      ),
      // 3.1.2 Typography: Use Roboto throughout the app.
      textTheme: GoogleFonts.robotoTextTheme(Theme.of(context).textTheme).apply(
        bodyColor: const Color(0xFF212121), // General text color
      ),
      // 3.1.3 Buttons: Style for Elevated Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF43A047), // Green for CTA
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48), // Minimum height of 48px
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0), // Rounded corners
          ),
        ),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    return ChangeNotifierProvider(
      create: (context) => LoanProvider(),
      child: MaterialApp(
        title: 'LoanApp',
        theme: appTheme, // Apply the defined theme.

        // --- THIS IS CRITICAL! The app's starting point ---
        home: const PinSetupScreen(), // The app ALWAYS starts at PinSetupScreen
        // ---------------------------------------------------

        // Add routes here so other screens can be accessed by name.
        routes: {
          '/home': (context) => const HomeScreen(), // Route for the new HomeScreen
          '/loanList': (context) => const LoanListScreen(), // Route for the loan list
          '/pinValidation': (context) => const PinValidationScreen(), // Route for PIN validation
          // Add routes for other future screens (clients, payments, etc.) here
        },
      ),
    );
  }
}