// lib/core/database/app_database.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:loan_app/data/models/client_model.dart';
import 'package:loan_app/data/models/loan_model.dart'; // Asegúrate de que esta importación sea correcta

/// Clase para gestionar la inicialización y configuración de la base de datos Hive.
class AppDatabase {
  /// Inicializa Hive y registra los adaptadores de los modelos.
  static Future<void> init() async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);

    // Registra los adaptadores para los modelos de datos.
    // ¡Asegúrate de que LoanModelAdapter() se registre con el typeId correcto!
    // Si tienes ClientModel, asegúrate de que su typeId sea diferente a 3.
    // Hive.registerAdapter(ClientModelAdapter()); // Si ClientModelAdapter usa typeId 0 o 2, cámbialo a 0 o 1
    Hive.registerAdapter(LoanModelAdapter()); // <--- ESTO USARÁ EL typeId 3 ahora
  }
}