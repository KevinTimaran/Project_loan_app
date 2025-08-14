// lib/data/models/loan_model.dart
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import 'package:flutter/foundation.dart'; // Asegúrate de tener esta importación
part 'loan_model.g.dart';

// Anotación para indicar que esta clase es un tipo de Hive.
// ¡CAMBIA EL typeId A UN NÚMERO NO USADO ANTERIORMENTE! (ej. 3)
@HiveType(typeId: 3) // <--- ¡CAMBIO CRÍTICO AQUÍ!
class LoanModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String clientId;

  @HiveField(2)
  late double amount;

  @HiveField(3)
  late double interestRate;

  @HiveField(4)
  late int termMonths;

  @HiveField(5)
  late DateTime startDate;

  @HiveField(6)
  late DateTime dueDate;

  @HiveField(7)
  late String status;

  LoanModel({
    String? id, // Permitir un ID opcional, pero generaremos uno por defecto
    required this.clientId, // Ahora espera el NOMBRE del cliente
    required this.amount,
    required this.interestRate,
    required this.termMonths,
    required this.startDate,
    required this.dueDate,
    this.status = 'activo', // El estado por defecto es 'activo'
  }) {
    // Genera un ID numérico de 5 dígitos si no se proporciona uno.
    this.id = id ?? _generateFiveDigitId();
    // DEBUG: Muestra el ID final asignado en el constructor
    debugPrint('DEBUG CONSTRUCTOR: LoanModel creado con ID: ${this.id}'); // <--- NUEVO DEBUG PRINT
  }

  // Método auxiliar para generar un ID numérico de 5 dígitos como String.
  String _generateFiveDigitId() {
    final random = Random();
    final int randomNumber = random.nextInt(90000) + 10000;
    debugPrint('DEBUG GENERADOR: Generando nuevo ID de 5 dígitos: $randomNumber'); // Ya lo tienes, pero lo mantenemos
    return randomNumber.toString();
  }

  // ... (el resto de tu código LoanModel, sin cambios) ...

  @override
  String toString() {
    return 'LoanModel(id: $id, clientName: $clientId, amount: $amount, interestRate: $interestRate, termMonths: $termMonths, startDate: $startDate, dueDate: $dueDate, status: $status)';
  }
}

// Función para reiniciar la base de datos eliminando el box de préstamos
Future<void> resetLoanDatabase() async {
  await Hive.deleteBoxFromDisk('loans');

  debugPrint('DEBUG RESET: Box de préstamos eliminado de disco.');
}




