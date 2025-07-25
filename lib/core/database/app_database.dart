// lib/core/database/app_database.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:loan_app/data/models/client_model.dart'; // Asumiendo que ya tienes ClientModel
import 'package:loan_app/data/models/loan_model.dart';   // <--- ¡Añade esta importación!

/// Clase para gestionar la inicialización y configuración de la base de datos Hive.
class AppDatabase {
  /// Inicializa Hive y registra los adaptadores de los modelos.
  static Future<void> init() async {
    // Obtiene el directorio de documentos de la aplicación para almacenar la base de datos.
    final appDocumentDir = await getApplicationDocumentsDirectory();
    // Inicializa Hive con la ruta obtenida.
    await Hive.initFlutter(appDocumentDir.path);

    // Registra los adaptadores para los modelos de datos.
    // Asegúrate de que los typeId sean únicos para cada modelo.
    Hive.registerAdapter(ClientModelAdapter()); // Asumiendo que ClientModelAdapter ya existe
    Hive.registerAdapter(LoanModelAdapter());   // <--- ¡Registra el adaptador de LoanModel!

    // Opcional: Abrir las cajas (boxes) al inicio si se van a usar con frecuencia.
    // Esto puede mejorar el rendimiento al evitar aperturas repetidas.
    // await Hive.openBox<ClientModel>('clients');
    // await Hive.openBox<LoanModel>('loans');
  }
}