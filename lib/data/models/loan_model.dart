import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart'; // Importa el paquete uuid para generar IDs únicos
import 'dart:math'; // Importa dart:math para la función pow (potencia)

part 'loan_model.g.dart'; // Este archivo será generado automáticamente por build_runner

// Anotación para indicar que esta clase es un tipo de Hive y debe ser persistida.
// Asegúrate de que el 'typeId' sea único para cada modelo en tu aplicación.
@HiveType(typeId: 1)
class LoanModel extends HiveObject {
  // Campo para el ID único del préstamo. Se genera automáticamente si no se proporciona.
  @HiveField(0)
  late String id;

  // ID del cliente al que está asociado este préstamo.
  @HiveField(1)
  late String clientId;

  // Monto principal del préstamo.
  @HiveField(2)
  late double amount;

  // Tasa de interés anual del préstamo (ej. 0.05 para 5%).
  @HiveField(3)
  late double interestRate;

  // Plazo del préstamo en meses.
  @HiveField(4)
  late int termMonths;

  // Fecha en que el préstamo fue otorgado.
  @HiveField(5)
  late DateTime startDate;

  // Fecha en que el préstamo debe ser completamente pagado.
  @HiveField(6)
  late DateTime dueDate;

  // Estado actual del préstamo (ej. 'activo', 'pagado', 'atrasado', 'cancelado').
  @HiveField(7)
  late String status;

  // Constructor de la clase LoanModel.
  // El ID es opcional; si no se proporciona, se genera uno nuevo.
  LoanModel({
    String? id,
    required this.clientId,
    required this.amount,
    required this.interestRate,
    required this.termMonths,
    required this.startDate,
    required this.dueDate,
    this.status = 'activo', // El estado por defecto es 'activo'
  }) {
    // Genera un ID numérico de 5 dígitos si no se proporciona uno.
    this.id = id ?? _generateFiveDigitId();

  }

  String _generateFiveDigitId(){
    final random = Random();
    return (10000 + random.nextInt(90000)).toString();
  }
  
  // Getter que calcula el pago mensual del préstamo utilizando la fórmula de amortización.
  // M = P [ i(1 + i)^n ] / [ (1 + i)^n – 1]
  // Donde:
  // M = Pago Mensual
  // P = Monto Principal del Préstamo (amount)
  // i = Tasa de Interés Mensual (interestRate / 12)
  // n = Número Total de Pagos (termMonths)
  double get monthlyPayment {
    if (termMonths == 0) return 0.0; // Evita división por cero si el plazo es 0

    // Si la tasa de interés es 0, el pago mensual es simplemente el monto dividido por el plazo.
    if (interestRate == 0) {
      return amount / termMonths;
    }

    final double monthlyRate = interestRate / 12;
    final double numerator = amount * monthlyRate * pow(1 + monthlyRate, termMonths);
    final double denominator = pow(1 + monthlyRate, termMonths) - 1;

    // Retorna el pago mensual, asegurando que no sea NaN o Infinito.
    if (denominator == 0) return 0.0; // Evita división por cero en casos extremos
    return numerator / denominator;
  }

  // Getter que calcula el monto total a pagar durante todo el plazo del préstamo.
  // Esto es simplemente el pago mensual multiplicado por el número de meses.
  double get totalAmountDue {
    return monthlyPayment * termMonths;
  }

  // Método para actualizar el estado del préstamo y guardarlo en Hive.
  void updateStatus(String newStatus) {
    status = newStatus;
    save(); // Llama al método save() de HiveObject para persistir el cambio
  }

  //Para verificar si el préstamo está completamente pagado
  bool get isFullyPaid => status == 'pagado';

  // Método opcional para convertir el modelo a un mapa de clave-valor.
  // Útil para depuración, logging o para interactuar con APIs externas.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'amount': amount,
      'interestRate': interestRate,
      'termMonths': termMonths,
      'startDate': startDate.toIso8601String(), // Convierte DateTime a String ISO 8601
      'dueDate': dueDate.toIso8601String(),
      'status': status,
      'totalAmountDue': totalAmountDue,
      'monthlyPayment': monthlyPayment,
    };
  }

  // Sobrescritura del método toString para una representación de cadena legible del objeto.
  @override
  String toString() {
    return 'LoanModel(id: $id, clientId: $clientId, amount: $amount, interestRate: $interestRate, termMonths: $termMonths, startDate: $startDate, dueDate: $dueDate, status: $status)';
  }
}